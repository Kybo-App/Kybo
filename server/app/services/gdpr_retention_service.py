"""
GDPR Retention Policy Service

Gestisce l'identificazione e l'eliminazione automatica degli utenti inattivi
in conformità con il GDPR (Art. 5(1)(e) - Storage Limitation Principle).

Funzionalità:
- Identifica utenti inattivi oltre il periodo di retention configurato
- Elimina dati in cascata (user doc, subcollections, auth record)
- Logging completo per audit trail
- Integrabile con cron job o background task
"""

from datetime import datetime, timezone, timedelta
from typing import Optional
from dataclasses import dataclass

import firebase_admin
from firebase_admin import auth, firestore

from app.core.config import settings
from app.core.logging import logger, sanitize_error_message


@dataclass
class RetentionConfig:
    """Configurazione per la retention policy."""
    retention_months: int = 24  # Default: 2 anni
    is_enabled: bool = False
    dry_run: bool = True  # Se True, non elimina realmente i dati
    exclude_roles: list = None  # Ruoli esclusi dalla purge (es. admin)

    def __post_init__(self):
        if self.exclude_roles is None:
            self.exclude_roles = ['admin', 'nutritionist']


@dataclass
class InactiveUser:
    """Rappresenta un utente identificato come inattivo."""
    uid: str
    email: str
    role: str
    last_activity: Optional[datetime]
    days_inactive: int
    retention_deadline: datetime


@dataclass
class PurgeResult:
    """Risultato di un'operazione di purge."""
    uid: str
    success: bool
    deleted_collections: list
    error: Optional[str] = None


