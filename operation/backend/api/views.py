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
    """Update mutual follow relationships with full user info."""
    
    # Convert followers and following lists to sets of user dictionaries
    following_dict = {user["id"]: user for user in instagram_data.new_following_list}
    followers_dict = {user["id"]: user for user in instagram_data.new_followers_list}

    # Find who the user follows but they don't follow back (store full user info)
    instagram_data.who_i_follow_he_dont_followback = [
        following_dict[id] for id in following_dict.keys() if id not in followers_dict
    ]

    # Find who follows the user but the user doesn't follow back (store full user info)
    instagram_data.who_i_dont_follow_he_followback = [
        followers_dict[id] for id in followers_dict.keys() if id not in following_dict
    ]

    instagram_data.save()



def update_removed_follow(instagram_data, old_list, new_list, field_name):
    """Update the list of removed followers or following with full user info."""
    
    if not isinstance(old_list, list):
        old_list = []
    if not isinstance(new_list, list):
        new_list = []

    # Ensure old_list and new_list contain dictionaries
    old_dict = {user["id"]: user for user in old_list if isinstance(user, dict) and "id" in user}
    new_dict = {user["id"]: user for user in new_list if isinstance(user, dict) and "id" in user}

    # Find removed users (store full user info)
    removed_users = [old_dict[id] for id in old_dict.keys() if id not in new_dict]

    # Retrieve the existing removed list from the model
    existing_removed = getattr(instagram_data, field_name, [])

    # Ensure existing_removed is a list of dictionaries
    if not isinstance(existing_removed, list):
        existing_removed = []

    existing_removed_dict = {user["id"]: user for user in existing_removed if isinstance(user, dict) and "id" in user}

    # Merge existing and new removed users while ensuring uniqueness
    updated_removed_dict = {**existing_removed_dict, **{user["id"]: user for user in removed_users}}

    # Assign the updated list back to the correct field
    setattr(instagram_data, field_name, list(updated_removed_dict.values()))

    instagram_data.save()







@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def save_fetched_followers(request):
    """Receives the following list from Flutter and updates the database."""
    try:
        user = request.user
        followers_list = request.data.get("followers_list")
        
        if not isinstance(followers_list, list):
            
            return Response({"error": "Invalid data format. Expecting a list."}, status=status.HTTP_400_BAD_REQUEST)

        instagram_data = InstagramUser_data.objects.filter(user=user).first()
        
        if not instagram_data:
            return Response({"error": "Instagram data not found for this user."}, status=status.HTTP_404_NOT_FOUND)

        # Backup the old following list before updating
        instagram_data.old_followers_list = instagram_data.new_followers_list
        instagram_data.new_followers_list = followers_list  # Saving the complete list

        instagram_data.update_last_fetched_time()
        # Directly save the following list as JSON in the database
        instagram_data.save()
        update_follow_relationships(instagram_data)
        update_removed_follow(instagram_data, instagram_data.old_followers_list, instagram_data.new_followers_list, "who_removed_follower")
        return Response({"message": "Followers list updated successfully."}, status=status.HTTP_200_OK)

    except Exception as e:
        print(f"Error: {str(e)}")
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
        update_removed_follow(instagram_data, instagram_data.old_following_list, instagram_data.new_following_list, "who_removed_following")

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

        # Directly retrieve the full user data from who_i_follow_he_dont_followback
        unfollowed_back_users = instagram_user_data.who_i_follow_he_dont_followback

        # Ensure it is a list of dictionaries
        if not isinstance(unfollowed_back_users, list):
            unfollowed_back_users = []

        # Paginate the results
        paginator = CustomPagination()
        paginated_data = paginator.paginate_queryset(unfollowed_back_users, request)

        return paginator.get_paginated_response(paginated_data)

    except InstagramUser_data.DoesNotExist:
        return Response({"error": "Instagram user data not found"}, status=404)




