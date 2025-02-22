from django.contrib import admin
from .models import InstagramUser_data

@admin.register(InstagramUser_data)
class InstagramUserDataAdmin(admin.ModelAdmin):
    list_display = ('user', 'user1_id', 'created_at')
    search_fields = ('user__username', 'user1_id')
    list_filter = ('created_at',)
    readonly_fields = ('created_at',)
    fieldsets = (
        ("User Information", {
            'fields': ('user',)
        }),
        ("Authentication Details", {
            'fields': ('user1_id', 'session_id', 'csrftoken', 'x_ig_app_id')
        }),
        ("Following & Followers Data", {
            'fields': ('old_following_list', 'new_following_list', 'followers_list')
        }),
        ("Analysis", {
            'fields': ('who_remove_follow', 'who_i_follow_he_dont_followback', 'who_i_dont_follow_he_followback')
        }),
        ("Metadata", {
            'fields': ('created_at',)
        }),
    )
