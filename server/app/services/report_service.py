"""
Report Service - Monthly Nutritionist Reports

Genera report mensili per i nutrizionisti con metriche chiave:
- Clienti gestiti
- Diete caricate
- Messaggi scambiati
- Tempo di risposta medio
"""

from datetime import datetime, timezone, timedelta
from typing import Optional
from dataclasses import dataclass, asdict
import calendar

from firebase_admin import firestore

from app.core.logging import logger, sanitize_error_message


@dataclass
class NutritionistReport:
    """Report mensile per un nutrizionista."""
    nutritionist_id: str
    nutritionist_name: str
    nutritionist_email: str
    month: str  # YYYY-MM format
    period_start: str
    period_end: str

    # Client metrics
    total_clients: int
    new_clients: int
    active_clients: int  # Clients with activity in the month

    # Diet metrics
    diets_uploaded: int
    diets_by_client: dict  # {client_id: count}

    # Chat metrics
    total_messages_sent: int
    total_messages_received: int
    average_response_time_hours: Optional[float]

    # Summary
    generated_at: str

    def to_dict(self) -> dict:
        return asdict(self)


class ReportService:
    """
    Service for generating and managing nutritionist reports.

    Usage:
        service = ReportService()

        # Generate report for a specific month
        report = await service.generate_monthly_report(
            nutritionist_id="xxx",
            year=2024,
            month=3
        )

        # List available reports
        reports = await service.list_reports(nutritionist_id="xxx")
    """

    REPORTS_COLLECTION = 'nutritionist_reports'

    def __init__(self):
        self.db = firestore.client()

    # =========================================================================
    # REPORT GENERATION
    # =========================================================================

    async def generate_monthly_report(
        self,
        nutritionist_id: str,
        year: int,
        month: int,
        force_regenerate: bool = False
    ) -> NutritionistReport:
        """
        Genera il report mensile per un nutrizionista.

        Args:
            nutritionist_id: UID del nutrizionista
            year: Anno del report
            month: Mese del report (1-12)
            force_regenerate: Se True, rigenera anche se esiste già

        Returns:
            NutritionistReport con tutte le metriche
        """
        month_str = f"{year}-{month:02d}"
        report_id = f"{nutritionist_id}_{month_str}"

        # Check if report already exists
        if not force_regenerate:
            existing = await self._get_cached_report(report_id)
            if existing:
                logger.info("report_cache_hit", report_id=report_id)
                return existing

        # Calculate period
        _, last_day = calendar.monthrange(year, month)
        period_start = datetime(year, month, 1, tzinfo=timezone.utc)
        period_end = datetime(year, month, last_day, 23, 59, 59, tzinfo=timezone.utc)

        try:
            # Get nutritionist info
            nutritionist_doc = self.db.collection('users').document(nutritionist_id).get()
            if not nutritionist_doc.exists:
                raise ValueError(f"Nutritionist {nutritionist_id} not found")

            nutr_data = nutritionist_doc.to_dict()

            # Gather metrics
            client_metrics = await self._get_client_metrics(
                nutritionist_id, period_start, period_end
            )
            diet_metrics = await self._get_diet_metrics(
                nutritionist_id, period_start, period_end
            )
            chat_metrics = await self._get_chat_metrics(
                nutritionist_id, period_start, period_end
            )

            # Build report
            report = NutritionistReport(
                nutritionist_id=nutritionist_id,
                nutritionist_name=f"{nutr_data.get('first_name', '')} {nutr_data.get('last_name', '')}".strip(),
                nutritionist_email=nutr_data.get('email', ''),
                month=month_str,
                period_start=period_start.isoformat(),
                period_end=period_end.isoformat(),
                total_clients=client_metrics['total'],
                new_clients=client_metrics['new'],
                active_clients=client_metrics['active'],
                diets_uploaded=diet_metrics['total'],
                diets_by_client=diet_metrics['by_client'],
                total_messages_sent=chat_metrics['sent'],
                total_messages_received=chat_metrics['received'],
                average_response_time_hours=chat_metrics['avg_response_hours'],
                generated_at=datetime.now(timezone.utc).isoformat()
            )

            # Cache report
            await self._cache_report(report_id, report)

            logger.info(
                "report_generated",
                nutritionist_id=nutritionist_id,
                month=month_str,
                clients=client_metrics['total'],
                diets=diet_metrics['total']
            )

            return report

        except Exception as e:
            logger.error(
                "report_generation_error",
                nutritionist_id=nutritionist_id,
                month=month_str,
                error=sanitize_error_message(e)
            )
            raise

    async def _get_client_metrics(
        self,
        nutritionist_id: str,
        period_start: datetime,
        period_end: datetime
    ) -> dict:
        """Calcola metriche sui clienti."""
        total = 0
        new = 0
        active = 0

        # Get all clients of this nutritionist
        clients = self.db.collection('users').where(
            'parent_id', '==', nutritionist_id
        ).stream()

        for client in clients:
            total += 1
            client_data = client.to_dict()

            # Check if new (created in this period)
            created_at = client_data.get('createdAt')
            if created_at:
                if isinstance(created_at, datetime):
                    created_dt = created_at if created_at.tzinfo else created_at.replace(tzinfo=timezone.utc)
                elif hasattr(created_at, 'timestamp'):
                    created_dt = datetime.fromtimestamp(created_at.timestamp(), tz=timezone.utc)
                else:
                    created_dt = None

                if created_dt and period_start <= created_dt <= period_end:
                    new += 1

            # Check if active (has diet history or messages in period)
            # For simplicity, check diet_history
            history = self.db.collection('diet_history').where(
                filter=firestore.FieldFilter('userId', '==', client.id)
            ).where(
                filter=firestore.FieldFilter('uploadedAt', '>=', period_start)
            ).where(
                filter=firestore.FieldFilter('uploadedAt', '<=', period_end)
            ).limit(1).stream()

            if any(True for _ in history):
                active += 1

        return {'total': total, 'new': new, 'active': active}

    async def _get_diet_metrics(
        self,
        nutritionist_id: str,
        period_start: datetime,
        period_end: datetime
    ) -> dict:
        """Calcola metriche sulle diete caricate."""
        total = 0
        by_client = {}

        # Get diet_history uploaded by this nutritionist in the period
        diets = self.db.collection('diet_history').where(
            filter=firestore.FieldFilter('uploadedBy', '==', nutritionist_id)
        ).where(
            filter=firestore.FieldFilter('uploadedAt', '>=', period_start)
        ).where(
            filter=firestore.FieldFilter('uploadedAt', '<=', period_end)
        ).stream()

        for diet in diets:
            total += 1
            diet_data = diet.to_dict()
            client_id = diet_data.get('userId', 'unknown')
            by_client[client_id] = by_client.get(client_id, 0) + 1

        return {'total': total, 'by_client': by_client}

    async def _get_chat_metrics(
        self,
        nutritionist_id: str,
        period_start: datetime,
        period_end: datetime
    ) -> dict:
        """Calcola metriche sulla chat."""
        sent = 0
        received = 0
        response_times = []

        # Get all chats where nutritionist is participant
        chats = self.db.collection('chats').where(
            'participants.nutritionistId', '==', nutritionist_id
        ).stream()

        for chat in chats:
            chat_id = chat.id

            # Get messages in period
            messages = self.db.collection('chats').document(chat_id).collection(
                'messages'
            ).where(
                filter=firestore.FieldFilter('timestamp', '>=', period_start)
            ).where(
                filter=firestore.FieldFilter('timestamp', '<=', period_end)
            ).order_by('timestamp').stream()

            prev_msg = None
            for msg in messages:
                msg_data = msg.to_dict()
                sender_id = msg_data.get('senderId')

                if sender_id == nutritionist_id:
                    sent += 1
                    # Calculate response time if previous message was from client
                    if prev_msg and prev_msg.get('senderId') != nutritionist_id:
                        prev_time = prev_msg.get('timestamp')
                        curr_time = msg_data.get('timestamp')
                        if prev_time and curr_time:
                            if hasattr(prev_time, 'timestamp'):
                                prev_dt = datetime.fromtimestamp(prev_time.timestamp(), tz=timezone.utc)
                            else:
                                prev_dt = prev_time
                            if hasattr(curr_time, 'timestamp'):
                                curr_dt = datetime.fromtimestamp(curr_time.timestamp(), tz=timezone.utc)
                            else:
                                curr_dt = curr_time

                            delta = (curr_dt - prev_dt).total_seconds() / 3600  # hours
                            if 0 < delta < 168:  # Ignore responses > 1 week
                                response_times.append(delta)
                else:
                    received += 1

                prev_msg = msg_data

        avg_response = None
        if response_times:
            avg_response = round(sum(response_times) / len(response_times), 2)

        return {
            'sent': sent,
            'received': received,
            'avg_response_hours': avg_response
        }

    # =========================================================================
    # REPORT CACHING & RETRIEVAL
    # =========================================================================

    async def _get_cached_report(self, report_id: str) -> Optional[NutritionistReport]:
        """Recupera report dalla cache."""
        try:
            doc = self.db.collection(self.REPORTS_COLLECTION).document(report_id).get()
            if doc.exists:
                data = doc.to_dict()
                return NutritionistReport(**data)
        except Exception as e:
            logger.warning("report_cache_error", error=sanitize_error_message(e))
        return None

    async def _cache_report(self, report_id: str, report: NutritionistReport):
        """Salva report in cache."""
        try:
            self.db.collection(self.REPORTS_COLLECTION).document(report_id).set(
                report.to_dict()
            )
        except Exception as e:
            logger.warning("report_cache_save_error", error=sanitize_error_message(e))

    async def list_reports(
        self,
        nutritionist_id: Optional[str] = None,
        limit: int = 12
    ) -> list[dict]:
        """
        Lista i report disponibili.

        Args:
            nutritionist_id: Se specificato, filtra per nutrizionista
            limit: Numero massimo di report da ritornare

        Returns:
            Lista di report summary (senza dettagli completi)
        """
        try:
            query = self.db.collection(self.REPORTS_COLLECTION)

            if nutritionist_id:
                query = query.where('nutritionist_id', '==', nutritionist_id)

            query = query.order_by('month', direction=firestore.Query.DESCENDING)
            query = query.limit(limit)

            reports = []
            for doc in query.stream():
                data = doc.to_dict()
                reports.append({
                    'report_id': doc.id,
                    'nutritionist_id': data.get('nutritionist_id'),
                    'nutritionist_name': data.get('nutritionist_name'),
                    'month': data.get('month'),
                    'total_clients': data.get('total_clients'),
                    'diets_uploaded': data.get('diets_uploaded'),
                    'generated_at': data.get('generated_at')
                })

            return reports

        except Exception as e:
            logger.error("report_list_error", error=sanitize_error_message(e))
            return []

    async def get_report(self, report_id: str) -> Optional[NutritionistReport]:
        """
        Recupera un report specifico per ID.

        Args:
            report_id: ID del report (format: nutritionist_id_YYYY-MM)

        Returns:
            NutritionistReport o None
        """
        return await self._get_cached_report(report_id)

    async def delete_report(self, report_id: str) -> bool:
        """
        Elimina un report.

        Args:
            report_id: ID del report

        Returns:
            True se eliminato con successo
        """
        try:
            self.db.collection(self.REPORTS_COLLECTION).document(report_id).delete()
            logger.info("report_deleted", report_id=report_id)
            return True
        except Exception as e:
            logger.error("report_delete_error", error=sanitize_error_message(e))
            return False
