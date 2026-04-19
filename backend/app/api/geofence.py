from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, delete
from pydantic import BaseModel
from typing import Optional
from app.core.database import get_db
from app.models.zone import Zone
import uuid

router = APIRouter()

class GeofenceCreate(BaseModel):
    name: str
    zone_type: str = "green"
    state: str
    center_lat: float
    center_lng: float
    radius_meters: int = 5000
    description: Optional[str] = None

class GeofenceUpdate(BaseModel):
    name: Optional[str] = None
    zone_type: Optional[str] = None
    radius_meters: Optional[int] = None
    description: Optional[str] = None
    active: Optional[bool] = None

@router.get("/")
async def get_geofences(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Zone))
    zones = result.scalars().all()
    return [{"id": str(z.id), "name": z.name, "zone_type": z.zone_type,
             "state": z.state, "center_lat": z.center_lat, "center_lng": z.center_lng,
             "radius_meters": z.radius_meters, "risk_score": z.risk_score,
             "active": z.active, "description": z.description,
             "created_at": str(z.created_at)} for z in zones]

@router.post("/")
async def create_geofence(req: GeofenceCreate, db: AsyncSession = Depends(get_db)):
    zone = Zone(id=uuid.uuid4(), name=req.name, zone_type=req.zone_type,
                state=req.state, center_lat=req.center_lat, center_lng=req.center_lng,
                radius_meters=req.radius_meters, description=req.description, active=True)
    db.add(zone)
    await db.commit()
    await db.refresh(zone)
    return {"id": str(zone.id), "name": zone.name, "message": "Geofence created"}

@router.put("/{zone_id}")
async def update_geofence(zone_id: str, req: GeofenceUpdate, db: AsyncSession = Depends(get_db)):
    updates = {k: v for k, v in req.dict().items() if v is not None}
    await db.execute(update(Zone).where(Zone.id == uuid.UUID(zone_id)).values(**updates))
    await db.commit()
    return {"message": "Updated"}

@router.delete("/{zone_id}")
async def delete_geofence(zone_id: str, db: AsyncSession = Depends(get_db)):
    await db.execute(delete(Zone).where(Zone.id == uuid.UUID(zone_id)))
    await db.commit()
    return {"message": "Deleted"}
