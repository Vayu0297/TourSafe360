from sqlalchemy import Column, Float, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
import uuid
from app.core.database import Base

class TouristPosition(Base):
    __tablename__ = "tourist_positions_v2"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tourist_id = Column(UUID(as_uuid=True), nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    accuracy = Column(Float, nullable=True)
    speed = Column(Float, nullable=True)
    timestamp = Column(DateTime(timezone=True), server_default=func.now())
