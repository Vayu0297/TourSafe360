from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from app.core.database import get_db
from app.models.zone import Zone
import uuid

router = APIRouter()

class ZoneCreate(BaseModel):
    name: str
    zone_type: str = "green"
    state: str
    center_lat: float
    center_lng: float
    radius_meters: int = 5000
    description: str = None

@router.get("/")
async def get_zones(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Zone).where(Zone.active == True))
    return [{"id": str(z.id), "name": z.name, "zone_type": z.zone_type,
             "state": z.state, "center_lat": z.center_lat, "center_lng": z.center_lng,
             "radius_meters": z.radius_meters, "risk_score": z.risk_score} for z in result.scalars().all()]

@router.post("/")
async def create_zone(req: ZoneCreate, db: AsyncSession = Depends(get_db)):
    zone = Zone(id=uuid.uuid4(), **req.dict())
    db.add(zone)
    await db.commit()
    return {"id": str(zone.id), "name": zone.name}
