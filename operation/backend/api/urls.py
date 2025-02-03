from django.urls import path
from .views import receive_instagram_data

urlpatterns = [
    path('data/', receive_instagram_data, name='receive_instagram_data'),
]
