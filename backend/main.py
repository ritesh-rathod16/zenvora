"""
Zenvora Backend Entry Point.
Delegates to the production FastAPI application in models.app.main.
"""
from models.app.main import app

__all__ = ["app"]
