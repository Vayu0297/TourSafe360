from sqlalchemy import Column, String, Boolean, Float, DateTime, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
import uuid
from app.core.database import Base

class Tourist(Base):
    __tablename__ = "tourists"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String, nullable=False)
    email = Column(String, unique=True, nullable=False)
    phone = Column(String, nullable=False)
    password_hash = Column(String, nullable=False)
    nationality = Column(String, default="Indian")
    id_document_type = Column(String, default="aadhaar")
    aadhaar_number = Column(String, nullable=True)
    passport_number = Column(String, nullable=True)
    id_verified = Column(Boolean, default=False)
    blood_group = Column(String, nullable=True)
    emergency_contact = Column(String, nullable=True)
    current_lat = Column(Float, nullable=True)
    current_lng = Column(Float, nullable=True)
    current_location_name = Column(String, nullable=True)
    last_seen = Column(DateTime(timezone=True), nullable=True)
    is_active = Column(Boolean, default=True)
    blockchain_id = Column(String, nullable=True)
    device_token = Column(String, nullable=True)
    wearable_mac = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
