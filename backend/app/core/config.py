from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql+asyncpg://toursafe:toursafe%40360@127.0.0.1:5432/toursafe360v2?ssl=false"
    REDIS_URL: str = "redis://127.0.0.1:6379"
    SECRET_KEY: str = "toursafe360-v2-secret-key"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080
    OLLAMA_BASE_URL: str = "http://127.0.0.1:11434"
    SAFETY_MODEL: str = "mistral:7b-instruct-q4_0"
    DEVOPS_MODEL: str = "qwen2.5-coder:3b"
    CHAT_MODEL: str = "llama3.2:3b"

    class Config:
        env_file = ".env"
        extra = "ignore"

settings = Settings()
