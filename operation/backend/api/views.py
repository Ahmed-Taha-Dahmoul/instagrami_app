from rest_framework_simplejwt.authentication import JWTAuthentication
from django.contrib.auth.models import User
from .models import InstagramUser_data
from rest_framework.decorators import api_view, authentication_classes, permission_classes
from rest_framework.permissions import IsAuthenticated
from django.http import JsonResponse
import json
from rest_framework.response import Response
from rest_framework import status

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






@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def check_instagram_status(request):
    try:
        # Get the current authenticated user
        user = request.user
        
        # Check if Instagram data exists for the authenticated user
        instagram_data = InstagramUser_data.objects.filter(user=user).first()

        if instagram_data:
            # Return a success response if Instagram data exists
            return Response({"connected": True, "message": "Instagram account is connected."}, status=200)
        else:
            # Return a response indicating Instagram is not connected
            return Response({"connected": False, "message": "Instagram account is not connected."}, status=200)
    
    except Exception as e:
        # If there's an error, return a 500 internal server error response
        return Response({"error": "Internal Server Error", "details": str(e)}, status=500)



from .crypto_utils import encrypt_data



@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def get_encrypted_instagram_data(request):
    """Sends encrypted Instagram session data to the frontend."""
    try:
        user = request.user
        instagram_data = InstagramUser_data.objects.filter(user=user).first()

        if not instagram_data:
            return Response({"error": "Instagram data not found for this user."}, status=status.HTTP_404_NOT_FOUND)

        # Prepare data for encryption
        data_to_encrypt = {
            "user1_id": instagram_data.user1_id,
            "session_id": instagram_data.session_id,
            "csrftoken": instagram_data.csrftoken,
            "x_ig_app_id": instagram_data.x_ig_app_id
        }

        encrypted_data = encrypt_data(json.dumps(data_to_encrypt))
        return Response({"encrypted_data": encrypted_data}, status=status.HTTP_200_OK)

    except Exception as e:
        return Response({"error": "Failed to retrieve data", "details": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    


def update_follow_relationships(instagram_data):
    """Update mutual follow relationships."""
    # Convert followers and following lists to sets of ids
    following_ids = set(user["pk"] for user in instagram_data.new_following_list)
    followers_ids = set(user["pk"] for user in instagram_data.followers_list)

    # Find who the user follows but they don't follow back
    instagram_data.who_i_follow_he_dont_followback = list(following_ids - followers_ids)
    
    # Find who follows the user but the user doesn't follow back
    instagram_data.who_i_dont_follow_he_followback = list(followers_ids - following_ids)
    
    instagram_data.save()


def update_removed_followers(instagram_data, old_list, new_list):
    """Update the list of removed followers."""
    # Convert old and new lists to sets of ids
    old_ids = set(user["pk"] for user in old_list)
    new_ids = set(user["pk"] for user in new_list)
    
    # Find removed followers
    removed_followers = old_ids - new_ids
    
    # Update who_remove_follow, either appending or incrementing counts
    existing_removed = instagram_data.who_remove_follow or []
    updated_removed = existing_removed + list(removed_followers)
    instagram_data.who_remove_follow = updated_removed
    instagram_data.save()




@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def save_fetched_followers(request):
    """Receives the follower list from Flutter and updates the database."""
    try:
        user = request.user
        followers_list = request.data.get("followers_list")

        if not isinstance(followers_list, list):
            return Response({"error": "Invalid data format. Expecting a list."}, status=status.HTTP_400_BAD_REQUEST)

        instagram_data = InstagramUser_data.objects.filter(user=user).first()

        if not instagram_data:
            return Response({"error": "Instagram data not found for this user."}, status=status.HTTP_404_NOT_FOUND)

        # Directly save the followers list as JSON in the database
        instagram_data.followers_list = followers_list
        instagram_data.save()

        # Update follow relationships (you can keep these functions if needed)
        update_follow_relationships(instagram_data)

        return Response({"message": "Followers list updated successfully."}, status=status.HTTP_200_OK)

    except Exception as e:
        return Response({"error": "Failed to save data", "details": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def save_fetched_following(request):
    """Receives the following list from Flutter and updates the database."""
    try:
        user = request.user
        following_list = request.data.get("following_list")
        
        if not isinstance(following_list, list):
            
            return Response({"error": "Invalid data format. Expecting a list."}, status=status.HTTP_400_BAD_REQUEST)

        instagram_data = InstagramUser_data.objects.filter(user=user).first()
        
        if not instagram_data:
            return Response({"error": "Instagram data not found for this user."}, status=status.HTTP_404_NOT_FOUND)

        # Backup the old following list before updating
        instagram_data.old_following_list = instagram_data.new_following_list
        instagram_data.new_following_list = following_list  # Saving the complete list

        # Directly save the following list as JSON in the database
        instagram_data.save()

        # Optionally, update follow relationships if needed
        update_follow_relationships(instagram_data)

        return Response({"message": "Following list updated successfully."}, status=status.HTTP_200_OK)

    except Exception as e:
        print(f"Error: {str(e)}")
        return Response({"error": "Failed to save data", "details": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
