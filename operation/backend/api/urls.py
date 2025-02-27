from django.urls import path
from .views import receive_instagram_data, check_instagram_status, get_encrypted_instagram_data , save_fetched_followers , save_fetched_following , get_followed_but_not_followed_back , get_dont_follow_back_you , verify_token , save_instagram_user_profile , get_instagram_user_profile

urlpatterns = [
    path('data/', receive_instagram_data, name='receive_instagram_data'),
    path('check_instagram_status/', check_instagram_status, name='check_instagram_status'),
    path('instagram-data/', get_encrypted_instagram_data, name='get_encrypted_instagram_data'),
    path('save-fetched-followers/', save_fetched_followers, name='save_fetched_followers'),
    path('save-fetched-following/', save_fetched_following, name='save_fetched_following'),
    path('get-followed-but-not-followed-back/', get_followed_but_not_followed_back , name ="get_followed_but_not_followed_back" ),
    path('get-dont-follow-back-you/', get_dont_follow_back_you , name ="get_dont_follow_back_you" ),
    path('token/verify/', verify_token, name='token-verify'),
    path('save-user-instagram-profile/', save_instagram_user_profile, name='save_instagram_user_profile'),
    path('get-user-instagram-profile/', get_instagram_user_profile, name='get_instagram_user_profile'),
]
