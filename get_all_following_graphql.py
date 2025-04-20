import requests
import json

def fetch_instagram_data(user_id, first, session_id, csrftoken, x_ig_app_id):
    url = "https://www.instagram.com/graphql/query/"
    query_hash = "58712303d941c6855d4e888c5f0cd22f"
    
    variables = {
        "id": str(user_id),
        "first": first
    }
    
    headers = {
        "cookie": f"csrftoken={csrftoken}; ds_user_id={user_id}; sessionid={session_id}",
        "x-csrftoken": csrftoken,
        "x-ig-app-id": x_ig_app_id,
    }
    
    params = {
        "query_hash": query_hash,
        "variables": json.dumps(variables)
    }
    
    response = requests.get(url, headers=headers, params=params)
    
    if response.status_code == 200:
        return response.json()
    else:
        return {"error": f"Request failed with status code {response.status_code}", "details": response.text}

def save_to_json(data, filename="output.json"):
    with open(filename, "w", encoding="utf-8") as file:
        json.dump(data, file, indent=4, ensure_ascii=False)

# Example usage
if __name__ == "__main__":
    user_id = "40811006809"  # Replace with the actual user ID
    first = 20  # Number of results to fetch
    session_id = "40811006809%3Ai67L2FJNMFigXS%3A16%3AAYcZ7DEUnwvaD2OAf-XEjSwRkoRK2FfncI2L7t_06g"  # Replace with your session ID
    csrftoken = "23nM7beAk1F8YWAVtEI7n7nl89R5FTwP"  # Replace with your CSRF token
    x_ig_app_id = "1217981644879628"  # Replace with your IG App ID
    
    data = fetch_instagram_data(user_id, first, session_id, csrftoken, x_ig_app_id)
    save_to_json(data)
    print("Data saved to output.json")