from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.core.config import get_settings
from app.models.config import AppConfig
from app.models.schemas import AppConfigBundle

router = APIRouter(prefix="/config", tags=["App 配置"])


@router.get("/", response_model=AppConfigBundle)
async def get_app_config(db: AsyncSession = Depends(get_db)):
    """
    App 启动时调用，一次性拉取所有配置。
    包括：功能开关、版本要求、公告、Pose 数据版本号等。
    """
    result = await db.execute(
        select(AppConfig).where(AppConfig.is_active == True)
    )
    configs = {row.key: row.value for row in result.scalars().all()}

    return AppConfigBundle(
        configs=configs,
        poses_version=configs.get("poses_version", "1.0.0"),
        min_app_version=configs.get("min_app_version", "1.0.0"),
        latest_app_version=configs.get("latest_app_version", "1.0.0"),
        maintenance_mode=configs.get("maintenance_mode", "false").lower() == "true",
        announcement=configs.get("announcement"),
    )
