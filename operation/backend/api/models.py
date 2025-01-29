from django.db import models

class InstagramUser(models.Model):
    username = models.CharField(max_length=100, unique=True)
    user_id = models.CharField(max_length=100, unique=True)
    session_id = models.CharField(max_length=255)
    csrftoken = models.CharField(max_length=255)
    x_ig_app_id = models.CharField(max_length=255)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.username
