import requests

def get_instagram_user_info(user_id, csrftoken, sessionid, xIgAppId):
    url = f"https://www.instagram.com/api/v1/users/{user_id}/info/"
    
    headers = {
        "cookie": f"csrftoken={csrftoken}; ds_user_id={user_id}; sessionid={sessionid}",
        "referer": f"https://www.instagram.com/api/v1/users/{user_id}/info/",
        "x-csrftoken": csrftoken,
        "x-ig-app-id": xIgAppId,
    }
    
    response = requests.get(url, headers=headers)
    
    if response.status_code == 200:
        return response.json()
    else:
        return {"error": f"Failed to fetch data: {response.status_code}", "details": response.text}

# Example usage:
# Replace with actual values before running
user_id = "23123721451"
csrftoken = "FPmo6Sf0hM0NCMEZvwZhT4LHTbOmhGsE"
sessionid = "3028440064%3AIbHG9eq28wvIxJ%3A27%3AAYdcgdqe6PvM63DalFJVVf2yU_-qw0exnhXwt2xGyQ"
xIgAppId = "1217981644879628"

user_info = get_instagram_user_info(user_id, csrftoken, sessionid, xIgAppId)
print(user_info)
