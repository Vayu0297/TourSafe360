from fastapi import APIRouter
from pydantic import BaseModel
from app.agents.safety_agent import run_safety_agent
from langchain_ollama import OllamaLLM
from app.core.config import settings

router = APIRouter()
chat_llm = OllamaLLM(model=settings.CHAT_MODEL,
                      base_url=settings.OLLAMA_BASE_URL, temperature=0.7)

class ChatRequest(BaseModel):
    message: str
    language: str = "english"

class SafetyTestRequest(BaseModel):
    alert_type: str = "sos"
    message: str = "Help needed"
    latitude: float = 26.1445
    longitude: float = 91.7362
    tourist_name: str = "Test Tourist"
    blood_group: str = "O+"
    emergency_contact: str = "9999999999"

LANGUAGE_MAP = {
    "english": "English", "hindi": "Hindi (हिंदी)", "chinese": "Chinese (中文)",
    "spanish": "Spanish (Español)", "french": "French (Français)",
    "arabic": "Arabic (العربية)", "russian": "Russian (Русский)",
    "japanese": "Japanese (日本語)", "korean": "Korean (한국어)",
    "german": "German (Deutsch)", "assamese": "Assamese (অসমীয়া)",
    "bengali": "Bengali (বাংলা)", "tamil": "Tamil (தமிழ்)",
    "telugu": "Telugu (తెలుగు)", "marathi": "Marathi (मराठी)",
    "portuguese": "Portuguese (Português)", "italian": "Italian (Italiano)",
    "thai": "Thai (ภาษาไทย)", "vietnamese": "Vietnamese (Tiếng Việt)",
    "malay": "Malay (Bahasa Melayu)", "mizo": "Mizo", "manipuri": "Manipuri (মৈতৈলোন্)",
}

@router.post("/chat")
async def tourist_chat(req: ChatRequest):
    lang = LANGUAGE_MAP.get(req.language.lower(), req.language)
    prompt = f"""You are TourSafe360 — an expert AI tourism safety assistant for North East India.
You help tourists with travel information, safety tips, local culture, emergency guidance, and attractions.
IMPORTANT: Always respond in {lang}. If the user writes in a different language, still respond in {lang}.
Keep responses helpful, concise and friendly.

Tourist question: {req.message}"""
    response = chat_llm.invoke(prompt)
    return {
        "response": response,
        "model": settings.CHAT_MODEL,
        "language": lang,
        "supported_languages": list(LANGUAGE_MAP.keys())
    }

@router.get("/languages")
async def get_languages():
    return {"supported_languages": LANGUAGE_MAP}

@router.post("/safety/test")
async def test_safety_agent(req: SafetyTestRequest):
    return await run_safety_agent(req.dict())

@router.get("/status")
async def agents_status():
    return {
        "safety_agent": {"model": settings.SAFETY_MODEL, "status": "ready"},
        "chat_agent": {"model": settings.CHAT_MODEL, "status": "ready"},
        "devops_agent": {"model": settings.DEVOPS_MODEL, "status": "ready"},
    }
