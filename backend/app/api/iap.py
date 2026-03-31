import httpx
from fastapi import APIRouter
from app.core.config import get_settings
from app.models.schemas import ReceiptVerifyRequest, ReceiptVerifyResponse

router = APIRouter(prefix="/iap", tags=["内购验证"])


@router.post("/verify", response_model=ReceiptVerifyResponse)
async def verify_receipt(request: ReceiptVerifyRequest):
    """
    验证 Apple IAP 收据。
    先请求生产环境，如果返回 21007（沙箱收据）则自动重试沙箱环境。
    """
    settings = get_settings()

    result = await _verify_with_apple(
        request.receipt_data,
        settings.apple_verify_url,
        settings.apple_shared_secret,
    )

    # 21007 = 沙箱收据发到了生产环境，自动重试沙箱
    if result.get("status") == 21007:
        result = await _verify_with_apple(
            request.receipt_data,
            settings.apple_sandbox_verify_url,
            settings.apple_shared_secret,
        )

    if result.get("status") != 0:
        return ReceiptVerifyResponse(
            valid=False,
            message=f"Apple verification failed with status {result.get('status')}",
        )

    # 提取最新的交易信息
    latest = result.get("latest_receipt_info", [{}])
    if latest:
        latest_txn = latest[-1]
        return ReceiptVerifyResponse(
            valid=True,
            product_id=latest_txn.get("product_id"),
            expires_date=latest_txn.get("expires_date"),
            message="Receipt is valid",
        )

    return ReceiptVerifyResponse(
        valid=True,
        product_id=request.product_id,
        message="Receipt is valid (non-subscription)",
    )


async def _verify_with_apple(
    receipt_data: str, url: str, shared_secret: str
) -> dict:
    payload = {"receipt-data": receipt_data}
    if shared_secret:
        payload["password"] = shared_secret

    async with httpx.AsyncClient(timeout=30) as client:
        try:
            response = await client.post(url, json=payload)
            return response.json()
        except Exception as e:
            return {"status": -1, "error": str(e)}
