from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from app.core.database import init_db
from app.core.redis import get_redis, close_redis
from app.api import auth, tourists, sos, zones, health, agents, devops, geofence
import socketio

sio = socketio.AsyncServer(
    async_mode='asgi',
    cors_allowed_origins='*',
    logger=True,
    engineio_logger=False
)

@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    await get_redis()
    print("🚀 TourSafe360 v2 AI backend ready!")
    print(f"🤖 Safety Agent: Mistral-7B | Chat: Llama3.2 | DevOps: qwen2.5-coder")
    yield
    await close_redis()

app = FastAPI(title="TourSafe360 v2", version="2.0.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"],
    allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
app.state.sio = sio

@sio.event
async def connect(sid, environ):
    print(f'✅ Client connected: {sid}')

@sio.event
async def disconnect(sid):
    print(f'❌ Client disconnected: {sid}')

app.include_router(auth.router, prefix="/api/auth", tags=["auth"])
app.include_router(tourists.router, prefix="/api/tourists", tags=["tourists"])
app.include_router(sos.router, prefix="/api/sos", tags=["sos"])
app.include_router(zones.router, prefix="/api/zones", tags=["zones"])
app.include_router(health.router, prefix="/api/health", tags=["health"])
app.include_router(agents.router, prefix="/api/agents", tags=["agents"])
app.include_router(devops.router, prefix="/api/devops", tags=["devops"])
app.include_router(geofence.router, prefix="/api/geofence", tags=["geofence"])

@app.get("/health")
async def health_check():
    return {"status": "ok", "version": "2.0.0", "ai": "local-ollama"}

socket_app = socketio.ASGIApp(sio, app)
