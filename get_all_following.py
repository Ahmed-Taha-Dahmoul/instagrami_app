import requests
import json

# Set your variables here
csrftoken = "bi38AtyLygnZaIjnMFjc72w9AvBSz2CD"
userId = "5100464648"
sessionId = "5100464648%3AZDSJsi2UjBaePO%3A9%3AAYc_wLAJZy9nX_57Oj7pdZ1GXMOiWwGxjfL9g4uXQQ"
xIgAppId = "1217981644879628"
target_user_id = "5100464648"   # The user whose "following" list you want to fetch

# Headers
headers = {
    "cookie": f"csrftoken={csrftoken}; ds_user_id={userId}; sessionid={sessionId}",
    "referer": f"https://www.instagram.com/{userId}/following/",
    "x-csrftoken": csrftoken,
    "x-ig-app-id": xIgAppId,
    "user-agent": "Instagram 253.0.0.19.105 Android",  # Mimicking Instagram app request
}

# API Endpoint
base_url = f"https://www.instagram.com/api/v1/friendships/{target_user_id}/following/"

all_users = []  # List to store all following users
next_max_id = None  # Used for pagination

while True:
    # Add pagination parameter if needed
    url = base_url if next_max_id is None else f"{base_url}?max_id={next_max_id}"
    print(url)
    
    # Send GET request
    response = requests.get(url, headers=headers)
    
    if response.status_code == 200:
        data = response.json()
        all_users.extend(data.get("users", []))  # Add users to list
        
        # Check if there is another page of results
        next_max_id = data.get("next_max_id")
        if not next_max_id:  # If no more pages, break the loop
            break
    else:
        print(f"Failed! Status Code: {response.status_code}")
        print(response.text)
        break  # Stop if request fails

# Save to JSON file
filename = f"{target_user_id}_following.json"
with open(filename, "w", encoding="utf-8") as file:
    json.dump(all_users, file, indent=4, ensure_ascii=False)

print(f"Success! {len(all_users)} users saved to {filename}")
