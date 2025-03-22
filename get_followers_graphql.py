import requests
import json

def fetch_instagram_followers(user_id, first, session_id, csrftoken, xIgAppId, user_agent):
    all_followers = []  # List to store all fetched followers
    next_max_id = None  # Variable to store next_max_id for pagination
    url = "https://www.instagram.com/graphql/query/"
    query_hash = "37479f2b8209594dde7facb0d904896a"  # Fixed query hash for followers

    headers = {
        "cookie": f"csrftoken={csrftoken}; ds_user_id={user_id}; sessionid={session_id}",
        "x-csrftoken": csrftoken,
        "x-ig-app-id": xIgAppId,
        "user-agent": user_agent,
    }

    try:
        while True:
            # Variables for the query, including pagination
            variables = {
                "id": user_id,  # Use user_id here instead of PK
                "first": first,
                "after": next_max_id,  # Use next_max_id for pagination
            }

            # Encode the variables to a JSON string
            params = {
                "query_hash": query_hash,
                "variables": json.dumps(variables),
            }

            # Send the GET request
            response = requests.get(url, headers=headers, params=params)

            if response.status_code == 200:
                # Save the raw response body to a JSON file
                with open(f'followers_response_{user_id}.json', 'a') as json_file:
                    json.dump(response.json(), json_file, indent=4)
                    json_file.write("\n")  # Newline for each response block

                data = response.json()

                # Extract the list of followers
                followers = data['data']['user']['edge_followed_by']['edges']
                all_followers.extend(followers)

                # Check if there is more data to fetch
                next_max_id = data['data']['user']['edge_followed_by']['page_info'].get('end_cursor')

                if not next_max_id:
                    break  # No more followers to fetch, exit the loop
            else:
                print(f"Error fetching followers: {response.status_code} - {response.text}")
                break  # Exit the loop if there is an error

        # Return the list of all followers
        return all_followers

    except Exception as e:
        print(f"An error occurred: {e}")
        return None  # Return None in case of an error


# Example usage
if __name__ == "__main__":
    # Replace with your actual Instagram values
    user_id = "40811006809"  # The user ID (can be fetched from the user’s page)
    first = 50  # Number of followers per request (can adjust this as needed)
    session_id = "40811006809%3AUb358ZHb5SQPxK%3A16%3AAYd0bSEdKqw2jRRbsHqvxAuxzxvFwWn04pjYjfo0Hg"
    csrftoken = "JQqWAvxc4QYdKsk0XBHuJm1KUPPoqAEj"
    xIgAppId = "1217981644879628"
    user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3"  # You can use a random User-Agent string

    followers = fetch_instagram_followers(user_id, first, session_id, csrftoken, xIgAppId, user_agent)
    if followers:
        print(f"Total followers fetched: {len(followers)}")
        # Optionally print a few follower names or ids
        for follower in followers[:10]:  # Print first 10 followers as an example
            print(follower)
    else:
        print("Failed to fetch followers.")
