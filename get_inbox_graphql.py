import requests
import json

# Your authentication details
csrftoken = "bi38AtyLygnZaIjnMFjc72w9AvBSz2CD"
userId = "5100464648"
sessionId = "5100464648%3AZDSJsi2UjBaePO%3A9%3AAYc_wLAJZy9nX_57Oj7pdZ1GXMOiWwGxjfL9g4uXQQ"
xIgAppId = "1217981644879628"
target_user_id = "5100464648"  # The user whose "following" list you want to fetch

# Headers
headers = {
    "cookie": f"csrftoken={csrftoken}; ds_user_id={userId}; sessionid={sessionId}",
    "x-csrftoken": csrftoken,
    "x-ig-app-id": xIgAppId,
    "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36",
    "accept": "*/*",
    "accept-language": "en-US,en;q=0.9",
    "sec-fetch-site": "same-origin",
    "sec-fetch-mode": "cors",
    "sec-fetch-dest": "empty",
}

# GraphQL URL
query_hash = "AT5sP-6HzlJypb897i4"
variables = json.dumps({"id": target_user_id, "first": 20})
url = f"https://www.instagram.com/graphql/query/?query_hash={query_hash}&variables={variables}"

# Make the request
response = requests.get(url, headers=headers)

# Save the result to a JSON file
output_file = "instagram_response.json"
if response.status_code == 200:
    data = response.json()
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4)
    print(f"Response saved to {output_file}")
else:
    print(f"Error: {response.status_code}, {response.text}")