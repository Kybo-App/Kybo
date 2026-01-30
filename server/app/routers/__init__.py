# Router modules
from app.routers.diet import router as diet_router
from app.routers.users import router as users_router
from app.routers.admin import router as admin_router

__all__ = ['diet_router', 'users_router', 'admin_router']
