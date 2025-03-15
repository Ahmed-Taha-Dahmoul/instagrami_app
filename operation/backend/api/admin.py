from django.contrib import admin
from .models import InstagramUser_data

@admin.register(InstagramUser_data)
class InstagramUserDataAdmin(admin.ModelAdmin):
    list_display = ('user', 'user1_id', 'instagram_username', 'instagram_follower_count', 'instagram_following_count', 'created_at', 'has_12_hours_passed')
    search_fields = ('user__username', 'user1_id', 'instagram_username')
    list_filter = ('created_at',)
    readonly_fields = ('created_at', 'has_12_hours_passed')  # Add it here to show in the detail view

    fieldsets = (
        ("User Information", {
            'fields': ('user', 'instagram_username', 'instagram_full_name')
        }),
        ("Authentication Details", {
            'fields': ('user1_id', 'session_id', 'csrftoken', 'x_ig_app_id')
        }),
        ("Following  Data", {
            'fields': ('old_following_list', 'new_following_list')
        }),
        ("Followers  Data", {
            'fields': ('old_followers_list' , 'new_followers_list')
        }),
        ("Analysis", {
            'fields': ('who_removed_following', 'who_removed_follower', 'who_i_follow_he_dont_followback', 'who_i_dont_follow_he_followback')
        }),
        ("Instagram Profile Details", {
            'fields': ('instagram_follower_count', 'instagram_following_count', 'instagram_total_posts', 'instagram_biography', 'instagram_profile_picture_url')
        }),
        ("Metadata", {
            'fields': ('created_at','last_time_fetched','has_12_hours_passed', 'unfollowed')  # Show in the model details
        }),
    )

    def has_12_hours_passed(self, obj):
        return obj.has_12_hours_passed_since_last_fetch()

    has_12_hours_passed.boolean = True  # Show as a boolean (✔️ or ❌)
    has_12_hours_passed.short_description = "12 Hours Passed?"




from .models import FrontFlags

class FrontFlagsAdmin(admin.ModelAdmin):
    list_display = ('user', 'is_first_time_connected_flag')  # Fields to display in the list view
    search_fields = ('user__username',)  # Make the username searchable
    list_filter = ('is_first_time_connected_flag',)  # Filter by the flag value

admin.site.register(FrontFlags, FrontFlagsAdmin)