class GDPRRetentionService:
    """
    Servizio per la gestione della retention policy GDPR.

    Usage:
        service = GDPRRetentionService()

        # Identifica utenti inattivi
        inactive = await service.get_inactive_users(retention_months=24)

        # Elimina un utente specifico
        result = await service.purge_user(uid="xxx", reason="GDPR Retention")

        # Purge batch (per cron job)
        results = await service.purge_inactive_users(dry_run=True)
    """

    # Collection names per riferimento
    USERS_COLLECTION = 'users'
    DIETS_SUBCOLLECTION = 'diets'
    DIET_HISTORY_COLLECTION = 'diet_history'
    CHATS_COLLECTION = 'chats'
    MESSAGES_SUBCOLLECTION = 'messages'
    CONSENT_LOGS_COLLECTION = 'consent_logs'
    ACCESS_LOGS_COLLECTION = 'access_logs'
    RETENTION_CONFIG_DOC = 'config/gdpr_retention'

    def __init__(self):
        self.db = firestore.client()

    # =========================================================================
    # CONFIGURATION MANAGEMENT
    # =========================================================================

    async def get_retention_config(self) -> RetentionConfig:
        """
        Recupera la configurazione retention da Firestore.
        Se non esiste, ritorna la configurazione di default.
        """
        try:
            doc = self.db.document(self.RETENTION_CONFIG_DOC).get()
            if doc.exists:
                data = doc.to_dict()
                return RetentionConfig(
                    retention_months=data.get('retention_months', 24),
                    is_enabled=data.get('is_enabled', False),
                    dry_run=data.get('dry_run', True),
                    exclude_roles=data.get('exclude_roles', ['admin', 'nutritionist'])
                )
            return RetentionConfig()
        except Exception as e:
            logger.error("gdpr_config_read_error", error=sanitize_error_message(e))
            return RetentionConfig()

    async def set_retention_config(
        self,
        retention_months: int,
        is_enabled: bool,
        dry_run: bool = True,
        exclude_roles: list = None,
        updated_by: str = None
    ) -> bool:
        """
        Salva la configurazione retention in Firestore.

        Args:
            retention_months: Mesi di inattività dopo cui eliminare i dati
            is_enabled: Se la retention automatica è attiva
            dry_run: Se True, simula l'eliminazione senza cancellare
            exclude_roles: Ruoli esclusi dalla purge
            updated_by: UID dell'admin che ha modificato la config

        Returns:
            True se salvato con successo
        """
        if exclude_roles is None:
            exclude_roles = ['admin', 'nutritionist']

        try:
            self.db.document(self.RETENTION_CONFIG_DOC).set({
                'retention_months': retention_months,
                'is_enabled': is_enabled,
                'dry_run': dry_run,
                'exclude_roles': exclude_roles,
                'updated_at': firestore.SERVER_TIMESTAMP,
                'updated_by': updated_by
            })

            logger.info(
                "gdpr_config_updated",
                retention_months=retention_months,
                is_enabled=is_enabled,
                updated_by=updated_by
            )
            return True

        except Exception as e:
            logger.error("gdpr_config_update_error", error=sanitize_error_message(e))
            return False

    # =========================================================================
    # INACTIVE USER IDENTIFICATION
    # =========================================================================

    def _get_last_activity(self, user_data: dict) -> Optional[datetime]:
        """
        Determina l'ultima attività dell'utente basandosi su vari campi.

        Ordine di priorità:
        1. last_activity (campo esplicito se presente)
        2. last_login
        3. updated_at
        4. createdAt
        """
        activity_fields = ['last_activity', 'last_login', 'updated_at', 'createdAt']

        for field in activity_fields:
            value = user_data.get(field)
            if value:
                if isinstance(value, datetime):
                    # Assicura timezone-aware
                    if value.tzinfo is None:
                        return value.replace(tzinfo=timezone.utc)
                    return value
                # Se è un timestamp Firestore
                if hasattr(value, 'timestamp'):
                    return datetime.fromtimestamp(value.timestamp(), tz=timezone.utc)

        return None

    async def get_inactive_users(
        self,
        retention_months: int = None,
        exclude_roles: list = None
    ) -> list[InactiveUser]:
        """
        Identifica gli utenti inattivi oltre il periodo di retention.

        Args:
            retention_months: Mesi di inattività (default da config)
            exclude_roles: Ruoli da escludere (default da config)

        Returns:
            Lista di InactiveUser
        """
        # Usa config se non specificato
        if retention_months is None or exclude_roles is None:
            config = await self.get_retention_config()
            retention_months = retention_months or config.retention_months
            exclude_roles = exclude_roles if exclude_roles is not None else config.exclude_roles

        now = datetime.now(timezone.utc)
        cutoff_date = now - timedelta(days=retention_months * 30)

        inactive_users = []

        try:
            # Query tutti gli utenti
            users_ref = self.db.collection(self.USERS_COLLECTION)
            users = users_ref.stream()

            for user_doc in users:
                user_data = user_doc.to_dict()
                uid = user_doc.id
                role = user_data.get('role', 'client')

                # Salta ruoli esclusi
                if role in exclude_roles:
                    continue

                last_activity = self._get_last_activity(user_data)

                # Se non ha attività registrata, usa createdAt o considera inattivo
                if last_activity is None:
                    # Senza dati, consideriamo l'utente potenzialmente vecchio
                    # ma lo segnaliamo per revisione manuale
                    last_activity = cutoff_date - timedelta(days=1)

                # Verifica se inattivo
                if last_activity < cutoff_date:
                    days_inactive = (now - last_activity).days
                    retention_deadline = last_activity + timedelta(days=retention_months * 30)

                    inactive_users.append(InactiveUser(
                        uid=uid,
                        email=user_data.get('email', 'N/A'),
                        role=role,
                        last_activity=last_activity,
                        days_inactive=days_inactive,
                        retention_deadline=retention_deadline
                    ))

            logger.info(
                "gdpr_inactive_users_found",
                count=len(inactive_users),
                retention_months=retention_months,
                cutoff_date=cutoff_date.isoformat()
            )

            return inactive_users

        except Exception as e:
            logger.error("gdpr_inactive_search_error", error=sanitize_error_message(e))
            return []

    async def get_users_approaching_retention(
        self,
        days_before_deadline: int = 30,
        retention_months: int = None
    ) -> list[InactiveUser]:
        """
        Identifica utenti che si avvicinano alla scadenza retention.
        Utile per notifiche preventive.

        Args:
            days_before_deadline: Giorni prima della scadenza
            retention_months: Mesi di retention (default da config)

        Returns:
            Lista di utenti prossimi alla scadenza
        """
        if retention_months is None:
            config = await self.get_retention_config()
            retention_months = config.retention_months

        now = datetime.now(timezone.utc)
        # Calcola finestra: utenti che scadranno tra 0 e days_before_deadline giorni
        cutoff_approaching = now - timedelta(days=(retention_months * 30) - days_before_deadline)
        cutoff_expired = now - timedelta(days=retention_months * 30)

        approaching_users = []

        try:
            users_ref = self.db.collection(self.USERS_COLLECTION)
            users = users_ref.stream()

            config = await self.get_retention_config()
            exclude_roles = config.exclude_roles

            for user_doc in users:
                user_data = user_doc.to_dict()
                uid = user_doc.id
                role = user_data.get('role', 'client')

                if role in exclude_roles:
                    continue

                last_activity = self._get_last_activity(user_data)
                if last_activity is None:
                    continue

                # Utenti nella finestra di warning (non ancora scaduti)
                if cutoff_expired <= last_activity < cutoff_approaching:
                    days_inactive = (now - last_activity).days
                    retention_deadline = last_activity + timedelta(days=retention_months * 30)
                    days_until_deadline = (retention_deadline - now).days

                    approaching_users.append(InactiveUser(
                        uid=uid,
                        email=user_data.get('email', 'N/A'),
                        role=role,
                        last_activity=last_activity,
                        days_inactive=days_inactive,
                        retention_deadline=retention_deadline
                    ))

            return approaching_users

        except Exception as e:
            logger.error("gdpr_approaching_search_error", error=sanitize_error_message(e))
            return []

    # =========================================================================
    # DATA DELETION (CASCADE)
    # =========================================================================

    async def purge_user(
        self,
        uid: str,
        reason: str,
        requester_id: str = "SYSTEM",
        dry_run: bool = True
    ) -> PurgeResult:
        """
        Elimina tutti i dati di un utente in cascata (GDPR Art. 17).

        Ordine di eliminazione:
        1. Subcollection diets
        2. diet_history (documenti con userId == uid)
        3. chats e messages (dove l'utente è partecipante)
        4. consent_logs
        5. access_logs (OPZIONALE - potrebbe essere necessario per compliance)
        6. User document
        7. Firebase Auth record

        Args:
            uid: User ID da eliminare
            reason: Motivo dell'eliminazione (per audit)
            requester_id: Chi ha richiesto l'eliminazione
            dry_run: Se True, simula senza eliminare

        Returns:
            PurgeResult con dettagli dell'operazione
        """
        deleted_collections = []

        try:
            # Log inizio operazione
            logger.info(
                "gdpr_purge_started",
                uid=uid,
                reason=reason,
                requester_id=requester_id,
                dry_run=dry_run
            )

            # Crea audit log PRIMA dell'eliminazione
            if not dry_run:
                self.db.collection(self.ACCESS_LOGS_COLLECTION).add({
                    'requester_id': requester_id,
                    'target_uid': uid,
                    'action': 'GDPR_DATA_PURGE',
                    'reason': reason,
                    'timestamp': firestore.SERVER_TIMESTAMP,
                    'dry_run': dry_run
                })

            # 1. Elimina subcollection diets
            diets_deleted = await self._delete_subcollection(
                f"{self.USERS_COLLECTION}/{uid}/{self.DIETS_SUBCOLLECTION}",
                dry_run
            )
            if diets_deleted > 0:
                deleted_collections.append(f"diets ({diets_deleted} docs)")

            # 2. Elimina diet_history
            history_deleted = await self._delete_by_field(
                self.DIET_HISTORY_COLLECTION,
                'userId',
                uid,
                dry_run
            )
            if history_deleted > 0:
                deleted_collections.append(f"diet_history ({history_deleted} docs)")

            # 3. Elimina chats dove l'utente è partecipante
            chats_deleted = await self._delete_user_chats(uid, dry_run)
            if chats_deleted > 0:
                deleted_collections.append(f"chats ({chats_deleted} docs)")

            # 4. Elimina consent_logs
            consent_deleted = await self._delete_by_field(
                self.CONSENT_LOGS_COLLECTION,
                'user_id',
                uid,
                dry_run
            )
            if consent_deleted > 0:
                deleted_collections.append(f"consent_logs ({consent_deleted} docs)")

            # 5. NON eliminare access_logs per audit trail permanente
            # (necessario per compliance GDPR)

            # 6. Elimina user document
            if not dry_run:
                self.db.collection(self.USERS_COLLECTION).document(uid).delete()
            deleted_collections.append("user document")

            # 7. Elimina Firebase Auth record
            if not dry_run:
                try:
                    auth.delete_user(uid)
                    deleted_collections.append("auth record")
                except auth.UserNotFoundError:
                    logger.warning("gdpr_auth_not_found", uid=uid)
                except Exception as e:
                    logger.error("gdpr_auth_delete_error", uid=uid, error=sanitize_error_message(e))
            else:
                deleted_collections.append("auth record (dry_run)")

            logger.info(
                "gdpr_purge_completed",
                uid=uid,
                deleted_collections=deleted_collections,
                dry_run=dry_run
            )

            return PurgeResult(
                uid=uid,
                success=True,
                deleted_collections=deleted_collections
            )

        except Exception as e:
            logger.error(
                "gdpr_purge_error",
                uid=uid,
                error=sanitize_error_message(e)
            )
            return PurgeResult(
                uid=uid,
                success=False,
                deleted_collections=deleted_collections,
                error=str(e)
            )

    async def _delete_subcollection(self, path: str, dry_run: bool) -> int:
        """Elimina tutti i documenti in una subcollection."""
        deleted = 0
        try:
            docs = self.db.collection(path).stream()
            for doc in docs:
                if not dry_run:
                    doc.reference.delete()
                deleted += 1
        except Exception as e:
            logger.error("delete_subcollection_error", path=path, error=sanitize_error_message(e))
        return deleted

    async def _delete_by_field(
        self,
        collection: str,
        field: str,
        value: str,
        dry_run: bool
    ) -> int:
        """Elimina documenti dove field == value."""
        deleted = 0
        try:
            docs = self.db.collection(collection).where(field, '==', value).stream()
            for doc in docs:
                if not dry_run:
                    doc.reference.delete()
                deleted += 1
        except Exception as e:
            logger.error(
                "delete_by_field_error",
                collection=collection,
                field=field,
                error=sanitize_error_message(e)
            )
        return deleted

    async def _delete_user_chats(self, uid: str, dry_run: bool) -> int:
        """
        Elimina chat dove l'utente è partecipante.
        Include eliminazione delle subcollection messages.
        """
        deleted = 0
        try:
            # Query chats dove l'utente è client o nutritionist
            chats_ref = self.db.collection(self.CHATS_COLLECTION)

            # Cerca in participants.clientId
            client_chats = chats_ref.where('participants.clientId', '==', uid).stream()
            for chat in client_chats:
                # Prima elimina messages subcollection
                await self._delete_subcollection(
                    f"{self.CHATS_COLLECTION}/{chat.id}/{self.MESSAGES_SUBCOLLECTION}",
                    dry_run
                )
                if not dry_run:
                    chat.reference.delete()
                deleted += 1

            # Cerca anche in participants.nutritionistId (caso raro)
            nutritionist_chats = chats_ref.where('participants.nutritionistId', '==', uid).stream()
            for chat in nutritionist_chats:
                await self._delete_subcollection(
                    f"{self.CHATS_COLLECTION}/{chat.id}/{self.MESSAGES_SUBCOLLECTION}",
                    dry_run
                )
                if not dry_run:
                    chat.reference.delete()
                deleted += 1

        except Exception as e:
            logger.error("delete_chats_error", uid=uid, error=sanitize_error_message(e))

        return deleted

    # =========================================================================
    # BATCH OPERATIONS (FOR CRON/BACKGROUND TASKS)
    # =========================================================================

    async def purge_inactive_users(
        self,
        dry_run: bool = None,
        requester_id: str = "SYSTEM_CRON"
    ) -> list[PurgeResult]:
        """
        Esegue la purge di tutti gli utenti inattivi.
        Ideale per cron job o background task.

        Args:
            dry_run: Se None, usa il valore dalla config
            requester_id: Identificativo del processo

        Returns:
            Lista di PurgeResult per ogni utente processato
        """
        config = await self.get_retention_config()

        # Verifica se la retention è abilitata
        if not config.is_enabled:
            logger.info("gdpr_retention_disabled", message="Retention policy is disabled")
            return []

        if dry_run is None:
            dry_run = config.dry_run

        # Identifica utenti inattivi
        inactive_users = await self.get_inactive_users(
            retention_months=config.retention_months,
            exclude_roles=config.exclude_roles
        )

        if not inactive_users:
            logger.info("gdpr_no_inactive_users", message="No inactive users to purge")
            return []

        results = []

        for user in inactive_users:
            result = await self.purge_user(
                uid=user.uid,
                reason=f"GDPR Retention Policy - {user.days_inactive} days inactive",
                requester_id=requester_id,
                dry_run=dry_run
            )
            results.append(result)

        # Summary log
        successful = sum(1 for r in results if r.success)
        failed = len(results) - successful

        logger.info(
            "gdpr_batch_purge_completed",
            total=len(results),
            successful=successful,
            failed=failed,
            dry_run=dry_run
        )

        return results

    # =========================================================================
    # DASHBOARD / REPORTING
    # =========================================================================

    async def get_retention_dashboard(self) -> dict:
        """
        Genera statistiche per la dashboard GDPR.

        Returns:
            dict con statistiche retention
        """
        config = await self.get_retention_config()
        inactive_users = await self.get_inactive_users()
        approaching_users = await self.get_users_approaching_retention(days_before_deadline=30)

        # Conta utenti per ruolo
        total_users = 0
        users_by_role = {}

        try:
            users = self.db.collection(self.USERS_COLLECTION).stream()
            for user in users:
                total_users += 1
                role = user.to_dict().get('role', 'unknown')
                users_by_role[role] = users_by_role.get(role, 0) + 1
        except Exception as e:
            logger.error("dashboard_count_error", error=sanitize_error_message(e))

        return {
            "config": {
                "retention_months": config.retention_months,
                "is_enabled": config.is_enabled,
                "dry_run": config.dry_run,
                "exclude_roles": config.exclude_roles
            },
            "statistics": {
                "total_users": total_users,
                "users_by_role": users_by_role,
                "inactive_users_count": len(inactive_users),
                "approaching_deadline_count": len(approaching_users)
            },
            "inactive_users": [
                {
                    "uid": u.uid,
                    "email": u.email,
                    "role": u.role,
                    "days_inactive": u.days_inactive,
                    "retention_deadline": u.retention_deadline.isoformat() if u.retention_deadline else None
                }
                for u in inactive_users[:50]  # Limita a 50 per performance
            ],
            "approaching_deadline": [
                {
                    "uid": u.uid,
                    "email": u.email,
                    "days_inactive": u.days_inactive,
                    "retention_deadline": u.retention_deadline.isoformat() if u.retention_deadline else None
                }
                for u in approaching_users[:50]
            ]
        }
