from rest_framework_simplejwt.authentication import JWTAuthentication
from django.contrib.auth.models import User
from .models import InstagramUser_data, FrontFlags
from rest_framework.decorators import api_view, authentication_classes, permission_classes
from rest_framework.permissions import IsAuthenticated
from django.http import JsonResponse
import json
from rest_framework.response import Response
from rest_framework import status
from .serializers import InstagramUserDataSerializer



@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def verify_token(request):
    return Response({"message": "Token is valid"}, status=200)




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
            # Check if the required fields are present and not empty
            if all([instagram_data.user1_id, instagram_data.session_id, instagram_data.csrftoken, instagram_data.x_ig_app_id]):
                # If all fields are filled, return a success response
                return Response({"connected": True, "message": "Instagram account is connected."}, status=200)
            else:
                # If one of the fields is empty, return false with a message
                return Response({"connected": False, "message": "Instagram account is connected but missing some required data."}, status=200)
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

        # Update the last_time_fetched field to the current time
        instagram_data.update_last_fetched_time()

        # Save the changes to the database
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

        instagram_data.update_last_fetched_time()
        # Directly save the following list as JSON in the database
        instagram_data.save()

        # Optionally, update follow relationships if needed
        update_follow_relationships(instagram_data)

        return Response({"message": "Following list updated successfully."}, status=status.HTTP_200_OK)

    except Exception as e:
        print(f"Error: {str(e)}")
        return Response({"error": "Failed to save data", "details": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)








from rest_framework.pagination import PageNumberPagination


#traja3 alli eni nfollowi fehom w houma le

class CustomPagination(PageNumberPagination):
    page_size = 15  # Number of users per page
    page_size_query_param = 'page_size'
    max_page_size = 50  # Maximum number of users per request

@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def get_followed_but_not_followed_back(request):
    try:
        instagram_user_data = InstagramUser_data.objects.get(user=request.user)

        unfollowed_back_users_ids = instagram_user_data.who_i_follow_he_dont_followback
        following_data = instagram_user_data.new_following_list
        following_dict = {user['pk']: user for user in following_data}

        result = [
            {
                "id": user_data.get('id'),
                "username": user_data.get('username'),
                "full_name": user_data.get('full_name'),
                "is_private": user_data.get('is_private'),
                "is_verified": user_data.get('is_verified'),
                "profile_pic_url": user_data.get('profile_pic_url'),
            }
            for user_pk in unfollowed_back_users_ids if (user_data := following_dict.get(user_pk))
        ]

        paginator = CustomPagination()
        paginated_data = paginator.paginate_queryset(result, request)

        return paginator.get_paginated_response(paginated_data)

    except InstagramUser_data.DoesNotExist:
        return Response({"error": "Instagram user data not found"}, status=404)










#traja3 el yfollow fiya weni le

@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def get_dont_follow_back_you(request):
    try:
        instagram_user_data = InstagramUser_data.objects.get(user=request.user)

        # Get the list of users who follow the authenticated user, but they don't follow back
        dont_follow_back_users_ids = instagram_user_data.who_i_dont_follow_he_followback

        # Retrieve the full following list to extract user details
        followers_data = instagram_user_data.followers_list  # Assuming followers are stored here
        followers_dict = {user['pk']: user for user in followers_data}

        # Construct response
        result = [
            {
                "id": user_data.get('id'),
                "username": user_data.get('username'),
                "full_name": user_data.get('full_name'),
                "is_private": user_data.get('is_private'),
                "is_verified": user_data.get('is_verified'),
                "profile_pic_url": user_data.get('profile_pic_url'),
            }
            for user_pk in dont_follow_back_users_ids if (user_data := followers_dict.get(user_pk))
        ]

        # Set up pagination
        paginator = CustomPagination()
        paginated_data = paginator.paginate_queryset(result, request)

        return paginator.get_paginated_response(paginated_data)

    except InstagramUser_data.DoesNotExist:
        return Response({"error": "Instagram user data not found"}, status=404)
    














#hedhi bech tokhou el user data mel front end 
@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def save_instagram_user_profile(request):
    try:
        user_data = request.data.get('user_data')

        if not user_data:
            return Response({"error": "No 'user_data' found in the request body"}, status=status.HTTP_400_BAD_REQUEST)
        
        user = user_data.get('user')
        if not user:
            return Response({"error": "No user information found"}, status=status.HTTP_400_BAD_REQUEST)

        # Extract relevant fields
        instagram_username = user.get('username', '')
        instagram_full_name = user.get('full_name', '')
        instagram_follower_count = user.get('follower_count', 0)
        instagram_following_count = user.get('following_count', 0)
        instagram_total_posts = user.get('media_count', 0)
        instagram_biography = user.get('biography', '')
        instagram_profile_picture_url = user.get('profile_pic_url', '')

        # Get or create the InstagramUser_data object
        try:
            instagram_user_data = InstagramUser_data.objects.get(user=request.user)
            created = False
            previous_follower_count = instagram_user_data.instagram_follower_count  # Get the previous count
        except InstagramUser_data.DoesNotExist:
            instagram_user_data = InstagramUser_data(user=request.user)
            created = True
            previous_follower_count = None  # No previous data

        # Check if follower count changed
        if previous_follower_count is not None:
            if instagram_follower_count < previous_follower_count:
                instagram_user_data.unfollowed = True  # Follower count decreased
            elif instagram_follower_count > previous_follower_count:
                instagram_user_data.unfollowed = True  # Follower count increased
        else:
            instagram_user_data.unfollowed = False  # No previous data to compare

        # Update the InstagramUser_data fields
        instagram_user_data.instagram_username = instagram_username
        instagram_user_data.instagram_full_name = instagram_full_name
        instagram_user_data.instagram_follower_count = instagram_follower_count
        instagram_user_data.instagram_following_count = instagram_following_count
        instagram_user_data.instagram_total_posts = instagram_total_posts
        instagram_user_data.instagram_biography = instagram_biography
        instagram_user_data.instagram_profile_picture_url = instagram_profile_picture_url

        instagram_user_data.save()

        serializer = InstagramUserDataSerializer(instagram_user_data)

        return Response({
            "success": "User data saved successfully",
            "user_data": serializer.data
        }, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)

    except Exception as e:
        print(f"An error occurred: {e}")
        return Response({
            "error": "An error occurred",
            "details": str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


    




#hedhi bech nabathou el user profile data lel front 

@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def get_instagram_user_profile(request):
    try:
        # Try to get the InstagramUser_data object related to the authenticated user
        instagram_user_data = InstagramUser_data.objects.get(user=request.user)

        # Serialize the InstagramUser_data
        serializer = InstagramUserDataSerializer(instagram_user_data)

        # Return the serialized data as a JSON response
        return Response({
            "success": "User data fetched successfully",
            "user_data": serializer.data
        }, status=status.HTTP_200_OK)

    except InstagramUser_data.DoesNotExist:
        return Response({"error": "Instagram user data not found"}, status=status.HTTP_404_NOT_FOUND)

    except Exception as e:
        return Response({
            "error": "An error occurred",
            "details": str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    














#traj3elna unfollow status

@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def get_unfollowed_status(request):
    try:
        # Fetch the InstagramUser_data object for the authenticated user
        instagram_user_data = InstagramUser_data.objects.get(user=request.user)

        return Response({
            "unfollowed": instagram_user_data.unfollowed
        }, status=status.HTTP_200_OK)

    except InstagramUser_data.DoesNotExist:
        return Response({
            "error": "Instagram user data not found"
        }, status=status.HTTP_404_NOT_FOUND)

    except Exception as e:
        print(f"An error occurred: {e}")
        return Response({
            "error": "An error occurred",
            "details": str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    





#bech tchouf el followers w folloing a9al mel 20k

@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def check_instagram_counts(request):
    try:
        # Fetch the InstagramUser_data object for the authenticated user
        instagram_user_data = InstagramUser_data.objects.get(user=request.user)

        # Calculate the total of followers and following
        total_count = instagram_user_data.instagram_follower_count + instagram_user_data.instagram_following_count

        # Check if the total count is <= 20,000
        return Response({
            "status": total_count <= 20000  # Returns True if total <= 20,000, else False
        }, status=status.HTTP_200_OK)

    except InstagramUser_data.DoesNotExist:
        return Response({
            "error": "Instagram user data not found"
        }, status=status.HTTP_404_NOT_FOUND)

    except Exception as e:
        print(f"An error occurred: {e}")
        return Response({
            "error": "An error occurred",
            "details": str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)






#bech traj3elna yekhi awl marra wala le
@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def get_first_time_flag(request):
    try:
        # Fetch the FrontFlags object for the authenticated user
        front_flag = FrontFlags.objects.get(user=request.user)

        return Response({
            "is_first_time_connected_flag": front_flag.is_first_time_connected_flag
        }, status=status.HTTP_200_OK)

    except FrontFlags.DoesNotExist:
        return Response({
            "error": "Front flag data not found"
        }, status=status.HTTP_404_NOT_FOUND)

    except Exception as e:
        print(f"An error occurred: {e}")
        return Response({
            "error": "An error occurred",
            "details": str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    






@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def update_first_time_flag(request):
    try:
        # Fetch the FrontFlags object for the authenticated user
        front_flag, created = FrontFlags.objects.get_or_create(user=request.user)

        # Get the new flag value from the request data
        new_flag_value = request.data.get('is_first_time_connected_flag')

        if new_flag_value is None:
            return Response({
                "error": "The 'is_first_time_connected_flag' field is required"
            }, status=status.HTTP_400_BAD_REQUEST)

        # Update the flag with the new value
        front_flag.is_first_time_connected_flag = new_flag_value
        front_flag.save()

        return Response({
            "is_first_time_connected_flag": front_flag.is_first_time_connected_flag
        }, status=status.HTTP_200_OK)

    except Exception as e:
        print(f"An error occurred: {e}")
        return Response({
            "error": "An error occurred",
            "details": str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    








# return if 12 hours passed from last fech true or false
@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def check_12_hours_passed(request):
    try:
        # Fetch the InstagramUser_data object for the authenticated user
        user_data = InstagramUser_data.objects.filter(user=request.user).first()

        if not user_data:
            return Response({
                "error": "No Instagram data found for this user"
            }, status=status.HTTP_404_NOT_FOUND)

        # Check if 12 hours have passed since last_time_fetched
        has_passed = user_data.has_12_hours_passed_since_last_fetch()

        return Response({"has_12_hours_passed": has_passed}, status=status.HTTP_200_OK)

    except Exception as e:
        return Response({
            "error": "An error occurred",
            "details": str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)