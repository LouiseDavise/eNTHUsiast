# import os
# import base64
# import json
# from google.auth.transport.requests import Request
# from google.oauth2.credentials import Credentials
# from google_auth_oauthlib.flow import InstalledAppFlow
# from googleapiclient.discovery import build
# from google import genai

# from openai import OpenAI
# import json

# # Setup OpenRouter Client
# client = genai.Client(api_key="AIzaSyBg0-edCIYobhwGI7q9kQ5_DkIhOt7RKRE")

# # --- SMART PATH CONFIGURATION ---
# SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
# CREDENTIALS_PATH = os.path.join(SCRIPT_DIR, 'credentials.json')
# TOKEN_PATH = os.path.join(SCRIPT_DIR, 'token.json')

# # Define your two output files
# BULLETIN_JSON = os.path.join(SCRIPT_DIR, '../assets/bulletin.json')
# TASK_JSON = os.path.join(SCRIPT_DIR, '../assets/upcoming_task.json')

# SCOPES = ['https://www.googleapis.com/auth/gmail.modify']
# TARGET_EMAIL = 'louizkwok2@gmail.com'

# def authenticate_gmail():
#     creds = None
#     if os.path.exists(TOKEN_PATH):
#         creds = Credentials.from_authorized_user_file(TOKEN_PATH, SCOPES)
#     if not creds or not creds.valid:
#         if creds and creds.expired and creds.refresh_token:
#             creds.refresh(Request())
#         else:
#             flow = InstalledAppFlow.from_client_secrets_file(CREDENTIALS_PATH, SCOPES)
#             creds = flow.run_local_server(port=0)
#         with open(TOKEN_PATH, 'w') as token:
#             token.write(creds.to_json())
#     return build('gmail', 'v1', credentials=creds)

# def check_and_parse_emails():
#     service = authenticate_gmail()
#     query = f"from:{TARGET_EMAIL} is:unread"
#     results = service.users().messages().list(userId='me', q=query).execute()
#     messages = results.get('messages', [])

#     if not messages:
#         print(f"No new unread emails from {TARGET_EMAIL}.")
#         return

#     for msg in messages:
#         msg_data = service.users().messages().get(userId='me', id=msg['id']).execute()
#         payload = msg_data['payload']
        
#         # 1. Extract the Subject Line just in case the tag is there
#         headers = payload.get('headers', [])
#         subject = next((header['value'] for header in headers if header['name'].lower() == 'subject'), '')
        
#         # 2. Extract the Body Text
#         if 'parts' in payload:
#             part = payload['parts'][0]
#             data = part['body'].get('data', '')
#         else:
#             data = payload['body'].get('data', '')
            
#         if not data:
#             continue
            
#         clean_text = base64.urlsafe_b64decode(data).decode('utf-8')
#         print(f"Parsing new email: {subject}")

#         # ---------------------------------------------------------
#         # ROUTING LOGIC: Where should this email go?
#         # ---------------------------------------------------------
        
#         # Check if the tag is in the Subject OR the Body text
#         if "<NTHU Bulletin Board>" in subject or "<NTHU Bulletin Board>" in clean_text:
            
#             # --- PARSE AS BULLETIN ---
#             parts = clean_text.split("English Version")
#             english_content = parts[-1].strip() if len(parts) > 1 else clean_text
            
#             footer_marker = "This message was sent automatically"
#             if footer_marker in english_content:
#                 english_content = english_content.split(footer_marker)[0].strip()
                
#             english_content = english_content.replace('\xa0\xa0', '\n\n')
            
#             bulletin_data = {
#                 "id": msg['id'],
#                 "sender": TARGET_EMAIL,
#                 "title": "Campus Announcements",
#                 "snippet": msg_data.get('snippet', '').split("English Version")[-1][:50].strip() + "...",
#                 "fullText": english_content
#             }
            
#             print("-> Routed to: BULLETIN")
#             update_json_file(bulletin_data, BULLETIN_JSON)

#         else:
#             print("-> Routing to Google Gemini for Task Extraction...")
            
#             prompt = f"""
#             You are an assistant for a university app. Read the following email 
#             and extract the task details into a strict JSON format.
            
#             The JSON must have exactly these keys:
#             - title: A short, clear name for the task
#             - code: The course code (e.g., CS1010, EE2020). If none, return ""
#             - time: The time of the class or deadline (e.g., "14:00"). If none, return ""
#             - type: Must be one of: "Homework", "Midterm", "Final", "Quiz", "Project", or "Other"
#             - dueDate: The deadline format as YYYY-MM-DD. If none, return "TBD"
            
#             Do not include markdown formatting or backticks. Only output the raw JSON object.
            
#             Email Text:
#             {clean_text}
#             """
            
#             try:
#                 # Ask Gemini (Using the new SDK and upgraded 2.5-flash model)
#                 response = client.models.generate_content(
#                     model='gemini-2.5-flash',
#                     contents=prompt
#                 )
                
#                 response_content = response.text.strip()
                
