"""
TourSafe360 v2 — AI DevOps Agent
Uses qwen2.5-coder:3b locally to:
- Monitor API health
- Auto-run tests
- Detect anomalies in logs
- Suggest fixes for errors
Zero API cost — runs on your GTX 1650
"""
from langchain_ollama import OllamaLLM
from app.core.config import settings
import httpx, json, asyncio
from datetime import datetime

llm = OllamaLLM(model=settings.DEVOPS_MODEL,
                 base_url=settings.OLLAMA_BASE_URL, temperature=0.1)

ENDPOINTS_TO_MONITOR = [
    {"name": "health", "url": "http://127.0.0.1:8000/health", "method": "GET"},
    {"name": "tourists", "url": "http://127.0.0.1:8000/api/tourists/active", "method": "GET"},
    {"name": "zones", "url": "http://127.0.0.1:8000/api/zones/", "method": "GET"},
]

async def check_endpoint_health(endpoint: dict) -> dict:
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            start = asyncio.get_event_loop().time()
            if endpoint["method"] == "GET":
                r = await client.get(endpoint["url"])
            elapsed = (asyncio.get_event_loop().time() - start) * 1000
            return {
                "name": endpoint["name"],
                "status": "healthy" if r.status_code < 400 else "unhealthy",
                "status_code": r.status_code,
                "response_time_ms": round(elapsed, 2),
                "timestamp": datetime.utcnow().isoformat()
            }
    except Exception as e:
        return {
            "name": endpoint["name"],
            "status": "down",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }

async def run_health_check() -> dict:
    results = await asyncio.gather(*[check_endpoint_health(ep) for ep in ENDPOINTS_TO_MONITOR])
    healthy = sum(1 for r in results if r["status"] == "healthy")
    return {
        "total": len(results),
        "healthy": healthy,
        "unhealthy": len(results) - healthy,
        "endpoints": list(results),
        "overall": "healthy" if healthy == len(results) else "degraded"
    }

async def analyze_error_with_ai(error_log: str) -> str:
    prompt = f"""You are a DevOps AI for TourSafe360 — a FastAPI + PostgreSQL + Redis system.
Analyze this error and suggest a fix in 3 bullet points max.

Error:
{error_log}

Respond concisely with:
- Root cause
- Immediate fix
- Prevention"""
    try:
        return llm.invoke(prompt)
    except Exception as e:
        return f"AI analysis unavailable: {e}"

async def generate_api_test(endpoint: str, method: str) -> str:
    prompt = f"""Generate a Python pytest test for this FastAPI endpoint:
Endpoint: {method} {endpoint}
App: TourSafe360 tourism safety API

Write one concise pytest function only, no explanation."""
    try:
        return llm.invoke(prompt)
    except Exception as e:
        return f"# AI test generation failed: {e}"

async def run_devops_agent(task: str) -> dict:
    """Main devops agent entry point"""
    if task == "health_check":
        return await run_health_check()
    elif task.startswith("analyze_error:"):
        error = task.replace("analyze_error:", "")
        analysis = await analyze_error_with_ai(error)
        return {"analysis": analysis, "model": settings.DEVOPS_MODEL}
    elif task.startswith("generate_test:"):
        endpoint = task.replace("generate_test:", "")
        test = await generate_api_test(endpoint, "GET")
        return {"test_code": test, "model": settings.DEVOPS_MODEL}
    else:
        return {"error": "Unknown task"}
