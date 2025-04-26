import json
import datetime
import sys
import os

# --- Configuration ---
# CHANGE THIS VARIABLE to the name of your Instagram inbox JSON file
# Make sure this file is in the SAME DIRECTORY as this Python script.
file_name = "instagram_inbox_response_7931218225.json"
# ---------------------

def format_timestamp(ts_us):
    """
    Formats a microsecond timestamp into a human-readable UTC string.
    Handles potential errors if the timestamp is invalid or out of range.
    Note: Instagram timestamps can sometimes be unusual. This assumes
          microseconds since the Unix epoch. Adjust if needed.
    """
    if not isinstance(ts_us, (int, float)):
        return "Invalid Timestamp Type"
    try:
        # Assuming the timestamp is in microseconds since the Unix epoch
        ts_sec = ts_us / 1_000_000
        dt_object = datetime.datetime.fromtimestamp(ts_sec, tz=datetime.timezone.utc)
        # You might want to convert to local time if preferred:
        # dt_object = datetime.datetime.fromtimestamp(ts_sec)
        # return dt_object.strftime('%Y-%m-%d %H:%M:%S Local')
        return dt_object.strftime('%Y-%m-%d %H:%M:%S UTC')
    except (ValueError, OverflowError, OSError) as e:
        # Handle cases where timestamp might be too large, small, or invalid
        # print(f"Warning: Could not format timestamp {ts_us}: {e}", file=sys.stderr)
        # Attempt direct conversion if it looks like milliseconds instead
        try:
             ts_sec = ts_us / 1_000
             dt_object = datetime.datetime.fromtimestamp(ts_sec, tz=datetime.timezone.utc)
             return dt_object.strftime('%Y-%m-%d %H:%M:%S UTC (interpreted as ms)')
        except Exception:
             return f"Unparseable Timestamp ({ts_us})"


def get_user_info(users_list, user_id):
    """Finds user information from the thread's user list."""
    for user in users_list:
        if user.get('pk') == user_id:
            return {
                'id': user.get('pk'),
                'username': user.get('username', 'Unknown User'),
                'full_name': user.get('full_name', '')
            }
    return None

