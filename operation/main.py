import json
import requests
from instagram_scrape_cookies import get_dynamic_instagram_data
from instagram_following_request import get_instagram_following
from instagram_cookies_update import update_instagram_data

USER_DATA_FILE = "users_data.json"

def load_user_data():
    """Loads user data from users_data.json."""
    try:
        with open(USER_DATA_FILE, 'r', encoding='utf-8') as f:
            users_data = json.load(f)
            # Assuming the first user in the list is the one we want to use
            if users_data and isinstance(users_data, list):
                return users_data[0]  # Get the first user if multiple users exist
            return None
    except (FileNotFoundError, json.JSONDecodeError):
        return None

def ensure_user_data():
    """Ensures that users_data.json exists and contains valid data."""
    user_data = load_user_data()
    if not user_data:
        print("No valid user data found. Logging in to create it...")
        user_data = get_dynamic_instagram_data()  # Login and retrieve cookies
        if user_data:
            print("User data saved successfully.")
        else:
            print("Failed to retrieve user data. Exiting.")
            exit(1)
    return user_data

if __name__ == '__main__':
    user_data = ensure_user_data()

    while True:
        # Prepare the data for the request
        instagram_data = {
            'user_id': user_data['user_id'],
            'session_id': user_data['session_id'],
            'csrftoken': user_data['csrftoken'],
            'x_ig_app_id': user_data['x_ig_app_id']
        }

        # Get the list of users the user is following
        following_list = get_instagram_following(
            instagram_data['user_id'],
            instagram_data['session_id'],
            instagram_data['csrftoken'],
            instagram_data['x_ig_app_id']
        )

        # Check if the request failed (None means error)
        if following_list is None:
            print("Failed to retrieve following list. Attempting to update Instagram cookies...")
            update_instagram_data()  # Update the session data without parameters
            user_data = ensure_user_data()  # Reload the updated user data from the file
            if user_data:
                print("Instagram cookies updated successfully.")
                # After updating the cookies, retry the request
                instagram_data['csrftoken'] = user_data['csrftoken']
                instagram_data['session_id'] = user_data['session_id']
                instagram_data['x_ig_app_id'] = user_data['x_ig_app_id']
                continue  # Retry fetching the following list with updated data
            else:
                print("Failed to update Instagram cookies. Exiting.")
                exit(1)

        if following_list:
            print("Successfully retrieved following list.")
            # Save or process `following_list` as needed
            break
        else:
            print("Failed to retrieve following list.")
            break
