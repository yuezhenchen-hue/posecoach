import json
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.models.analytics import AnalyticsEvent
from app.models.schemas import AnalyticsEventIn, AnalyticsBatchIn

router = APIRouter(prefix="/analytics", tags=["数据统计"])


@router.post("/event")
async def track_event(
    event: AnalyticsEventIn,
    db: AsyncSession = Depends(get_db),
):
    """记录单个用户事件"""
    db_event = AnalyticsEvent(
        device_id=event.device_id,
        event_type=event.event_type,
        event_data=json.dumps(event.event_data) if event.event_data else None,
        app_version=event.app_version,
        ios_version=event.ios_version,
        device_model=event.device_model,
    )
    db.add(db_event)
    await db.commit()
    return {"status": "ok"}


@router.post("/batch")
async def track_batch(
    batch: AnalyticsBatchIn,
    db: AsyncSession = Depends(get_db),
):
    """批量上报事件（App 在后台攒一批后一次性上报，节省流量）"""
    db_events = [
        AnalyticsEvent(
            device_id=e.device_id,
            event_type=e.event_type,
            event_data=json.dumps(e.event_data) if e.event_data else None,
            app_version=e.app_version,
            ios_version=e.ios_version,
            device_model=e.device_model,
        )
        for e in batch.events
    ]
    db.add_all(db_events)
    await db.commit()
    return {"status": "ok", "count": len(db_events)}
