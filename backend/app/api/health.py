from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from app.core.database import get_db
from app.core.security import decode_token
from app.models.health import HealthEvent
from app.models.tourist import Tourist
from app.models.health import HealthEvent
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import uuid

router = APIRouter()
security = HTTPBearer()

async def get_current_tourist(credentials: HTTPAuthorizationCredentials = Depends(security),
                               db: AsyncSession = Depends(get_db)):
    data = decode_token(credentials.credentials)
    result = await db.execute(select(Tourist).where(Tourist.id == uuid.UUID(data['id'])))
    return result.scalar_one_or_none()

class HealthData(BaseModel):
    heart_rate: int = None
    spo2: float = None
    accel_magnitude: float = None
    fall_detected: bool = False
    anomaly_score: float = 0.0

@router.post("/submit")
async def submit_health(req: HealthData, request: Request,
                        tourist: Tourist = Depends(get_current_tourist),
                        db: AsyncSession = Depends(get_db)):
    event = HealthEvent(id=uuid.uuid4(), tourist_id=tourist.id, **req.dict())
    db.add(event)
    await db.commit()
    if req.fall_detected:
        await request.app.state.sio.emit('fall_detected',
            {"tourist_id": str(tourist.id), "tourist_name": tourist.name})
    return {"status": "recorded", "fall_detected": req.fall_detected}

from app.services.fall_inference import predict_fall

class WearableData(BaseModel):
    ax: float = 0; ay: float = 0; az: float = 9.8
    gx: float = 0; gy: float = 0; gz: float = 0
    mx: float = 20; my: float = 10; mz: float = 45
    baro: float = 1013; hr: int = 72; spo2: float = 98
    zone: str = "mountain"

@router.post("/wearable")
async def wearable_data(req: WearableData, request: Request,
                        tourist: Tourist = Depends(get_current_tourist),
                        db: AsyncSession = Depends(get_db)):
    sensor_data = req.dict()
    result = await predict_fall(sensor_data)
    if result and result.get("fall_detected"):
        event = HealthEvent(
            id=uuid.uuid4(), tourist_id=tourist.id,
            heart_rate=req.hr, spo2=req.spo2,
            accel_magnitude=result.get("accel_magnitude", 0),
            fall_detected=True,
            anomaly_score=result.get("fall_probability", 0)
        )
        db.add(event)
        await db.commit()
        await request.app.state.sio.emit("fall_detected", {
            "tourist_id": str(tourist.id),
            "tourist_name": tourist.name,
            "fall_probability": result.get("fall_probability"),
            "equipment_recommendations": result.get("equipment_recommendations", []),
            "alert_message": result.get("alert_message"),
            "zone": req.zone,
            "vitals": result.get("vitals"),
            "confirmed_fall": result.get("confirmed_fall", False)
        })
    return result or {"status": "buffering"}
