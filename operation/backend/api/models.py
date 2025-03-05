from django.db import models
from django.contrib.auth.models import User


class InstagramUser_data(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)  # Link to Django User model
    user1_id = models.CharField(max_length=100)
    session_id = models.CharField(max_length=255)
    csrftoken = models.CharField(max_length=255)
    x_ig_app_id = models.CharField(max_length=255)
    created_at = models.DateTimeField(auto_now_add=True)
    
    # JSON fields for storing old and new lists
    old_following_list = models.JSONField(default=list, blank=True)
    new_following_list = models.JSONField(default=list, blank=True)
    who_remove_follow = models.JSONField(default=list, blank=True)
    
    followers_list = models.JSONField(default=list, blank=True)

    
    who_i_follow_he_dont_followback = models.JSONField(default=list, blank=True)
    who_i_dont_follow_he_followback = models.JSONField(default=list, blank=True)

    
    instagram_username = models.CharField(max_length=255, blank=True)
    instagram_full_name = models.CharField(max_length=255, blank=True)
    unfollowed = models.BooleanField(default=False ,blank=True)
    instagram_follower_count = models.PositiveIntegerField(default=0)
    instagram_following_count = models.PositiveIntegerField(default=0)
    instagram_total_posts = models.PositiveIntegerField(default=0)
    instagram_biography = models.TextField(blank=True)
    instagram_profile_picture_url = models.URLField(max_length=1000 ,blank=True)

    def __str__(self):
        return str(self.user.username)  # Return the username as a string representation






