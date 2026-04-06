from fastapi import FastAPI, HTTPException, Header, Depends, Body
from pydantic import BaseModel
from typing import List, Optional
import time
import uuid

app = FastAPI(title="Telemetry Vendor Mock API")

# Simple Auth Storage
VALID_CLIENT_ID = "test_user"
VALID_CLIENT_SECRET = "test_pass"
# In a real mock we'd use a real token, here we just check if it exists
VALID_TOKEN = "mock_access_token_12345"


class TokenRequest(BaseModel):
    client_id: str
    client_secret: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "Bearer"
    expires_in: int = 3600


class TelemetryRequest(BaseModel):
    batch_size: int = 1000
    stream_type: str
    cursor: Optional[str] = None


class TelemetryEvent(BaseModel):
    event_id: str
    stream_type: str
    data: dict
    timestamp: float


class TelemetryResponse(BaseModel):
    events: List[TelemetryEvent]
    next_cursor: Optional[str]


async def verify_token(authorization: str = Header(...)):
    if authorization != f"Bearer {VALID_TOKEN}":
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    return authorization


@app.post("/v1/oauth/token", response_model=TokenResponse)
async def login(req: TokenRequest):
    if req.client_id == VALID_CLIENT_ID and req.client_secret == VALID_CLIENT_SECRET:
        return TokenResponse(access_token=VALID_TOKEN)
    raise HTTPException(status_code=401, detail="Invalid credentials")


@app.post("/v1/telemetry/events", response_model=TelemetryResponse)
async def get_telemetry(req: TelemetryRequest, token: str = Depends(verify_token)):
    # Deterministic generation logic
    current_index = 0
    if req.cursor:
        try:
            # Expected format: cursor_{stream_type}_{index}
            parts = req.cursor.split("_")
            current_index = int(parts[-1])
        except (ValueError, IndexError):
            raise HTTPException(status_code=400, detail="Invalid cursor format")

    max_records = 30000
    if current_index >= max_records:
        return TelemetryResponse(events=[], next_cursor=None)

    num_to_generate = min(req.batch_size, max_records - current_index)
    events = []

    for i in range(num_to_generate):
        idx = current_index + i + 1
        events.append(
            TelemetryEvent(
                event_id=str(uuid.uuid4()),
                stream_type=req.stream_type,
                data={"value": idx, "message": f"Sample {req.stream_type} event {idx}"},
                timestamp=time.time(),
            )
        )

    next_idx = current_index + num_to_generate
    next_cursor = (
        f"cursor_{req.stream_type}_{next_idx}" if next_idx < max_records else None
    )

    return TelemetryResponse(events=events, next_cursor=next_cursor)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
