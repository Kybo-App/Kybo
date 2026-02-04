"""
Router per i Report Nutrizionisti.

Endpoint per generare e visualizzare report mensili.
"""
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, HTTPException, Depends, Query
from pydantic import BaseModel

from app.core.dependencies import verify_professional, verify_admin
from app.core.logging import logger, sanitize_error_message
from app.services.report_service import ReportService

router = APIRouter(prefix="/admin/reports", tags=["reports"])


# --- SCHEMAS ---
class GenerateReportRequest(BaseModel):
    nutritionist_id: str
    year: int
    month: int  # 1-12
    force_regenerate: bool = False


# --- ENDPOINTS ---

@router.get("/monthly")
async def get_monthly_report(
    nutritionist_id: str = Query(..., description="UID del nutrizionista"),
    month: str = Query(..., description="Mese nel formato YYYY-MM"),
    requester: dict = Depends(verify_professional)
):
    """
    Genera/recupera il report mensile per un nutrizionista.

    - Admin: può vedere report di qualsiasi nutrizionista
    - Nutritionist: può vedere solo il proprio report
    """
    try:
        # Parse month
        try:
            year, month_num = map(int, month.split('-'))
            if not (1 <= month_num <= 12):
                raise ValueError()
        except ValueError:
            raise HTTPException(
                status_code=400,
                detail="Formato mese non valido. Usa YYYY-MM (es. 2024-03)"
            )

        # Permission check
        requester_role = requester['role']
        requester_id = requester['uid']

        if requester_role != 'admin' and requester_id != nutritionist_id:
            raise HTTPException(
                status_code=403,
                detail="Non autorizzato a visualizzare questo report"
            )

        service = ReportService()
        report = await service.generate_monthly_report(
            nutritionist_id=nutritionist_id,
            year=year,
            month=month_num
        )

        logger.info(
            "report_accessed",
            requester_id=requester_id,
            nutritionist_id=nutritionist_id,
            month=month
        )

        return report.to_dict()

    except HTTPException:
        raise
    except Exception as e:
        logger.error("report_get_error", error=sanitize_error_message(e))
        raise HTTPException(
            status_code=500,
            detail="Errore durante la generazione del report"
        )


@router.post("/generate")
async def generate_report(
    body: GenerateReportRequest,
    requester: dict = Depends(verify_professional)
):
    """
    Genera (o rigenera) un report mensile.

    - Admin: può generare per qualsiasi nutrizionista
    - Nutritionist: può generare solo il proprio
    """
    try:
        # Permission check
        requester_role = requester['role']
        requester_id = requester['uid']

        if requester_role != 'admin' and requester_id != body.nutritionist_id:
            raise HTTPException(
                status_code=403,
                detail="Non autorizzato a generare questo report"
            )

        # Validate month
        if not (1 <= body.month <= 12):
            raise HTTPException(status_code=400, detail="Mese non valido (1-12)")

        if body.year < 2020 or body.year > datetime.now().year + 1:
            raise HTTPException(status_code=400, detail="Anno non valido")

        service = ReportService()
        report = await service.generate_monthly_report(
            nutritionist_id=body.nutritionist_id,
            year=body.year,
            month=body.month,
            force_regenerate=body.force_regenerate
        )

        logger.info(
            "report_generated",
            requester_id=requester_id,
            nutritionist_id=body.nutritionist_id,
            month=f"{body.year}-{body.month:02d}",
            force=body.force_regenerate
        )

        return {
            "message": "Report generato con successo",
            "report": report.to_dict()
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error("report_generate_error", error=sanitize_error_message(e))
        raise HTTPException(
            status_code=500,
            detail="Errore durante la generazione del report"
        )


@router.get("/list")
async def list_reports(
    nutritionist_id: Optional[str] = Query(None, description="Filtra per nutrizionista"),
    limit: int = Query(12, ge=1, le=50, description="Numero massimo di report"),
    requester: dict = Depends(verify_professional)
):
    """
    Lista i report disponibili.

    - Admin: può vedere tutti i report
    - Nutritionist: vede solo i propri report
    """
    try:
        requester_role = requester['role']
        requester_id = requester['uid']

        # Non-admin can only see their own reports
        if requester_role != 'admin':
            nutritionist_id = requester_id

        service = ReportService()
        reports = await service.list_reports(
            nutritionist_id=nutritionist_id,
            limit=limit
        )

        return {"reports": reports, "count": len(reports)}

    except Exception as e:
        logger.error("report_list_error", error=sanitize_error_message(e))
        raise HTTPException(
            status_code=500,
            detail="Errore durante il recupero della lista report"
        )


@router.get("/{report_id}")
async def get_report_by_id(
    report_id: str,
    requester: dict = Depends(verify_professional)
):
    """
    Recupera un report specifico per ID.

    ID format: nutritionist_id_YYYY-MM
    """
    try:
        # Extract nutritionist_id from report_id
        parts = report_id.rsplit('_', 1)
        if len(parts) != 2:
            raise HTTPException(status_code=400, detail="ID report non valido")

        nutritionist_id = parts[0]

        # Permission check
        requester_role = requester['role']
        requester_id = requester['uid']

        if requester_role != 'admin' and requester_id != nutritionist_id:
            raise HTTPException(
                status_code=403,
                detail="Non autorizzato a visualizzare questo report"
            )

        service = ReportService()
        report = await service.get_report(report_id)

        if not report:
            raise HTTPException(status_code=404, detail="Report non trovato")

        return report.to_dict()

    except HTTPException:
        raise
    except Exception as e:
        logger.error("report_get_by_id_error", error=sanitize_error_message(e))
        raise HTTPException(
            status_code=500,
            detail="Errore durante il recupero del report"
        )


@router.delete("/{report_id}")
async def delete_report(
    report_id: str,
    admin: dict = Depends(verify_admin)
):
    """
    Elimina un report (solo admin).
    """
    try:
        service = ReportService()
        success = await service.delete_report(report_id)

        if not success:
            raise HTTPException(status_code=500, detail="Eliminazione fallita")

        logger.info(
            "report_deleted_by_admin",
            admin_id=admin['uid'],
            report_id=report_id
        )

        return {"message": "Report eliminato", "report_id": report_id}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("report_delete_error", error=sanitize_error_message(e))
        raise HTTPException(
            status_code=500,
            detail="Errore durante l'eliminazione del report"
        )
