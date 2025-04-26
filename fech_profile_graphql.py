import requests
import json

url = "https://www.instagram.com/graphql/query"


csrftoken= "J0tDJyPkpowe430IxGhNm4CikyEgySeK"
userId= "7931218225"
sessionId="7931218225%3AcwtqrwLRg5jQEI%3A0%3AAYcBhEp5-WAw3-vvV7G8UubLSucq7HNY55jdjlTdig"
xIgAppId = "1217981644879628"

headers = {
    "cookie": f"csrftoken={csrftoken}; ds_user_id={userId}; sessionid={sessionId}",
    "x-csrftoken": csrftoken,
    "x-ig-app-id": xIgAppId,
    "user-agent": "Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Mobile Safari/537.36",
}


# Instagram user ID (replace with your target user)
user_id = "7931218225"

variables = {
    "id": user_id,
    "render_surface": "PROFILE"
}

data = {
    "doc_id": "9707764636006837",
    "fb_api_req_friendly_name": "PolarisProfilePageContentQuery",
    "variables": json.dumps(variables)
}

response = requests.post(url, headers=headers, data=data)

if response.status_code == 200:
    print("✅ Profile data fetched successfully!")

    with open(f"profile_data_with header_{user_id}.json", "w", encoding="utf-8") as f:
        json.dump(response.json(), f, ensure_ascii=False, indent=4)

    print("📁 Saved to 'profile_data.json'")
else:
    print(f"❌ Failed with status code {response.status_code}")
    print(response.text)
