# serializers.py
from rest_framework import serializers
from .models import InstagramUser_data

class InstagramUserDataSerializer(serializers.ModelSerializer):
    class Meta:
        model = InstagramUser_data
        fields = [
            'user', 'instagram_username', 'instagram_full_name',
            'instagram_follower_count', 'instagram_following_count',
            'instagram_total_posts', 'instagram_biography', 'instagram_profile_picture_url'
        ]
