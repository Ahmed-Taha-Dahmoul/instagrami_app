from django.urls import path
from .views import receive_instagram_data, check_instagram_status, get_encrypted_instagram_data , save_fetched_followers , save_fetched_following , get_followed_but_not_followed_back , get_dont_follow_back_you , verify_token , save_instagram_user_profile , get_instagram_user_profile
from .views import get_unfollowed_status , check_instagram_counts , get_first_time_flag , update_first_time_flag , check_12_hours_passed , change_unfollow_status , remove_following , update_last_time_fetched , remove_follower , get_who_removed_you , get_unfollowed_you
from .views import remove_unfollowed_you
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
    path('unfollow-status/', get_unfollowed_status, name='get_unfollowed_status'),
    path('change_unfollow_status/' , change_unfollow_status , name='change_unfollow_status'),
    path('check-instagram-counts/' , check_instagram_counts , name='check_instagram_counts'),
    path('get-first-time-flag/' , get_first_time_flag , name='get_first_time_flag'),
    path('update-first-time-flag/' , update_first_time_flag , name='update_first_time_flag'),
    path('check-12-hours-passed/' , check_12_hours_passed , name='check_12_hours_passed'),
    path('remove-following/' , remove_following , name='remove_following'),
    path('remove-follower/' , remove_follower , name='remove_follower'),
    path('update-last-time-fetched/' , update_last_time_fetched , name='update_last_time_fetched'),
    path('get-unfollowed-you/' , get_unfollowed_you , name='get_unfollowed_you'),
    path('get-who-removed-you/' , get_who_removed_you , name='get_who_removed_you'),
    path('remove-unfollowed-you/' , remove_unfollowed_you , name='remove_unfollowed_you'),
]
