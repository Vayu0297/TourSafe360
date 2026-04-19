from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from pydantic import BaseModel
from app.core.database import get_db
from app.core.redis import get_redis
from app.core.security import decode_token
from app.models.tourist import Tourist
from app.models.position import TouristPosition
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import uuid, json
from datetime import datetime

router = APIRouter()
security = HTTPBearer()

async def get_current_tourist(credentials: HTTPAuthorizationCredentials = Depends(security),
                               db: AsyncSession = Depends(get_db)):
    data = decode_token(credentials.credentials)
    result = await db.execute(select(Tourist).where(Tourist.id == uuid.UUID(data['id'])))
    return result.scalar_one_or_none()

class LocationUpdate(BaseModel):
    latitude: float
    longitude: float
    location_name: str = None
    accuracy: float = None
    speed: float = None

@router.put("/location")
async def update_location(req: LocationUpdate,
                           tourist: Tourist = Depends(get_current_tourist),
                           db: AsyncSession = Depends(get_db)):
    await db.execute(update(Tourist).where(Tourist.id == tourist.id).values(
        current_lat=req.latitude, current_lng=req.longitude,
        current_location_name=req.location_name, last_seen=datetime.utcnow()
    ))
    db.add(TouristPosition(id=uuid.uuid4(), tourist_id=tourist.id,
                            latitude=req.latitude, longitude=req.longitude,
                            accuracy=req.accuracy, speed=req.speed))
    await db.commit()
    redis = await get_redis()
    await redis.setex(f"tourist:location:{tourist.id}", 300,
                      json.dumps({"lat": req.latitude, "lng": req.longitude, "name": tourist.name}))
    return {"status": "updated"}

@router.get("/active")
async def get_active(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Tourist).where(Tourist.is_active == True))
    return [{"id": str(t.id), "name": t.name, "nationality": t.nationality,
             "current_lat": t.current_lat, "current_lng": t.current_lng,
             "blood_group": t.blood_group, "last_seen": str(t.last_seen)} for t in result.scalars().all()]

@router.get("/locations/live")
async def live_locations():
    redis = await get_redis()
    keys = await redis.keys("tourist:location:*")
    return [json.loads(await redis.get(k)) for k in keys if await redis.get(k)]
