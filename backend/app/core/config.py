from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    app_name: str = "PoseCoach API"
    app_version: str = "1.0.0"
    debug: bool = False

    database_url: str = "sqlite+aiosqlite:///./data/posecoach.db"

    # Apple IAP 验证
    apple_shared_secret: str = ""
    apple_verify_url: str = "https://buy.itunes.apple.com/verifyReceipt"
    apple_sandbox_verify_url: str = "https://sandbox.itunes.apple.com/verifyReceipt"

    # API 安全
    api_key: str = "posecoach-dev-key"
    cors_origins: list[str] = ["*"]

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache
def get_settings() -> Settings:
    return Settings()
