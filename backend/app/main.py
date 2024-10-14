from fastapi import FastAPI
from app.api.endpoints import assets, auth

# Create the FastAPI app instance
app = FastAPI(title="Asset Management API")

# Include the routers
app.include_router(assets.router, prefix="/api/v1", tags=["assets"])
app.include_router(auth.router, prefix="/api/v1/auth", tags=["auth"])

@app.get("/")
async def root():
    return {"message": "Welcome to the Asset Management API"}
