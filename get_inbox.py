import requests
import json

# Parameters
csrftoken = "bi38AtyLygnZaIjnMFjc72w9AvBSz2CD"
userId = "5100464648"
sessionId = "5100464648%3AZDSJsi2UjBaePO%3A9%3AAYc_wLAJZy9nX_57Oj7pdZ1GXMOiWwGxjfL9g4uXQQ"
xIgAppId = "1217981644879628"
target_user_id = "5100464648"  # The user whose "following" list you want to fetch

# Headers
headers = {
    "cookie": f"csrftoken={csrftoken}; ds_user_id={userId}; sessionid={sessionId}",
    "referer": f"https://www.instagram.com/{userId}/following/",
    "x-csrftoken": csrftoken,
    "x-ig-app-id": xIgAppId,
}

# Endpoint URL
url = "https://www.instagram.com/api/v1/direct_v2/inbox/"

# Make the GET request to fetch inbox data
response = requests.get(url, headers=headers)

# Check if the response is successful
if response.status_code == 200:
    # Save the response JSON to a file
    with open("instagram_inbox_response.json", "w") as json_file:
        json.dump(response.json(), json_file, indent=4)  # Pretty print with indent
    print("Response successfully saved to 'instagram_inbox_response.json'")
else:
    print(f"Error: {response.status_code}")
    print(response.text)