#                 # Clean up markdown formatting if Gemini adds it
#                 if response_content.startswith("```json"):
#                     response_content = response_content[7:-3].strip()
#                 elif response_content.startswith("```"):
#                     response_content = response_content[3:-3].strip()
                    
#                 ai_data = json.loads(response_content)
                
#                 # Build your AppEvent data structure
#                 task_data = {
#                     "id": msg['id'],
#                     "title": ai_data.get("title", "Unknown Task"),
#                     "code": ai_data.get("code", ""),
#                     "time": ai_data.get("time", ""),
#                     "type": ai_data.get("type", "Other"),
#                     "dueDate": ai_data.get("dueDate", "TBD"),
#                     "status": "Incomplete", 
#                     "location": "Online" 
#                 }
                
#                 print(f"   Successfully extracted: {task_data['title']} ({task_data['type']})")
#                 update_json_file(task_data, TASK_JSON)
                
#             except Exception as e:
#                 import traceback
#                 print(f"AI Parsing Failed: {type(e).__name__} - {str(e)}")
#                 traceback.print_exc()

#         # Mark as read
#         service.users().messages().modify(
#             userId='me', id=msg['id'], body={'removeLabelIds': ['UNREAD']}
#         ).execute()

# # --- Notice this function now takes `target_file_path` as a second argument ---
# def update_json_file(new_data, target_file_path):
#     os.makedirs(os.path.dirname(target_file_path), exist_ok=True)

#     if os.path.exists(target_file_path):
#         with open(target_file_path, 'r', encoding='utf-8') as f:
#             try:
#                 existing_data = json.load(f)
#             except json.JSONDecodeError:
#                 existing_data = [] 
#     else:
#         existing_data = []

#     existing_data.append(new_data)

#     with open(target_file_path, 'w', encoding='utf-8') as f:
#         json.dump(existing_data, f, indent=4, ensure_ascii=False)
    
#     # Extract just the filename (like 'bulletin.json') for a cleaner print statement
#     filename = os.path.basename(target_file_path)
#     print(f"   Successfully added to {filename}!")

# if __name__ == '__main__':
#     check_and_parse_emails()

import os
import base64
import json
import traceback

import firebase_admin
from firebase_admin import credentials, firestore

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from google import genai


# =========================
# PATH CONFIG
# =========================

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

CREDENTIALS_PATH = os.path.join(SCRIPT_DIR, "credentials.json")
TOKEN_PATH = os.path.join(SCRIPT_DIR, "token.json")

SERVICE_ACCOUNT_PATH = os.path.join(SCRIPT_DIR, "../serviceAccountKey.json")

BULLETIN_JSON = os.path.join(SCRIPT_DIR, "../assets/bulletin.json")
TASK_JSON = os.path.join(SCRIPT_DIR, "../assets/upcoming_task.json")


# =========================
# API CONFIG
# =========================

SCOPES = ["https://www.googleapis.com/auth/gmail.modify"]
TARGET_EMAIL = "louizkwok2@gmail.com"

client = genai.Client(api_key="AIzaSyBg0-edCIYobhwGI7q9kQ5_DkIhOt7RKRE")


# =========================
# FIREBASE SETUP
# =========================

def init_firestore():
    if not os.path.exists(SERVICE_ACCOUNT_PATH):
        raise FileNotFoundError(
            f"serviceAccountKey.json not found at: {SERVICE_ACCOUNT_PATH}"
        )

    if not firebase_admin._apps:
        cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
        firebase_admin.initialize_app(cred)

    return firestore.client()


db = init_firestore()


def safe_doc_id(value):
    return (
        str(value)
        .strip()
        .replace(" ", "_")
        .replace("/", "_")
        .replace("\\", "_")
        .replace("#", "_")
        .replace("?", "_")
    )


def save_bulletin_to_firebase(bulletin_data):
    raw_id = bulletin_data.get("id") or f"{bulletin_data.get('sender', '')}_{bulletin_data.get('title', '')}"
    doc_id = safe_doc_id(raw_id)

    firebase_data = {
        "id": bulletin_data.get("id", ""),
        "sender": bulletin_data.get("sender", ""),
        "title": bulletin_data.get("title", ""),
        "snippet": bulletin_data.get("snippet", ""),
        "fullText": bulletin_data.get("fullText", ""),
        "source": "email",
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }

    db.collection("bulletins").document(doc_id).set(firebase_data, merge=True)

    print(f"   Successfully uploaded bulletin to Firebase: {doc_id}")


# =========================
# GMAIL SETUP
# =========================

def authenticate_gmail():
    creds = None

    if os.path.exists(TOKEN_PATH):
        creds = Credentials.from_authorized_user_file(TOKEN_PATH, SCOPES)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(
                CREDENTIALS_PATH,
                SCOPES,
            )
            creds = flow.run_local_server(port=0)

        with open(TOKEN_PATH, "w", encoding="utf-8") as token:
            token.write(creds.to_json())

    return build("gmail", "v1", credentials=creds)


