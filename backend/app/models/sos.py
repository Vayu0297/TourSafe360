from sqlalchemy import Column, String, Float, DateTime, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
import uuid
from app.core.database import Base

class SOSAlert(Base):
    __tablename__ = "sos_alerts_v2"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tourist_id = Column(UUID(as_uuid=True), nullable=False)
    alert_type = Column(String, default="sos")
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    location_name = Column(String, nullable=True)
    message = Column(Text, nullable=True)
    status = Column(String, default="active")
    severity = Column(String, default="high")
    ai_triage = Column(Text, nullable=True)
    assigned_to = Column(String, nullable=True)
    blockchain_tx = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    resolved_at = Column(DateTime(timezone=True), nullable=True)
