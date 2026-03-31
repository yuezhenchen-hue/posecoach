from pydantic import BaseModel
from datetime import datetime


# ========== Pose ==========

class PoseTemplateOut(BaseModel):
    id: str
    name: str
    description: str
    scene: str
    person_count: str
    difficulty: str
    image_url: str | None = None
    is_premium: bool = False

    model_config = {"from_attributes": True}


class SceneTipOut(BaseModel):
    scene: str
    tip_type: str
    content: str

    model_config = {"from_attributes": True}


# ========== Config ==========

class AppConfigOut(BaseModel):
    key: str
    value: str

    model_config = {"from_attributes": True}


class AppConfigBundle(BaseModel):
    """App 启动时一次性拉取的配置包"""
    configs: dict[str, str]
    poses_version: str
    min_app_version: str
    latest_app_version: str
    maintenance_mode: bool = False
    announcement: str | None = None


# ========== Analytics ==========

class AnalyticsEventIn(BaseModel):
    device_id: str
    event_type: str
    event_data: dict | None = None
    app_version: str | None = None
    ios_version: str | None = None
    device_model: str | None = None


class AnalyticsBatchIn(BaseModel):
    events: list[AnalyticsEventIn]


# ========== IAP ==========

class ReceiptVerifyRequest(BaseModel):
    receipt_data: str
    product_id: str
    transaction_id: str | None = None


class ReceiptVerifyResponse(BaseModel):
    valid: bool
    product_id: str | None = None
    expires_date: str | None = None
    message: str


# ========== General ==========

class HealthResponse(BaseModel):
    status: str
    version: str
    timestamp: datetime