def parse_conversation(json_file_path):
    """
    Parses the Instagram inbox JSON file and prints the conversation.
    """
    # Construct the full path relative to the script's location
    script_dir = os.path.dirname(os.path.abspath(__file__))
    full_path = os.path.join(script_dir, json_file_path)

    if not os.path.exists(full_path):
        print(f"Error: File not found at {full_path}", file=sys.stderr)
        print(f"(Ensure '{json_file_path}' is in the same directory as the script)", file=sys.stderr)
        return

    try:
        with open(full_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        print(f"Error: Could not decode JSON file {full_path}: {e}", file=sys.stderr)
        return
    except Exception as e:
        print(f"Error reading file {full_path}: {e}", file=sys.stderr)
        return

    if 'thread' not in data:
        print("Error: JSON does not contain a 'thread' object.", file=sys.stderr)
        return

    thread = data['thread']
    items = thread.get('items', [])
    users_in_thread = thread.get('users', [])
    viewer_id = thread.get('viewer_id')

    if not viewer_id:
        print("Error: Could not determine viewer ID from JSON.", file=sys.stderr)
        return
    if not users_in_thread:
         print("Error: No users found in the thread metadata.", file=sys.stderr)
         return
    if not items:
        print("No conversation items found in the thread.")
        return

    # --- Identify Users ---
    viewer_info = get_user_info(users_in_thread, viewer_id)
    # If viewer info isn't in users list (sometimes happens), try inviter
    if not viewer_info and 'inviter' in thread:
         inviter = thread['inviter']
         if inviter.get('pk') == viewer_id:
              viewer_info = {
                'id': viewer_id,
                'username': inviter.get('username', 'Viewer'),
                'full_name': inviter.get('full_name', 'Viewer')
              }

    if not viewer_info:
         print("Warning: Could not definitively identify viewer's username.", file=sys.stderr)
         viewer_name = f"Viewer ({viewer_id})"
    else:
         viewer_name = viewer_info.get('username', f"Viewer ({viewer_id})")


    other_user_info = None
    for user in users_in_thread:
        if user.get('pk') != viewer_id:
            other_user_info = get_user_info(users_in_thread, user.get('pk'))
            break

    if not other_user_info:
        print("Warning: Could not identify the other user in the thread.", file=sys.stderr)
        other_user_name = "Other User"
    else:
        other_user_name = other_user_info.get('username', 'Other User')

    print(f"--- Conversation with: {other_user_name} ---")
    print(f"--- (You are: {viewer_name}) ---\n")

    # --- Process Items (Reverse for chronological order) ---
    # The API often returns newest first, so we reverse
    items.reverse()

    for item in items:
        item_id = item.get('item_id')
        sender_id = item.get('user_id')
        timestamp_us = item.get('timestamp')
        item_type = item.get('item_type')
        is_sent_by_viewer = item.get('is_sent_by_viewer', sender_id == viewer_id) # Fallback
        hide_in_thread = item.get('hide_in_thread', 0)

        # Skip hidden action logs (like simple "Liked a message" notifications)
        if item_type == 'action_log' and hide_in_thread == 1:
            continue

        formatted_time = format_timestamp(timestamp_us)
        sender_name = viewer_name if is_sent_by_viewer else other_user_name

        print(f"[{formatted_time}] {sender_name}:")

        # --- Extract Content based on Type ---
        content = ""
        media_info = ""
        liked_by_viewer = None # Liked status of the *shared post*, not the message itself

        if item_type == 'text':
            content = item.get('text', '[No Text Content]')

        elif item_type == 'clip':
            clip_container = item.get('clip', {})
            clip_data = clip_container.get('clip', {}) # Nested clip object
            if clip_data: # Check if clip data exists
                original_user = clip_data.get('user', {}).get('username', 'Unknown User')
                original_caption_obj = clip_data.get('caption', {})
                original_caption = original_caption_obj.get('text', '[No Caption]') if original_caption_obj else '[No Caption]'
                media_info = f"Shared Clip by {original_user}: \"{original_caption[:100]}{'...' if len(original_caption)>100 else ''}\""
                liked_by_viewer = clip_data.get('has_liked')
            else:
                 media_info = "[Shared Clip - Data Missing]"


        elif item_type == 'media_share':
            media_data = item.get('media_share', {})
            original_user = media_data.get('user', {}).get('username', 'Unknown User')
            original_caption_obj = media_data.get('caption', {})
            original_caption = original_caption_obj.get('text', '[No Caption]') if original_caption_obj else '[No Caption]'
            media_type_num = media_data.get('media_type')
            media_type_str = "Media"
            if media_type_num == 1: media_type_str = "Photo"
            if media_type_num == 2: media_type_str = "Video/Clip"
            if media_type_num == 8: media_type_str = "Carousel"
            media_info = f"Shared {media_type_str} by {original_user}: \"{original_caption[:100]}{'...' if len(original_caption)>100 else ''}\""
            liked_by_viewer = media_data.get('has_liked')

        elif item_type == 'action_log':
             log_data = item.get('action_log', {})
             content = f"Action: {log_data.get('description', '[Unknown Action]')}"
             # Don't print separator for hidden logs we didn't skip earlier
             if hide_in_thread != 1: print(f"  {content}\n" + "-" * 20)
             continue # Skip normal printing for action logs unless needed

        elif item_type == 'like': # Older format for likes
             content = "Liked the previous message."

        else:
            content = f"[Unsupported Item Type: {item_type}]"

        # --- Print Content and Media Info ---
        if content:
            print(f"  {content}")
        if media_info:
            print(f"  {media_info}")
        if liked_by_viewer is True and is_sent_by_viewer: # Only show if you liked the post you shared
             print("    (You liked this original post)")

        # --- Extract Reactions *to this item* ---
        reactions = item.get('reactions', {})
        emojis = reactions.get('emojis', [])
        if emojis:
            react_str = "    Reactions: "
            reacts = []
            for emoji_react in emojis:
                reactor_id = emoji_react.get('sender_id')
                emoji = emoji_react.get('emoji')
                # Use IDs for robustness in case username isn't found
                reactor_name = viewer_name if reactor_id == viewer_id else other_user_name
                reacts.append(f"{reactor_name} ({emoji})")
            react_str += ", ".join(reacts)
            print(react_str)

        # --- Check for Replies ---
        replied_to = item.get('replied_to_message')
        if replied_to and replied_to.get('item_id'):
             reply_item_id = replied_to['item_id']
             # Could add logic here to find and display the original message if needed
             print(f"  (In reply to message ending in ...{reply_item_id[-6:]})")


        print("-" * 20) # Separator

# --- Main execution ---
# This will run when the script is executed directly
if __name__ == "__main__":
    # The script will now use the file_name variable defined at the top
    parse_conversation(file_name)