from sqlalchemy import Column, Float, Boolean, DateTime, Integer
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
import uuid
from app.core.database import Base

class HealthEvent(Base):
    __tablename__ = "health_events_v2"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tourist_id = Column(UUID(as_uuid=True), nullable=False)
    heart_rate = Column(Integer, nullable=True)
    spo2 = Column(Float, nullable=True)
    accel_magnitude = Column(Float, nullable=True)
    fall_detected = Column(Boolean, default=False)
    anomaly_score = Column(Float, default=0.0)
    alert_sent = Column(Boolean, default=False)
    timestamp = Column(DateTime(timezone=True), server_default=func.now())
