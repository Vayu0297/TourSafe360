from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from app.core.database import get_db
from app.core.security import decode_token
from app.models.sos import SOSAlert
from app.models.tourist import Tourist
from app.agents.safety_agent import run_safety_agent
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import uuid, json

router = APIRouter()
security = HTTPBearer()

async def get_current_tourist(credentials: HTTPAuthorizationCredentials = Depends(security),
                               db: AsyncSession = Depends(get_db)):
    data = decode_token(credentials.credentials)
    result = await db.execute(select(Tourist).where(Tourist.id == uuid.UUID(data['id'])))
    tourist = result.scalar_one_or_none()
    if not tourist:
        raise HTTPException(401, "Not found")
    return tourist

class SOSRequest(BaseModel):
    alert_type: str = "sos"
    latitude: float
    longitude: float
    location_name: str = None
    message: str = None

@router.post("/trigger")
async def trigger_sos(req: SOSRequest, request: Request,
                      tourist: Tourist = Depends(get_current_tourist),
                      db: AsyncSession = Depends(get_db)):
    ai_result = await run_safety_agent({
        'alert_type': req.alert_type, 'message': req.message or req.alert_type,
        'latitude': req.latitude, 'longitude': req.longitude,
        'tourist_name': tourist.name,
        'blood_group': tourist.blood_group or 'Unknown',
        'emergency_contact': tourist.emergency_contact or 'Not provided'
    })
    alert = SOSAlert(id=uuid.uuid4(), tourist_id=tourist.id,
                     alert_type=req.alert_type, latitude=req.latitude,
                     longitude=req.longitude, location_name=req.location_name,
                     message=req.message, severity=ai_result['severity'],
                     ai_triage=json.dumps(ai_result['triage']))
    db.add(alert)
    await db.commit()
    sio = request.app.state.sio
    await sio.emit('sos_alert', {
        'id': str(alert.id), 'alert_type': req.alert_type,
        'severity': ai_result['severity'], 'tourist_name': tourist.name,
        'latitude': req.latitude, 'longitude': req.longitude,
        'ai_triage': ai_result['triage'], 'nearest_police': ai_result['nearest_police']
    })
    return {"alert_id": str(alert.id), "severity": ai_result['severity'],
            "ai_triage": ai_result['triage'], "nearest_police": ai_result['nearest_police']}

@router.get("/active")
async def get_active(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(SOSAlert).where(SOSAlert.status == "active"))
    return [{"id": str(a.id), "alert_type": a.alert_type, "latitude": a.latitude,
             "longitude": a.longitude, "severity": a.severity, "status": a.status,
             "ai_triage": json.loads(a.ai_triage) if a.ai_triage else None,
             "created_at": str(a.created_at)} for a in result.scalars().all()]

from sqlalchemy import update as sql_update
from datetime import datetime, timezone

class SOSResolve(BaseModel):
    status: str  # active, responding, resolved, false_alarm
    assigned_to: str = None
    resolution_note: str = None

@router.put("/{alert_id}/resolve")
async def resolve_sos(alert_id: str, req: SOSResolve,
                      db: AsyncSession = Depends(get_db)):
    updates = {
        'status': req.status,
        'assigned_to': req.assigned_to,
    }
    if req.status in ['resolved', 'false_alarm']:
        updates['resolved_at'] = datetime.now(timezone.utc)
    await db.execute(
        sql_update(SOSAlert).where(SOSAlert.id == uuid.UUID(alert_id)).values(**updates)
    )
    await db.commit()
    return {"message": f"Alert {req.status}", "alert_id": alert_id}

@router.get("/all")
async def get_all_sos(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(SOSAlert, Tourist).join(Tourist, SOSAlert.tourist_id == Tourist.id, isouter=True)
    )
    rows = result.all()
    alerts = []
    for alert, tourist in rows:
        import json as json_lib
        try:
            triage = json_lib.loads(alert.ai_triage) if alert.ai_triage else None
        except:
            triage = None
        alerts.append({
            "id": str(alert.id),
            "alert_type": alert.alert_type,
            "latitude": alert.latitude,
            "longitude": alert.longitude,
            "location_name": alert.location_name,
            "message": alert.message,
            "status": alert.status,
            "severity": alert.severity,
            "assigned_to": alert.assigned_to,
            "ai_triage": triage,
            "created_at": str(alert.created_at),
            "resolved_at": str(alert.resolved_at) if alert.resolved_at else None,
            "tourist_name": tourist.name if tourist else "Unknown",
            "tourist_phone": tourist.phone if tourist else None,
            "tourist_blood": tourist.blood_group if tourist else None,
            "tourist_lat": tourist.current_lat if tourist else None,
            "tourist_lng": tourist.current_lng if tourist else None,
        })
    return sorted(alerts, key=lambda x: x['created_at'], reverse=True)
