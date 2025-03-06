from django.db import models
from django.contrib.auth.models import User
from django.utils.timezone import now
from datetime import timedelta
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.utils import timezone

class InstagramUser_data(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)  
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
    unfollowed = models.BooleanField(default=False, blank=True)
    instagram_follower_count = models.PositiveIntegerField(default=0)
    instagram_following_count = models.PositiveIntegerField(default=0)
    instagram_total_posts = models.PositiveIntegerField(default=0)
    instagram_biography = models.TextField(blank=True)
    instagram_profile_picture_url = models.URLField(max_length=1000, blank=True)

    # New field
    last_time_fetched = models.DateTimeField(default=now, blank=True)

    def __str__(self):
        return str(self.user.username)

    def has_12_hours_passed_since_last_fetch(self):
        """Check if 12 hours have passed since last_time_fetched"""
        return now() >= self.last_time_fetched + timedelta(hours=12)

    def update_last_fetched_time(self):
        """Update last_time_fetched to the current time"""
        self.last_time_fetched = timezone.now()
        self.save()






class FrontFlags(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)  # Link to Django User model
    is_first_time_connected_flag = models.BooleanField(default=False, blank=True)

    def __str__(self):
        return str(self.user.username)

# Signal to create FrontFlags when a new user is created
@receiver(post_save, sender=User)
def create_front_flags(sender, instance, created, **kwargs):
    # Only create a new FrontFlags record if the user is newly created
    if created:
        FrontFlags.objects.create(user=instance)