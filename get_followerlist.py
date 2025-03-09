import requests
import random
import json

# User-defined variables
userId = '40811006809'  # Replace with the target user's ID
count = 200  # Number of followers to fetch per request (you can adjust this as needed)
csrftoken = '03MLQ8obwFNm4eitB78WttC49oViffye'  # Replace with your CSRF token
sessionId = '40811006809%3AvR9Ly3Wnoz1uxM%3A6%3AAYe3oOPSjTttKThzX_BGhmN-7kJXr7sQMFhzZMvOZg'  # Replace with your session ID
xIgAppId = '936619743392459'  # Replace with your Instagram app ID
userAgentList = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/64.0.3282.140 Safari/537.36 Edge/17.17134"
    # Add more user agents as necessary
]

# Randomly choose a user-agent from the list
userAgent = random.choice(userAgentList)

# URL to fetch followers
url = f'https://www.instagram.com/api/v1/friendships/{userId}/followers/?count={count}'

# Headers
headers = {
    "cookie": f"csrftoken={csrftoken}; ds_user_id={userId}; sessionid={sessionId}",
    "referer": f"https://www.instagram.com/{userId}/following/",
    "x-csrftoken": csrftoken,
    "x-ig-app-id": xIgAppId,
    "user-agent": userAgent,
}

# Function to fetch followers with pagination (using nextMaxId)
def fetch_all_followers():
    all_followers = []  # List to store all fetched followers
    next_max_id = ''  # Variable to store nextMaxId for pagination
    
    while True:
        # If there's a nextMaxId, append it to the URL for pagination
        paginated_url = f"{url}&max_id={next_max_id}" if next_max_id else url
        
        try:
            response = requests.get(paginated_url, headers=headers)
            
            # Check if the request was successful
            if response.status_code == 200:
                data = response.json()
                
                # Add fetched followers to the list
                all_followers.extend(data['users'])
                
                # Check if there is more data to fetch
                next_max_id = data.get('next_max_id')
                if not next_max_id:
                    break  # No more followers to fetch, exit the loop

            else:
                print(f"Error fetching followers: {response.status_code} - {response.text}")
                break  # Exit the loop if there is an error

        except requests.exceptions.RequestException as e:
            print(f"An error occurred: {e}")
            break  # Exit the loop in case of request failure
    
    # Save the all followers data to a JSON file
    with open('followers.json', 'w') as json_file:
        json.dump(all_followers, json_file, indent=4)
    print(f"All followers have been saved to 'followers.json'.")

# Run the function to fetch all followers
fetch_all_followers()
