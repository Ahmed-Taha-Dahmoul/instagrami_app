from rest_framework_simplejwt.authentication import JWTAuthentication
from django.contrib.auth.models import User
from .models import InstagramUser_data
from rest_framework.decorators import api_view, authentication_classes, permission_classes
from rest_framework.permissions import IsAuthenticated
from django.http import JsonResponse
import json

@api_view(['POST'])
@authentication_classes([JWTAuthentication])  # Use JWT for authentication
@permission_classes([IsAuthenticated])  # Ensure the user is authenticated
def receive_instagram_data(request):
    try:
        # The authenticated user is available through request.user
        user = request.user

        # Log the user info for debugging
        print(f"Authenticated user: {user.username}")

        # Decode the request body
        data = json.loads(request.body.decode('utf-8'))

        cookies = data.get('cookies', {})
        x_ig_app_id = data.get('x_ig_app_id', '')

        # Extract necessary cookie values
        user1_id = cookies.get('ds_user_id', '')
        session_id = cookies.get('sessionid', '')
        csrftoken = cookies.get('csrftoken', '')

        # If any required cookies are missing, return an error
        if not user1_id or not session_id or not csrftoken:
            return JsonResponse({"error": "Missing required cookie values"}, status=400)

        # Check if InstagramUser data exists for the current user, otherwise update it
        instagram_user, created = InstagramUser_data.objects.update_or_create(
            user=user,  # Use the logged-in user
            user1_id=user1_id,  # The Instagram user ID
            defaults={
                'session_id': session_id,
                'csrftoken': csrftoken,
                'x_ig_app_id': x_ig_app_id,
            }
        )

        # Return a success response based on whether it's a new or updated entry
        message = "Instagram data linked successfully!" if created else "Instagram data updated successfully!"
        return JsonResponse({"message": message, "status": "success"}, status=200)

    except json.JSONDecodeError:
        return JsonResponse({"error": "Invalid JSON format"}, status=400)

    except Exception as e:
        print(f"Error occurred: {str(e)}")
        return JsonResponse({"error": "Internal Server Error", "details": str(e)}, status=500)
