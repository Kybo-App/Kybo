#!/usr/bin/env python3
"""
RQ Worker entry point — Kybo diet parsing queue.

Avvio locale:
    python worker.py

Su Render (Background Worker service):
    Start Command: python worker.py

Variabili d'ambiente richieste:
    REDIS_URL            — es. redis://localhost:6379/0
    FIREBASE_CREDENTIALS — JSON service account (stesso del server FastAPI)
    RQ_QUEUE_NAME        — (opzionale, default: diet_parsing)
"""
import os
import sys
import logging

# Garantisce che `app/` sia nel path anche se lo script viene avviato dalla root
sys.path.insert(0, os.path.dirname(__file__))

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
)
log = logging.getLogger("kybo.worker")

from app.core.config import settings

if not settings.REDIS_URL:
    log.error("REDIS_URL non configurata — impossibile avviare il worker RQ.")
    sys.exit(1)

from redis import Redis
from rq import Worker, Queue

redis_conn = Redis.from_url(settings.REDIS_URL)

queues = [Queue(settings.RQ_QUEUE_NAME, connection=redis_conn)]

log.info(f"Worker in ascolto su: {settings.RQ_QUEUE_NAME}  |  Redis: {settings.REDIS_URL}")

worker = Worker(queues, connection=redis_conn)
worker.work(with_scheduler=True)