def extract_email_body(payload):
    if "parts" in payload:
        for part in payload["parts"]:
            mime_type = part.get("mimeType", "")

            if mime_type == "text/plain":
                data = part.get("body", {}).get("data", "")
                if data:
                    return base64.urlsafe_b64decode(data).decode("utf-8")

            if "parts" in part:
                nested_text = extract_email_body(part)
                if nested_text:
                    return nested_text

        first_part = payload["parts"][0]
        data = first_part.get("body", {}).get("data", "")
    else:
        data = payload.get("body", {}).get("data", "")

    if not data:
        return ""

    return base64.urlsafe_b64decode(data).decode("utf-8")


# =========================
# LOCAL JSON BACKUP
# =========================

def update_json_file(new_data, target_file_path):
    os.makedirs(os.path.dirname(target_file_path), exist_ok=True)

    if os.path.exists(target_file_path):
        with open(target_file_path, "r", encoding="utf-8") as f:
            try:
                existing_data = json.load(f)
            except json.JSONDecodeError:
                existing_data = []
    else:
        existing_data = []

    existing_data.append(new_data)

    with open(target_file_path, "w", encoding="utf-8") as f:
        json.dump(existing_data, f, indent=4, ensure_ascii=False)

    filename = os.path.basename(target_file_path)
    print(f"   Successfully added to {filename}!")


# =========================
# MAIN EMAIL PARSER
# =========================

def check_and_parse_emails():
    service = authenticate_gmail()

    query = f"from:{TARGET_EMAIL} is:unread"
    results = service.users().messages().list(
        userId="me",
        q=query,
    ).execute()

    messages = results.get("messages", [])

    if not messages:
        print(f"No new unread emails from {TARGET_EMAIL}.")
        return

    for msg in messages:
        msg_data = service.users().messages().get(
            userId="me",
            id=msg["id"],
        ).execute()

        payload = msg_data["payload"]

        headers = payload.get("headers", [])
        subject = next(
            (
                header["value"]
                for header in headers
                if header["name"].lower() == "subject"
            ),
            "",
        )

        clean_text = extract_email_body(payload)

        if not clean_text:
            continue

        print(f"Parsing new email: {subject}")

        try:
            if "<NTHU Bulletin Board>" in subject or "<NTHU Bulletin Board>" in clean_text:
                parts = clean_text.split("English Version")
                english_content = parts[-1].strip() if len(parts) > 1 else clean_text

                footer_marker = "This message was sent automatically"
                if footer_marker in english_content:
                    english_content = english_content.split(footer_marker)[0].strip()

                english_content = english_content.replace("\xa0\xa0", "\n\n")

                bulletin_data = {
                    "id": msg["id"],
                    "sender": TARGET_EMAIL,
                    "title": "Campus Announcements",
                    "snippet": (
                        msg_data.get("snippet", "")
                        .split("English Version")[-1][:50]
                        .strip()
                        + "..."
                    ),
                    "fullText": english_content,
                }

                print("-> Routed to: BULLETIN")

                # 1. Keep local JSON backup.
                update_json_file(bulletin_data, BULLETIN_JSON)

                # 2. Directly upload to Firebase.
                save_bulletin_to_firebase(bulletin_data)

            else:
                print("-> Routing to Google Gemini for Task Extraction...")

                prompt = f"""
You are an assistant for a university app. Read the following email
and extract the task details into a strict JSON format.

The JSON must have exactly these keys:
- title: A short, clear name for the task
- code: The course code. If none, return ""
- time: The time of the class or deadline. If none, return ""
- type: Must be one of: "Homework", "Midterm", "Final", "Quiz", "Project", or "Other"
- dueDate: The deadline format as YYYY-MM-DD. If none, return "TBD"

Do not include markdown formatting or backticks. Only output the raw JSON object.

Email Text:
{clean_text}
"""

                response = client.models.generate_content(
                    model="gemini-2.5-flash",
                    contents=prompt,
                )

                response_content = response.text.strip()

                if response_content.startswith("```json"):
                    response_content = response_content[7:-3].strip()
                elif response_content.startswith("```"):
                    response_content = response_content[3:-3].strip()

                ai_data = json.loads(response_content)

                task_data = {
                    "id": msg["id"],
                    "title": ai_data.get("title", "Unknown Task"),
                    "code": ai_data.get("code", ""),
                    "time": ai_data.get("time", ""),
                    "type": ai_data.get("type", "Other"),
                    "dueDate": ai_data.get("dueDate", "TBD"),
                    "status": "Incomplete",
                    "location": "Online",
                }

                print(f"   Successfully extracted: {task_data['title']} ({task_data['type']})")
                update_json_file(task_data, TASK_JSON)

            service.users().messages().modify(
                userId="me",
                id=msg["id"],
                body={"removeLabelIds": ["UNREAD"]},
            ).execute()

            print("   Marked email as read.")

        except Exception as e:
            print(f"Failed to parse/upload email {msg['id']}: {type(e).__name__} - {e}")
            traceback.print_exc()


if __name__ == "__main__":
    check_and_parse_emails()