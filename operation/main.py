import json
import requests
from instagram_scrape_cookies import get_dynamic_instagram_data
from instagram_following_request import get_instagram_following
from instagram_cookies_update import update_instagram_data


USER_DATA_FILE = "users_data.json"
FOLLOWING_LIST_FILE = "following_list.json"

def load_user_data():
    """Loads user data from users_data.json."""
    try:
        with open(USER_DATA_FILE, 'r', encoding='utf-8') as f:
            users_data = json.load(f)
            print("Loaded user data:", users_data)  # Debugging
            if users_data and isinstance(users_data, list):
                print("Returning first user:", users_data[0])  # Debugging
                return users_data[0]
            return None
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"Error loading user data: {e}")  # Debugging
        return None


def ensure_user_data():
    """Ensures that users_data.json exists and contains valid data."""
    user_data = load_user_data()
    if not user_data:
        print("No valid user data found. Logging in to create it...")
        user_data = get_dynamic_instagram_data()
        if user_data:
            print("User data saved successfully.")
        else:
            print("Failed to retrieve user data. Exiting.")
            exit(1)
    return user_data


def save_following_list(following_list):
    """Saves the following list to a JSON file."""
    try:
        with open(FOLLOWING_LIST_FILE, 'w', encoding='utf-8') as f:
            json.dump(following_list, f, indent=4, ensure_ascii=False)
        print(f"Following list saved to {FOLLOWING_LIST_FILE}")
    except Exception as e:
        print(f"Error saving following list: {e}")

if __name__ == '__main__':
    user_data = ensure_user_data()

    while True:
        instagram_data = {
            'user_id': user_data['user_id'],
            'session_id': user_data['session_id'],
            'csrftoken': user_data['csrftoken'],
            'x_ig_app_id': user_data['x_ig_app_id']
        }

        following_list = get_instagram_following(
            instagram_data['user_id'],
            instagram_data['session_id'],
            instagram_data['csrftoken'],
            instagram_data['x_ig_app_id']
        )

        if following_list is None:
            print("Failed to retrieve following list. Attempting to update Instagram cookies...")
            update_instagram_data()
            user_data = ensure_user_data()
            if user_data:
                print("Instagram cookies updated successfully.")
                instagram_data['csrftoken'] = user_data['csrftoken']
                instagram_data['session_id'] = user_data['session_id']
                instagram_data['x_ig_app_id'] = user_data['x_ig_app_id']
                continue
            else:
                print("Failed to update Instagram cookies. Exiting.")
                exit(1)

        if following_list:
            print("Successfully retrieved following list.")
            save_following_list(following_list)
            break
        else:
            print("Failed to retrieve following list.")
            break