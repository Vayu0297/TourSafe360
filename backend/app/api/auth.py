from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from app.core.database import get_db
from app.core.security import hash_password, verify_password, create_token
from app.models.tourist import Tourist
import uuid

router = APIRouter()

class RegisterRequest(BaseModel):
    name: str
    email: str
    phone: str
    password: str
    nationality: str = "Indian"
    aadhaar_number: str = None
    passport_number: str = None
    blood_group: str = None
    emergency_contact: str = None

class LoginRequest(BaseModel):
    email: str
    password: str

@router.post("/register")
async def register(req: RegisterRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Tourist).where(Tourist.email == req.email))
    if result.scalar_one_or_none():
        raise HTTPException(400, "Email already registered")
    tourist = Tourist(
        id=uuid.uuid4(), name=req.name, email=req.email, phone=req.phone,
        password_hash=hash_password(req.password), nationality=req.nationality,
        aadhaar_number=req.aadhaar_number, passport_number=req.passport_number,
        blood_group=req.blood_group, emergency_contact=req.emergency_contact,
        id_document_type="aadhaar" if req.aadhaar_number else "passport"
    )
    db.add(tourist)
    await db.commit()
    await db.refresh(tourist)
    token = create_token({"id": str(tourist.id), "type": "tourist"})
    return {"message": "Registered successfully", "token": token, "tourist_id": str(tourist.id)}

@router.post("/login")
async def login(req: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Tourist).where(Tourist.email == req.email))
    tourist = result.scalar_one_or_none()
    if not tourist or not verify_password(req.password, tourist.password_hash):
        raise HTTPException(401, "Invalid credentials")
    token = create_token({"id": str(tourist.id), "type": "tourist"})
    return {"message": "Login successful", "token": token,
            "tourist": {"id": str(tourist.id), "name": tourist.name, "email": tourist.email}}
