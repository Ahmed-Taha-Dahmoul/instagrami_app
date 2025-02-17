from django.urls import path
from .views import receive_instagram_data, check_instagram_status, get_encrypted_instagram_data , save_fetched_followers

urlpatterns = [
    path('data/', receive_instagram_data, name='receive_instagram_data'),
    path('check_instagram_status/', check_instagram_status, name='check_instagram_status'),
    path('instagram-data/', get_encrypted_instagram_data, name='get_encrypted_instagram_data'),
    path('save-fetched-followers/', save_fetched_followers, name='save_fetched_followers'),
]
