import requests

# Instagram Search Function
def instagram_search(query, session_id):
    url = f"https://www.instagram.com/api/v1/web/search/topsearch/?context=blended&query={query}&include_reel=false"
    
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Referer": "https://www.instagram.com/",
        "X-IG-App-ID": "936619743392459"  # May need updating if Instagram changes it
    }

    cookies = {
        "sessionid": session_id  # Instagram login session ID (must be obtained from browser)
    }

    response = requests.get(url, headers=headers, cookies=cookies)
    
    if response.status_code == 200:
        return response.json()
    elif response.status_code == 401:
        print("Unauthorized: Invalid session ID.")
    else:
        print(f"Error {response.status_code}: {response.text}")
    
    return None

# Example usage
query = input("Enter search query: ")
session_id = input("Enter your Instagram session ID: ")  # You need to get this from your logged-in browser

results = instagram_search(query, session_id)

# Display results
print(results)