@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def remove_following(request):
    try:
        # Fetch InstagramUser_data for the authenticated user
        user_data = InstagramUser_data.objects.get(user=request.user)

        # Extract id from request body
        id = request.data.get("id")
        if not id:
            return Response({"error": "Missing 'id' in request body"}, status=status.HTTP_400_BAD_REQUEST)

        # Ensure id is in the following list and get the user data from following list
        user_in_following = next((user for user in user_data.new_following_list if user["id"] == id), None)
        if not user_in_following:
            return Response({"error": "User not found in following list"}, status=status.HTTP_400_BAD_REQUEST)

        # Remove the user from the new following list
        user_data.new_following_list = [f for f in user_data.new_following_list if f["id"] != id]

        # Decrease the count if it's greater than zero
        if user_data.instagram_following_count > 0:
            user_data.instagram_following_count -= 1

        # Remove the user from who_i_follow_he_dont_followback list (no extra logic)
        user_data.who_i_follow_he_dont_followback = [
            user for user in user_data.who_i_follow_he_dont_followback if user["id"] != id
        ]

        # Save changes
        user_data.save()

        return Response({"message": "User removed from following list and 'who_i_follow_he_dont_followback' updated successfully"}, status=status.HTTP_200_OK)
    
    except InstagramUser_data.DoesNotExist:
        return Response({"error": "Instagram user data not found"}, status=status.HTTP_400_BAD_REQUEST)








#traja3 el yfollow fiya weni le

@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def get_dont_follow_back_you(request):
    try:
        instagram_user_data = InstagramUser_data.objects.get(user=request.user)

        # Directly retrieve the full user data from who_i_dont_follow_he_followback
        dont_follow_back_users = instagram_user_data.who_i_dont_follow_he_followback

        # Ensure it is a list of dictionaries
        if not isinstance(dont_follow_back_users, list):
            dont_follow_back_users = []

        # Set up pagination
        paginator = CustomPagination()
        paginated_data = paginator.paginate_queryset(dont_follow_back_users, request)

        return paginator.get_paginated_response(paginated_data)

    except InstagramUser_data.DoesNotExist:
        return Response({"error": "Instagram user data not found"}, status=404)

    
@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def remove_follower(request):
    try:
        # Fetch InstagramUser_data for the authenticated user
        user_data = InstagramUser_data.objects.get(user=request.user)

        # Extract id from request body
        id = request.data.get("id")
        if not id:
            return Response({"error": "Missing 'id' in request body"}, status=status.HTTP_400_BAD_REQUEST)

        # Ensure id is in the follower list
        user_in_followers = next((user for user in user_data.new_followers_list if user["id"] == id), None)
        if not user_in_followers:
            return Response({"error": "User not found in follower list"}, status=status.HTTP_400_BAD_REQUEST)

        # Remove the user from the new follower list
        user_data.new_followers_list = [f for f in user_data.new_followers_list if f["id"] != id]

        # Decrease the follower count if it's greater than zero
        if user_data.instagram_follower_count > 0:
            user_data.instagram_follower_count -= 1

        # Update who I follow but they don't follow back with full user data (not just id)
        follower_ids = {user["id"] for user in user_data.new_followers_list}
        user_data.who_i_dont_follow_he_followback = [user for user in user_data.who_i_dont_follow_he_followback if user["id"] in follower_ids]

        # Save changes
        user_data.save()

        return Response({"message": "User removed from follower list successfully"}, status=status.HTTP_200_OK)

    except InstagramUser_data.DoesNotExist:
        return Response({"error": "Instagram user data not found"}, status=status.HTTP_400_BAD_REQUEST)




#bech traja3 chkoun ne7eli follow
@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def get_unfollowed_you(request):
    try:
        instagram_user_data = InstagramUser_data.objects.get(user=request.user)

        # Directly retrieve the full user data from who_removed_follower
        unfollowed_back_users = instagram_user_data.who_removed_follower

        # Ensure it is a list of dictionaries
        if not isinstance(unfollowed_back_users, list):
            unfollowed_back_users = []

        # Set up pagination
        paginator = CustomPagination()
        paginated_data = paginator.paginate_queryset(unfollowed_back_users, request)

        return paginator.get_paginated_response(paginated_data)

    except InstagramUser_data.DoesNotExist:
        return Response({"error": "Instagram user data not found"}, status=404)





