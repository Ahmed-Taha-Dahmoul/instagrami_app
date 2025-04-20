import requests
import json

url = "https://www.instagram.com/graphql/query"

headers = {
    "accept": "*/*",
    "accept-language": "fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7",
    "content-type": "application/x-www-form-urlencoded",
    "origin": "https://www.instagram.com",
    "referer": "https://www.instagram.com/tasnim_prv__/?next=/",
    "sec-ch-prefers-color-scheme": "dark",
    "sec-ch-ua": '"Google Chrome";v="135", "Not-A.Brand";v="8", "Chromium";v="135"',
    "sec-ch-ua-full-version-list": '"Google Chrome";v="135.0.7049.41", "Not-A.Brand";v="8.0.0.0", "Chromium";v="135.0.7049.41"',
    "sec-ch-ua-mobile": "?1",
    "sec-ch-ua-model": '"Nexus 5"',
    "sec-ch-ua-platform": '"Android"',
    "sec-ch-ua-platform-version": '"6.0"',
    "sec-fetch-dest": "empty",
    "sec-fetch-mode": "cors",
    "sec-fetch-site": "same-origin",
    "user-agent": "Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Mobile Safari/537.36",
    "x-asbd-id": "359341",
    "x-bloks-version-id": "0d99de0d13662a50e0958bcb112dd651f70dea02e1859073ab25f8f2a477de96",
    "x-csrftoken": "pQJb3VFbYYKpgpjXsOsy9bQ93gxRf5ky",
    "x-fb-friendly-name": "PolarisProfilePageContentQuery",
    "x-fb-lsd": "9-sySrHsgup72DB0aMhIJg",
    "x-ig-app-id": "1217981644879628",
    "cookie": "ig_nrcb=1; mid=Z9QvYAALAAENkA9fPhQjrim-grWF; ig_did=840B2684-497C-4325-A38F-525B3BFA6330; datr=GnTdZ3YE24eFkNMQH6rjblxF; csrftoken=pQJb3VFbYYKpgpjXsOsy9bQ93gxRf5ky; sessionid=YOUR_SESSION_ID; ds_user_id=40811006809; rur=\"LDC\\05440811006809\\0541775327492:01f71839c09e6b0deb9c7d60969036e289323ab6b2b1108d06a8505243f40dd24f05a9f4\"; wd=1226x296; dpr=2"
}

# Instagram user ID (replace with your target user)
user_id = "40811006809"

variables = {
    "id": user_id,
    "render_surface": "PROFILE"
}

data = {
    "av": "17841441004271375",
    "__d": "www",
    "__user": "0",
    "__a": "1",
    "__req": "5",
    "dpr": "2",
    "server_timestamps": "true",
    "doc_id": "9707764636006837",
    "fb_api_caller_class": "RelayModern",
    "fb_api_req_friendly_name": "PolarisProfilePageContentQuery",
    "variables": json.dumps(variables)
}

response = requests.post(url, headers=headers, data=data)

if response.status_code == 200:
    print("✅ Profile data fetched successfully!")

    with open("profile_data.json", "w", encoding="utf-8") as f:
        json.dump(response.json(), f, ensure_ascii=False, indent=4)

    print("📁 Saved to 'profile_data.json'")
else:
    print(f"❌ Failed with status code {response.status_code}")
    print(response.text)
