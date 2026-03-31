from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.models.pose import PoseTemplate, SceneTip
from app.models.schemas import PoseTemplateOut, SceneTipOut

router = APIRouter(prefix="/poses", tags=["Pose 模板"])


@router.get("/", response_model=list[PoseTemplateOut])
async def get_poses(
    scene: str | None = Query(None, description="按场景筛选，如 beach/cafe/cityStreet"),
    person_count: str | None = Query(None, description="按人数筛选: single/couple/group"),
    db: AsyncSession = Depends(get_db),
):
    """获取 Pose 模板列表，支持按场景和人数筛选"""
    query = select(PoseTemplate).where(PoseTemplate.is_active == True)

    if scene:
        query = query.where(PoseTemplate.scene == scene)
    if person_count:
        query = query.where(PoseTemplate.person_count == person_count)

    query = query.order_by(PoseTemplate.sort_order, PoseTemplate.id)
    result = await db.execute(query)
    return result.scalars().all()


@router.get("/{pose_id}", response_model=PoseTemplateOut)
async def get_pose(pose_id: str, db: AsyncSession = Depends(get_db)):
    """获取单个 Pose 模板详情"""
    result = await db.execute(
        select(PoseTemplate).where(PoseTemplate.id == pose_id)
    )
    pose = result.scalar_one_or_none()
    if not pose:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Pose not found")
    return pose


@router.get("/scenes/{scene}/tips", response_model=list[SceneTipOut])
async def get_scene_tips(
    scene: str,
    tip_type: str | None = Query(None, description="creative/parameter/composition"),
    db: AsyncSession = Depends(get_db),
):
    """获取某个场景的拍摄技巧"""
    query = select(SceneTip).where(
        SceneTip.scene == scene,
        SceneTip.is_active == True,
    )
    if tip_type:
        query = query.where(SceneTip.tip_type == tip_type)

    query = query.order_by(SceneTip.sort_order)
    result = await db.execute(query)
    return result.scalars().all()
