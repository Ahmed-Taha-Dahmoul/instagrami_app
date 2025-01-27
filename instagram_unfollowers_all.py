from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import time
from selenium.common.exceptions import TimeoutException

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
    time.sleep(3)

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
    # Locate and click the 'Following' button
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


    # Wait for the following page or list to load
    time.sleep(5)

    # -----------------------------------
    # Load and unfollow users
    # -----------------------------------
    scrollable_container = WebDriverWait(driver, 10).until(
        EC.presence_of_element_located((By.XPATH, "//div[@class='xyi19xy x1ccrb07 xtf3nb5 x1pc53ja x1lliihq x1iyjqo2 xs83m0k xz65tgg x1rife3k x1n2onr6']"))
    )

    user_element_xpath = "//div[@class='x9f619 xjbqb8w x78zum5 x168nmei x13lgxp2 x5pf9jr xo71vjh x1pi30zi x1swvt13 xwib8y2 x1y1aw1k x1uhb9sk x1plvlek xryxfnj x1c4vz4f x2lah0s xdt5ytf xqjyukv x1qjc9v5 x1oa3qoh x1nhvcw1']"
    
    unfollow_process = True
    while unfollow_process:
        last_user_count = 0
        scroll_count = 0
        start_time = time.time()
        timeout = 60  # Timeout after 1 minute

        while True:
            # Scroll down to the bottom.
            driver.execute_script("arguments[0].scrollTo(0, arguments[0].scrollHeight);", scrollable_container)

            # Wait to load page
            time.sleep(3)  # Added wait time here
            
            # Check if the number of user elements has increased
            current_user_count = len(driver.find_elements(By.XPATH, user_element_xpath))
            if current_user_count > last_user_count:
                last_user_count = current_user_count
                scroll_count += 1
                print(f"Scrolling... ({scroll_count}) - User count: {current_user_count}")
            elif current_user_count == last_user_count:
                print("No new content loaded, assuming list is fully loaded.")
                break
            else:
                print("Error loading list.")
                break

            if time.time() - start_time > timeout:
                print("Timeout reached, assuming list is fully loaded or an error has occurred.")
                break
        print("Full list loaded!")
        # -----------------------------------
        # Unfollow the users
        # -----------------------------------
        following_buttons = driver.find_elements(By.XPATH, "//button[.//div[contains(text(), 'Suivi(e)')]]")
        print(f"Found {len(following_buttons)} following buttons.")
        unfollow_count = 0
        for button in following_buttons:
            try:
                button.click()
                time.sleep(1)  # Wait for the dialog to appear

                # Locate the "Ne plus suivre" button in the dialog
                unfollow_confirm_button = WebDriverWait(driver, 5).until(
                    EC.presence_of_element_located((By.XPATH, "//button[text()='Ne plus suivre']"))
                )
                unfollow_confirm_button.click()
                unfollow_count += 1
                print(f"Unfollowed user ({unfollow_count}).")
                time.sleep(1)  # Wait for the dialog to disappear

            except TimeoutException:
                print("Timeout or error while unfollowing a user.")
                continue
            except Exception as e:
                print(f"An error occurred while unfollowing user: {e}")
                continue
        print(f"Finished unfollowing {unfollow_count} users.")
        # After unfollowing, check if new users have loaded by scrolling one more time
        driver.execute_script("arguments[0].scrollTo(0, arguments[0].scrollHeight);", scrollable_container)
        time.sleep(3)
        new_user_count = len(driver.find_elements(By.XPATH, user_element_xpath))
        if new_user_count > last_user_count :
            print("New users loaded, repeating the process...")
        else:
            unfollow_process = False
            print("No new users loaded, finished unfollowing.")

    # Keep the browser open indefinitely
    input("Press Enter to exit and close the browser...")

except Exception as e:
    print(f"An error occurred: {e}")

finally:
    # Close the browser
    driver.quit()
    print("Browser closed.")