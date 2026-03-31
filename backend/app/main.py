from contextlib import asynccontextmanager
from datetime import datetime, timezone

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.core.database import init_db
from app.api import poses, config, analytics, iap
from app.models.schemas import HealthResponse


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield


settings = get_settings()

app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="PoseCoach iOS App 后端 API —— Pose模板管理、App配置下发、数据统计、内购验证",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 注册路由
app.include_router(poses.router, prefix="/api/v1")
app.include_router(config.router, prefix="/api/v1")
app.include_router(analytics.router, prefix="/api/v1")
app.include_router(iap.router, prefix="/api/v1")


@app.get("/", response_model=HealthResponse, tags=["健康检查"])
async def health_check():
    return HealthResponse(
        status="ok",
        version=settings.app_version,
        timestamp=datetime.now(timezone.utc),
    )


@app.get("/api/v1/health", response_model=HealthResponse, tags=["健康检查"])
async def api_health():
    return HealthResponse(
        status="ok",
        version=settings.app_version,
        timestamp=datetime.now(timezone.utc),
    )
