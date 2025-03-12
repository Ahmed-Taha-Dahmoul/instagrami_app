import requests
import json

def get_instagram_user_info(username, user_id, csrftoken, session_id, x_ig_app_id):
    url = f"https://www.instagram.com/api/v1/web/search/topsearch/?context=blended&query={username}&include_reel=false"
    
    headers = {
        "cookie": f"csrftoken={csrftoken}; ds_user_id={user_id}; sessionid={session_id}",
        "referer": url,
        "x-csrftoken": csrftoken,
        "x-ig-app-id": x_ig_app_id,
    }
    
    response = requests.get(url, headers=headers)
    return response.json()

# Example usage
user_id = "40811006809"  # Replace with the actual user ID
session_id = "40811006809%3Ai67L2FJNMFigXS%3A16%3AAYcZ7DEUnwvaD2OAf-XEjSwRkoRK2FfncI2L7t_06g"  # Replace with your session ID
csrftoken = "23nM7beAk1F8YWAVtEI7n7nl89R5FTwP"  # Replace with your CSRF token
x_ig_app_id = "1217981644879628"
username = "tasnim_prv__"

response_data = get_instagram_user_info(username, user_id, csrftoken, session_id, x_ig_app_id)

# Save the response to a JSON file
with open('instagram_user_info.json', 'w') as json_file:
    json.dump(response_data, json_file, indent=4)

print("User info has been saved to instagram_user_info.json")
