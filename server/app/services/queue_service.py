"""
RQ Queue service — graceful fallback se Redis non è disponibile.

Usage:
    queue = get_diet_queue()
    if queue:
        job = queue.enqueue(process_diet_upload, ...)
        return {"job_id": job.id, "status": "queued"}
    else:
        # fallback: usa il semaphore classico
        ...
"""
from __future__ import annotations

from typing import Optional

from app.core.config import settings
from app.core.logging import logger

_diet_queue = None
_rq_redis = None


def get_diet_queue():
    """
    Restituisce la coda RQ se Redis è disponibile, altrimenti None.
    Lazy-init: la connessione viene creata al primo utilizzo.
    """
    global _diet_queue, _rq_redis

    if _diet_queue is not None:
        return _diet_queue

    if not settings.REDIS_URL:
        return None

    try:
        from redis import Redis
        from rq import Queue

        _rq_redis = Redis.from_url(settings.REDIS_URL, socket_connect_timeout=2)
        _rq_redis.ping()

        _diet_queue = Queue(
            settings.RQ_QUEUE_NAME,
            connection=_rq_redis,
            default_timeout=settings.RQ_JOB_TIMEOUT,
        )
        logger.info("rq_queue_ready", queue=settings.RQ_QUEUE_NAME)
        return _diet_queue

    except Exception as e:
        logger.warning("rq_queue_unavailable", error=str(e))
        return None


def is_worker_alive() -> bool:
    """
    Verifica se almeno un worker RQ è attivo e registrato sulla coda.
    Se nessun worker è vivo, accodare un job non ha senso perché non verrà
    mai processato — meglio usare il fallback sincrono.
    """
    if _rq_redis is None:
        return False

    try:
        from rq import Worker
        workers = Worker.all(connection=_rq_redis)
        alive = any(w.state != 'suspended' for w in workers)
        if not alive:
            logger.warning("rq_no_active_workers", total_workers=len(workers))
        return alive
    except Exception as e:
        logger.warning("rq_worker_check_failed", error=str(e))
        return False


def get_job_status(job_id: str) -> Optional[dict]:
    """
    Recupera lo stato di un job RQ.

    Returns:
        {
            "status": "queued" | "started" | "done" | "failed",
            "result": <dict> | None,
            "error":  <str>  | None,
            "owner_uid": <str> | None,   # [SECURITY] per verifica ownership nell'endpoint
        }
        oppure None se il job non esiste o Redis non è disponibile.
    """
    queue = get_diet_queue()
    if queue is None:
        return None

    try:
        from rq.job import Job, JobStatus

        job = Job.fetch(job_id, connection=_rq_redis)
        status = job.get_status()
        owner_uid = (job.meta or {}).get('owner_uid')

        if status == JobStatus.FINISHED:
            return {"status": "done", "result": job.result, "error": None, "owner_uid": owner_uid}
        elif status == JobStatus.FAILED:
            exc_info = job.exc_info or ""
            error_summary = exc_info.strip().splitlines()[-1] if exc_info else "Parsing fallito"
            return {"status": "failed", "result": None, "error": error_summary, "owner_uid": owner_uid}
        elif status in (JobStatus.STARTED, JobStatus.DEFERRED):
            return {"status": "started", "result": None, "error": None, "owner_uid": owner_uid}
        else:
            return {"status": "queued", "result": None, "error": None, "owner_uid": owner_uid}

    except Exception as e:
        logger.warning("rq_job_fetch_error", job_id=job_id, error=str(e))
        return None