@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def remove_unfollowed_you(request):
    user = request.user
    user_id_to_remove = request.data.get('user_id')  # Get user_id from request body

    if not user_id_to_remove:
        return Response({"error": "user_id is required"}, status=status.HTTP_400_BAD_REQUEST)

    try:
        instagram_user_data = InstagramUser_data.objects.get(user=user)

        # Find the user in who_removed_follower by id
        user_to_remove = next((user for user in instagram_user_data.who_removed_follower if user["id"] == user_id_to_remove), None)

        if user_to_remove:
            instagram_user_data.who_removed_follower.remove(user_to_remove)  # Remove the full user data
            instagram_user_data.save()  # Save changes

            return Response({"message": "User removed successfully"}, status=status.HTTP_200_OK)
        else:
            return Response({"error": "User_id not found in who_removed_follower"}, status=status.HTTP_404_NOT_FOUND)

    except InstagramUser_data.DoesNotExist:
        return Response({"error": "Instagram user data not found"}, status=status.HTTP_404_NOT_FOUND)

    





#bech traja3 chkoun ne7eni ma3edech ntaba3 fih
@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def get_who_removed_you(request):
    try:
        instagram_user_data = InstagramUser_data.objects.get(user=request.user)

        # Directly retrieve the full user data from who_removed_following
        unfollowed_back_users = instagram_user_data.who_removed_following

        # Ensure it is a list of dictionaries
        if not isinstance(unfollowed_back_users, list):
            unfollowed_back_users = []

        # Set up pagination
        paginator = CustomPagination()
        paginated_data = paginator.paginate_queryset(unfollowed_back_users, request)

        return paginator.get_paginated_response(paginated_data)

    except InstagramUser_data.DoesNotExist:
        return Response({"error": "Instagram user data not found"}, status=404)
    



@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def remove_removed_you(request):
    user = request.user
    user_id_to_remove = request.data.get('user_id')  # Get user_id from request body

    if not user_id_to_remove:
        return Response({"error": "user_id is required"}, status=status.HTTP_400_BAD_REQUEST)

    try:
        instagram_user_data = InstagramUser_data.objects.get(user=user)

        # Find the user in who_removed_following by id
        user_to_remove = next((user for user in instagram_user_data.who_removed_following if user["id"] == user_id_to_remove), None)

        if user_to_remove:
            instagram_user_data.who_removed_following.remove(user_to_remove)  # Remove the full user data
            instagram_user_data.save()  # Save changes

            return Response({"message": "User removed successfully"}, status=status.HTTP_200_OK)
        else:
            return Response({"error": "User_id not found in who_removed_following"}, status=status.HTTP_404_NOT_FOUND)

    except InstagramUser_data.DoesNotExist:
        return Response({"error": "Instagram user data not found"}, status=status.HTTP_404_NOT_FOUND)







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
        print(user)
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
    
    
@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def change_unfollow_status(request):
    try:
        unfollow_status = request.data.get('unfollow_status')

        

        if unfollow_status is not None:
            instagram_user_data = InstagramUser_data.objects.get(user=request.user)
            instagram_user_data.unfollowed = unfollow_status
            instagram_user_data.save()

            # Returning a success response
            return Response({
                "message": "Unfollow status updated successfully"
            }, status=status.HTTP_200_OK)
        else:
            return Response({
                "error": "Unfollow status is required"
            }, status=status.HTTP_400_BAD_REQUEST)

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
    

from datetime import timedelta
from django.utils.timezone import now

@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def update_last_time_fetched(request):
    try:
        # Get the InstagramUser_data instance for the logged-in user
        instagram_user_data = InstagramUser_data.objects.get(user=request.user)
        
        # Calculate the time 24 hours ago from now
        new_time = now() - timedelta(hours=0.5)
        
        # Update the 'last_time_fetched' field
        instagram_user_data.last_time_fetched = new_time
        instagram_user_data.save()

        # Return a success response
        return Response({
            "message": "last_time_fetched updated to 24 hours ago"
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






















