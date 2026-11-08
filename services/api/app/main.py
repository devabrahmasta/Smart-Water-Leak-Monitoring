"""
FastAPI Main Application untuk Smart Water Leak Monitoring System.
"""

from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError, HTTPException

from app.api.v1.commands import router as commands_router

app = FastAPI(
    title="Smart Water Leak Monitoring API",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)


@app.exception_handler(HTTPException)
async def custom_http_exception_handler(request: Request, exc: HTTPException):
    """Format galat standar CONTRACT.md: { 'error': { 'code': ..., 'message': ... } }"""
    if isinstance(exc.detail, dict) and "code" in exc.detail:
        return JSONResponse(
            status_code=exc.status_code,
            content={"error": exc.detail},
        )
    return JSONResponse(
        status_code=exc.status_code,
        content={"error": {"code": "ERROR", "message": str(exc.detail)}},
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """Format galat validasi 422: INVALID_PAYLOAD"""
    errors = exc.errors()
    first_err = errors[0] if errors else {}
    msg = first_err.get("msg", "Isi permintaan tidak valid")
    loc = " -> ".join(str(l) for l in first_err.get("loc", []))
    detail_msg = f"{loc}: {msg}" if loc else msg
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "error": {
                "code": "INVALID_PAYLOAD",
                "message": detail_msg,
            }
        },
    )


# Endpoint Health Publik (tanpa token)
@app.get("/health", tags=["Monitoring"])
def health_check():
    """Pemeriksaan kesehatan sistem (debug, publik tanpa token)."""
    return {"status": "ok"}


# Registrasi router API v1
app.include_router(commands_router)
