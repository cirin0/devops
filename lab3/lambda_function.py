from fastapi import FastAPI
from mangum import Mangum
import datetime

app = FastAPI(
    title="FastAPI AWS Service",
    description="A minimal FastAPI service deployed on AWS Lambda with API Gateway",
    version="1.0.0",
    root_path="/prod",
)


@app.get("/")
async def root():
    return {
        "message": "Hello from FastAPI on AWS!",
        "service": "API Gateway + Lambda + S3",
        "status": "active",
        "documentation": "/docs",
    }


@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "FastAPI",
        "timestamp": datetime.datetime.now().isoformat(),
    }


handler = Mangum(app)
