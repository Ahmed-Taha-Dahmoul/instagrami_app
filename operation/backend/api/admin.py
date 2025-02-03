from django.contrib import admin
from .models import InstagramUser_data

@admin.register(InstagramUser_data)
class InstagramUserAdmin(admin.ModelAdmin):
    list_display = ('user', 'user1_id', 'created_at')  # Columns shown in the admin list view
    search_fields = ('user__username', 'user1_id')  # Enable search by username and user1_id
    list_filter = ('created_at',)  # Add filter by created_at
    readonly_fields = ('created_at',)  # Make created_at read-only

    def get_queryset(self, request):
        queryset = super().get_queryset(request)
        return queryset.select_related('user')  # Optimize queries by prefetching related user

