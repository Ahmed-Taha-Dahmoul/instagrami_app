import requests
import json

# Parameters
csrftoken = "J0tDJyPkpowe430IxGhNm4CikyEgySeK"
userId = "7931218225"
sessionId = "7931218225%3AcwtqrwLRg5jQEI%3A0%3AAYcBhEp5-WAw3-vvV7G8UubLSucq7HNY55jdjlTdig"
xIgAppId = "1217981644879628"
target_user_id = "7931218225"  # The user whose "following" list you want to fetch

# Headers
headers = {
    "cookie": f"csrftoken={csrftoken}; ds_user_id={userId}; sessionid={sessionId}",
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
    with open("instagram_inbox_response_mar.json", "w") as json_file:
        json.dump(response.json(), json_file, indent=4)  # Pretty print with indent
    print("Response successfully saved to 'instagram_inbox_response.json'")
else:
    print(f"Error: {response.status_code}")
    print(response.text)
