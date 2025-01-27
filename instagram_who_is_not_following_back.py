from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import time
from selenium.common.exceptions import TimeoutException
import json

# Initialize Chrome options
options = webdriver.ChromeOptions()
options.add_argument('--start-maximized')
options.add_argument('--user-data-dir=C:\\Users\\friv1\\AppData\\Local\\Google\\Chrome\\User Data')  # Default profile directory
options.add_argument('--profile-directory=Default')  # Explicitly using the 'Default' profile
options.add_argument('--disable-extensions')
options.add_argument('--no-sandbox')
options.add_argument('--disable-dev-shm-usage')

# Launch the browser
service = Service(ChromeDriverManager().install())
driver = webdriver.Chrome(service=service, options=options)
print("Browser launched!")

try:
    # Navigate to Instagram
    driver.get("https://www.instagram.com")
    print("Navigating to Instagram...")

    # Wait for Instagram to load
    time.sleep(5)

    # ---------------------------------
    # Locate and click the profile link
    # ---------------------------------
    try:
        # Wait for the span inside the target link
        profile_span_element = WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.XPATH, "//a[contains(@class, '_a6hd') and @role='link' and @tabindex='0']//span[text()='Profil']"))
        )
        # Get the parent <a> element
        profile_link_element = profile_span_element.find_element(By.XPATH, "./ancestor::a")
    except TimeoutException:
        print("Timeout: Profile link element not found")
        exit()

    # Get the href attribute of the link (profile link)
    profile_href = profile_link_element.get_attribute('href')  # Get the 'href' attribute

    # Check the profile link
    print(f"Found profile link: {profile_href}")

    # Navigate to the profile URL
    driver.get(profile_href)
    print(f"Navigating to the profile: {profile_href}")

    # Wait for the profile page to load
    time.sleep(5)

    # -----------------------------------
    # Extract Following List
    # -----------------------------------
    try:
        following_button = WebDriverWait(driver, 10).until(
            EC.presence_of_element_located(
                (By.XPATH, "//a[contains(@href, '/following/') and contains(@class, '_a6hd')]")
            )
        )
        # Click the 'Following' button
        following_button.click()
        print("Clicked the 'Following' button!")
    except TimeoutException:
        print("Timeout: Following button not found")
        exit()
    time.sleep(5)
    following_usernames = []
    scrollable_container = WebDriverWait(driver, 10).until(
        EC.presence_of_element_located((By.XPATH, "//div[@class='xyi19xy x1ccrb07 xtf3nb5 x1pc53ja x1lliihq x1iyjqo2 xs83m0k xz65tgg x1rife3k x1n2onr6']"))
    )
    user_element_xpath = "//div[@class='x9f619 xjbqb8w x78zum5 x168nmei x13lgxp2 x5pf9jr xo71vjh x1pi30zi x1swvt13 xwib8y2 x1y1aw1k x1uhb9sk x1plvlek xryxfnj x1c4vz4f x2lah0s xdt5ytf xqjyukv x1qjc9v5 x1oa3qoh x1nhvcw1']"
    loading_indicator_xpath = "//div[@data-visualcompletion='loading-state']"
    last_user_count = 0
    start_time = time.time()
    timeout = 600000  # Timeout after 1 minute
    while True:
        # Scroll down to the bottom.
        driver.execute_script("arguments[0].scrollTo(0, arguments[0].scrollHeight);", scrollable_container)

        # Wait to load page
        time.sleep(3)  # Added wait time here
        
        # Check if the number of user elements has increased
        current_user_count = len(driver.find_elements(By.XPATH, user_element_xpath))
        if current_user_count > last_user_count:
            last_user_count = current_user_count
            print(f"Scrolling... - User count: {current_user_count}")
        elif current_user_count == last_user_count:
            print("No new content loaded, assuming list is fully loaded. Trying one more time...")
            driver.execute_script("arguments[0].scrollTo(0, arguments[0].scrollHeight);", scrollable_container)
            time.sleep(2)
            new_user_count = len(driver.find_elements(By.XPATH, user_element_xpath))
            if new_user_count > current_user_count:
                print("New users found, continuing scrolling...")
                last_user_count = new_user_count
                continue
            else:
                 print("No new users found after one more scroll, assuming list is fully loaded.")
                 break
        else:
            print("Error loading list.")
            break

        if time.time() - start_time > timeout:
            print("Timeout reached, assuming list is fully loaded or an error has occurred.")
            break
    print("Following list loaded!")
    username_elements = driver.find_elements(By.XPATH, "//div[@class='x9f619 xjbqb8w x78zum5 x168nmei x13lgxp2 x5pf9jr xo71vjh x1pi30zi x1swvt13 xwib8y2 x1y1aw1k x1uhb9sk x1plvlek xryxfnj x1c4vz4f x2lah0s xdt5ytf xqjyukv x1qjc9v5 x1oa3qoh x1nhvcw1']//span[@class='_ap3a _aaco _aacw _aacx _aad7 _aade']")
    for username_element in username_elements:
        following_usernames.append(username_element.text)
    print(f"Extracted {len(following_usernames)} following usernames.")

    # -----------------------------------
    # Extract Followers List
    # -----------------------------------
    driver.get(profile_href)
    time.sleep(5)
    try:
        followers_button = WebDriverWait(driver, 10).until(
            EC.presence_of_element_located(
                (By.XPATH, "//a[contains(@href, '/followers/') and contains(@class, '_a6hd')]")
            )
        )
        # Click the 'Followers' button
        followers_button.click()
        print("Clicked the 'Followers' button!")
    except TimeoutException:
        print("Timeout: Followers button not found")
        exit()
    time.sleep(5)
    followers_usernames = []
    scrollable_container = WebDriverWait(driver, 10).until(
        EC.presence_of_element_located((By.XPATH, "//div[@class='xyi19xy x1ccrb07 xtf3nb5 x1pc53ja x1lliihq x1iyjqo2 xs83m0k xz65tgg x1rife3k x1n2onr6']"))
    )
    last_user_count = 0
    start_time = time.time()
    timeout = 600000  # Timeout after 1 minute
    while True:
        # Scroll down to the bottom.
        driver.execute_script("arguments[0].scrollTo(0, arguments[0].scrollHeight);", scrollable_container)

        # Wait to load page
        time.sleep(3)  # Added wait time here
        
        # Check if the number of user elements has increased
        current_user_count = len(driver.find_elements(By.XPATH, user_element_xpath))
        if current_user_count > last_user_count:
            last_user_count = current_user_count
            print(f"Scrolling... - User count: {current_user_count}")
        elif current_user_count == last_user_count:
            print("No new content loaded, assuming list is fully loaded. Trying one more time...")
            driver.execute_script("arguments[0].scrollTo(0, arguments[0].scrollHeight);", scrollable_container)
            time.sleep(2)
            new_user_count = len(driver.find_elements(By.XPATH, user_element_xpath))
            if new_user_count > current_user_count:
                print("New users found, continuing scrolling...")
                last_user_count = new_user_count
                continue
            else:
                print("No new users found after one more scroll, assuming list is fully loaded.")
                break
        else:
            print("Error loading list.")
            break

        if time.time() - start_time > timeout:
            print("Timeout reached, assuming list is fully loaded or an error has occurred.")
            break
    print("Followers list loaded!")
    username_elements = driver.find_elements(By.XPATH, "//div[@class='x9f619 xjbqb8w x78zum5 x168nmei x13lgxp2 x5pf9jr xo71vjh x1pi30zi x1swvt13 xwib8y2 x1y1aw1k x1uhb9sk x1plvlek xryxfnj x1c4vz4f x2lah0s xdt5ytf xqjyukv x1qjc9v5 x1oa3qoh x1nhvcw1']//span[@class='_ap3a _aaco _aacw _aacx _aad7 _aade']")
    for username_element in username_elements:
        followers_usernames.append(username_element.text)
    print(f"Extracted {len(followers_usernames)} followers usernames.")
    
    # -----------------------------------
    # Identify Non-Followers
    # -----------------------------------
    not_following_back = [user for user in following_usernames if user not in followers_usernames]
    print("Not following you back:")
    for user in not_following_back:
        print(user)

    # -----------------------------------
    # Store Data in JSON
    # -----------------------------------
    data = {
        "following": following_usernames,
        "followers": followers_usernames,
        "not_following_back": not_following_back
    }

    with open("instagram_data.json", "w") as json_file:
        json.dump(data, json_file, indent=4)
    print("Data saved to instagram_data.json")

    # Keep the browser open indefinitely
    input("Press Enter to exit and close the browser...")

except Exception as e:
    print(f"An error occurred: {e}")

finally:
    # Close the browser
    driver.quit()
    print("Browser closed.")