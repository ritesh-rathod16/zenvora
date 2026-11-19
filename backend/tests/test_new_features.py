import os
import sys
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from models.app.main import app

def test_new_features_suite():
    with TestClient(app) as client:
        print("=== 1. AUTHENTICATE TEST USERS ===")
        # User 1
        res1 = client.post("/auth/login", json={"email": "luna@zenvora.com", "password": "Password123!"})
        assert res1.status_code == 200, f"Login failed: {res1.text}"
        token1 = res1.json()["access_token"]
        u1_data = res1.json()["user"]
        user1_name = u1_data.get("username") or u1_data.get("anonymous_username")
        headers1 = {"Authorization": f"Bearer {token1}"}

        # User 2
        res2 = client.post("/auth/login", json={"email": "cipher@zenvora.com", "password": "Password123!"})
        assert res2.status_code == 200, f"Login failed: {res2.text}"
        token2 = res2.json()["access_token"]
        u2_data = res2.json()["user"]
        user2_name = u2_data.get("username") or u2_data.get("anonymous_username")
        headers2 = {"Authorization": f"Bearer {token2}"}

        print(f"Logged in User1: @{user1_name}, User2: @{user2_name}")

        print("\n=== 2. TEST MODULE 1: ADVANCED STORY SETTINGS ===")
        # Get Story Settings
        res_st_get = client.get("/stories/settings", headers=headers1)
        assert res_st_get.status_code == 200
        print("GET /stories/settings:", res_st_get.json())

        # Update Story Settings
        res_st_put = client.put("/stories/settings", json={
            "allow_story_replies": "following",
            "allow_story_reactions": True,
            "allow_story_likes": True
        }, headers=headers1)
        assert res_st_put.status_code == 200
        assert res_st_put.json()["story_settings"]["allow_story_replies"] == "following"
        print("PUT /stories/settings verified")

        # Manage Close Friends
        res_cf_add = client.post(f"/stories/close-friends/{user2_name}", headers=headers1)
        assert res_cf_add.status_code == 200
        res_cf_list = client.get("/stories/close-friends", headers=headers1)
        assert res_cf_list.status_code == 200
        assert any(u["username"] == user2_name for u in res_cf_list.json())
        print("Close Friends management verified:", res_cf_list.json())

        # Manage Hide Story From
        res_hf_add = client.post(f"/stories/hide-from/{user2_name}", headers=headers1)
        assert res_hf_add.status_code == 200
        res_hf_del = client.delete(f"/stories/hide-from/{user2_name}", headers=headers1)
        assert res_hf_del.status_code == 200
        print("Hide Story From management verified")

        print("\n=== 3. TEST MODULE 2: COMPLETE REPOST SYSTEM ===")
        # User 1 creates post
        res_p_create = client.post("/posts/create", json={
            "content": "Testing Zenvora Complete Repost System!"
        }, headers=headers1)
        assert res_p_create.status_code == 200
        post_id = res_p_create.json()["id"]
        print(f"Post created by @{user1_name}, id: {post_id}")

        # User 2 Reposts Post
        res_repost = client.post(f"/posts/{post_id}/repost", headers=headers2)
        assert res_repost.status_code == 200
        assert res_repost.json()["reposted"] is True
        print("Post reposted by User2 verified")

        # Verify User 2 Reposts Profile Tab
        res_user_reposts = client.get(f"/posts/user/{user2_name}/reposts", headers=headers2)
        assert res_user_reposts.status_code == 200
        repost_list = res_user_reposts.json()
        assert len(repost_list) >= 1
        assert repost_list[0]["original_post_id"] == post_id
        print("User2 Reposts profile tab verified:", len(repost_list), "repost(s)")

        # Undo Repost
        res_undo_repost = client.post(f"/posts/{post_id}/repost", headers=headers2)
        assert res_undo_repost.status_code == 200
        assert res_undo_repost.json()["reposted"] is False
        print("Undo repost verified")

        print("\n=== 4. TEST MODULE 3: ZENVORA DISCOVER & SWIPE ===")
        # User 1 Discovery Feed
        res_disc = client.get("/discovery/swipe-discovery", headers=headers1)
        assert res_disc.status_code == 200
        disc_users = res_disc.json()
        print(f"Discovery feed returned {len(disc_users)} candidates")

        # Swipe Left (Skip)
        res_swipe_left = client.post("/swipe", json={
            "target_user_id": user2_name,
            "action": "pass"
        }, headers=headers1)
        assert res_swipe_left.status_code == 200
        assert res_swipe_left.json()["status"] == "skipped"
        print("Swipe Left (Pass) verified")

        # Undo Swipe
        res_undo_swipe = client.post("/swipe/undo", headers=headers1)
        assert res_undo_swipe.status_code == 200
        print("Undo Swipe verified:", res_undo_swipe.json())

        # Clean up existing follows/requests between User 1 and User 2 for clean test run
        client.post(f"/social/unfollow/{user2_name}", headers=headers1)

        # Set User 2 to Private for Follow Request test
        client.put("/users/me/settings", json={"is_private": True}, headers=headers2)

        # Swipe Right on Private User (Follow Request)
        res_swipe_right = client.post("/swipe", json={
            "target_user_id": user2_name,
            "action": "like"
        }, headers=headers1)
        assert res_swipe_right.status_code == 200
        assert res_swipe_right.json()["status"] == "pending"
        print("Swipe Right on private user (Follow Request Sent) verified:", res_swipe_right.json())

        # User 2 checks Pending Follow Requests
        res_pending = client.get("/social/requests/pending", headers=headers2)
        assert res_pending.status_code == 200
        pending_list = res_pending.json()
        assert len(pending_list) >= 1
        req_id = pending_list[0]["request_id"]
        print("Pending follow request found:", req_id)

        # User 2 Accepts Follow Request
        res_accept = client.post(f"/social/requests/{req_id}/accept", headers=headers2)
        assert res_accept.status_code == 200
        print("Follow request accepted verified:", res_accept.json())

        print("\n=== 5. TEST ADVANCED CHAT SETTINGS & DISAPPEARING MESSAGES ===")
        # Get/Update Chat Settings
        res_cs_get = client.get("/chats/settings", headers=headers1)
        assert res_cs_get.status_code == 200
        res_cs_put = client.put("/chats/settings", json={"read_receipts_enabled": True}, headers=headers1)
        assert res_cs_put.status_code == 200
        print("Chat settings endpoint verified")

        # Start Chat between User 1 and User 2
        res_chat_start = client.post(f"/chats/start/{user2_name}", headers=headers1)
        assert res_chat_start.status_code == 200
        chat_id = res_chat_start.json()["id"] if "id" in res_chat_start.json() else res_chat_start.json()["_id"]
        print(f"Chat session started, id: {chat_id}")

        # Set Disappearing Messages Mode to 'delete_24h'
        res_mode_24h = client.patch(f"/chats/{chat_id}/auto-delete", json={"auto_delete_mode": "delete_24h"}, headers=headers1)
        assert res_mode_24h.status_code == 200
        assert res_mode_24h.json()["auto_delete_mode"] == "delete_24h"
        print("Disappearing message mode changed to 24h verified")

        # Send Message
        res_msg_send = client.post(f"/chats/{chat_id}/send", json={
            "content": "Hello! Testing 24h disappearing message.",
            "message_type": "text"
        }, headers=headers1)
        assert res_msg_send.status_code == 200
        msg_id = res_msg_send.json()["id"]
        assert res_msg_send.json()["deletion_mode"] == "delete_24h"
        assert res_msg_send.json()["expires_at"] is not None
        print("Message sent with 24h expiration verified:", msg_id)

        # User 2 Views Message
        res_msg_view = client.post(f"/chats/{chat_id}/messages/{msg_id}/view", headers=headers2)
        assert res_msg_view.status_code == 200
        assert res_msg_view.json()["viewed_at"] is not None
        print("Message marked as viewed by recipient verified")

        # Set Mode to 'immediately_delete'
        res_mode_imm = client.patch(f"/chats/{chat_id}/auto-delete", json={"auto_delete_mode": "immediately_delete"}, headers=headers1)
        assert res_mode_imm.status_code == 200
        print("Disappearing message mode changed to immediately_delete verified")

        # Send Immediately Delete Message
        res_imm_msg = client.post(f"/chats/{chat_id}/send", json={
            "content": "Top secret immediately disappearing message!",
            "message_type": "text"
        }, headers=headers1)
        assert res_imm_msg.status_code == 200
        imm_msg_id = res_imm_msg.json()["id"]

        # Recipient views immediate message
        client.post(f"/chats/{chat_id}/messages/{imm_msg_id}/view", headers=headers2)

        # React to message
        res_react = client.post(f"/chats/{chat_id}/messages/{msg_id}/react", json={"emoji": "❤️"}, headers=headers2)
        assert res_react.status_code == 200
        print("Message emoji reaction verified")

        print("\nALL NEW FEATURES TEST SUITE PASSED PERFECTLY!")

if __name__ == "__main__":
    test_new_features_suite()
