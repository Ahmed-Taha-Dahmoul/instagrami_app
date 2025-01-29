from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import register, CustomTokenObtainPairView

urlpatterns = [
    path('register/', register, name='register'),  # User registration endpoint
    path('login/', CustomTokenObtainPairView.as_view(), name='login'),  # Login endpoint for JWT tokens
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),  # Token refresh endpoint
]
