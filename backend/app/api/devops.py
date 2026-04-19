from fastapi import APIRouter
from pydantic import BaseModel
from app.agents.devops_agent import run_devops_agent, run_health_check, analyze_error_with_ai, generate_api_test

router = APIRouter()

class AnalyzeRequest(BaseModel):
    error_log: str

class TestGenRequest(BaseModel):
    endpoint: str
    method: str = "GET"

@router.get("/health-check")
async def health_check():
    return await run_health_check()

@router.post("/analyze-error")
async def analyze_error(req: AnalyzeRequest):
    analysis = await analyze_error_with_ai(req.error_log)
    return {"analysis": analysis}

@router.post("/generate-test")
async def generate_test(req: TestGenRequest):
    test = await generate_api_test(req.endpoint, req.method)
    return {"test_code": test}
