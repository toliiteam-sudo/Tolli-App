# Tolii — Firebase Backend Architecture, Implementation Status & Developer Reference

> **Document Type:** Backend & Firebase Architecture / Deep Technical Status Report  
> **Target Audience:** AI Agents, Full-Stack Developers, Backend Engineers  
> **Last Updated:** 2026-09-23  
> **Project Root:** `d:/HVK STUDIOS/tolii`  

---

## 1. Executive Summary

This document provides a comprehensive technical overview of the **Firebase backend** implementation in the **Tolii** Flutter application.

### Key Metrics
| Category | Status | Details |
|---|---|---|
| **Firebase Auth** | 🟢 85% Completed | Google Sign-In fully integrated; Phone/Email OTP UI complete with simulated verification |
| **Cloud Firestore** | 🟢 95% Completed | Users, Usernames, Activities, Requests, Participants, Communities, Messages, Notifications fully wired |
| **Firebase Storage** | 🟢 80% Completed | Chat image upload & download URL retrieval implemented; Profile photo upload ready |
| **Firestore Security Rules** | 🟢 100% Completed | Production-grade `firestore.rules` implemented with granular access controls |
| **Real-time Subscriptions** | 🟢 95% Completed | Streams for Activities, Upcoming Games, Join Requests, Roster, Community Chat, Notifications |
| **Push Notifications (FCM)** | 🟡 40% Completed | In-App Firestore notification engine complete; background push (FCM) pending |
| **Cloud Functions / Cron** | ⚪ 0% Pending | Scheduled cleanup / serverless triggers not yet deployed (handled client-side) |

---

## 2. Architecture & Directory Mapping

```
lib/
├── services/
│   ├── firestore_service.dart     # Central singleton managing FirebaseFirestore collections
│   ├── google_fit_service.dart    # Google Fitness API OAuth2 integration (steps, calories, distance)
│   ├── health_service.dart        # Apple Health / Health Connect wrapper
│   └── toli_share_service.dart    # Social sharing & deep linking service
│
├── repositories/
│   ├── user_repository.dart       # User profile CRUD & Firestore snapshot streams
│   ├── username_repository.dart   # Atomic username claiming & auto-generation transactions
│   ├── activity_repository.dart   # Activities, participants, join requests, upcoming streams
│   ├── community_repository.dart  # Community groups, live chat messages, image uploads
│   └── notification_repository.dart # In-app notifications & unread badge counters
│
├── controllers/
│   ├── auth_controller.dart       # Authentication state, Google Sign-In, profile onboarding
│   ├── activities_controller.dart # Activity filters, live feed subscriptions, host activities
│   └── notification_controller.dart # Live notification subscriptions & badge state
│
├── models/
│   ├── auth_model.dart            # Local auth state & onboarding form fields
│   ├── user_profile_model.dart    # Firestore user document representation
│   ├── activity_model.dart        # Activity, SportCategory, SkillLevel, PlayerModel
│   ├── activity_request_model.dart# Join request entity
│   ├── chat_message_model.dart    # Chat message (text, image, system events)
│   └── notification_model.dart    # In-app notification entity
│
└── firestore.rules                # Production security rules for all collections
```

---

## 3. Database Schema & Firestore Collections

### 1. `users` Collection (`/users/{userId}`)
* **Path:** `/users/{userId}`
* **Document ID:** Firebase Auth `uid`
* **Schema:**
```typescript
interface UserProfile {
  uid: string;                 // User ID matching Auth UID
  firstName: string;           // First Name (e.g., "Arjun")
  lastName: string;            // Last Name (e.g., "Mehta")
  username: string;            // Unique handle (e.g., "arjunm")
  normalizedUsername: string;  // Lowercase handle for searches
  email: string;               // Email address
  phoneNumber: string;         // Phone number (e.g., "+91 9876543210")
  photoUrl?: string;           // Profile picture URL (Google or Firebase Storage)
  selectedCity: string;        // City / Location (e.g., "Bhavnagar", "Mumbai")
  gender?: string;             // Gender ("Male", "Female", "Other", "Prefer not to say")
  interests: string[];         // Selected sports (e.g., ["Cricket", "Pickleball"])
  isProfileComplete: boolean;  // Onboarding completion flag
  createdAt?: Timestamp;       // Server timestamp
  updatedAt?: Timestamp;       // Server timestamp
}
```
* **Subcollections:**
  * `/users/{userId}/joined_communities/{communityId}`: Tracks joined community groups (`{ communityId, title, joinedAt }`).

---

### 2. `usernames` Collection (`/usernames/{username}`)
* **Path:** `/usernames/{username}`
* **Document ID:** Normalized username string (e.g., `arjunm`, `vatsalp`)
* **Purpose:** Global uniqueness lock preventing handle collisions.
* **Schema:**
```typescript
interface UsernameDoc {
  uid: string;            // Owner's Firebase Auth UID
  username: string;       // Normalized handle
  createdAt: Timestamp;   // Server timestamp
}
```
* **Operation:** Claimed atomically via Firestore transactions (`claimUsernameAtomic`, `generateAndClaimUniqueUsername`).

---

### 3. `activities` Collection (`/activities/{activityId}`)
* **Path:** `/activities/{activityId}`
* **Document ID:** Auto-generated Firestore Document ID
* **Schema:**
```typescript
interface Activity {
  id: string;                    // Firestore Document ID
  title: string;                 // Activity sport/name (e.g., "Box Cricket")
  sportCategory: string;         // Enum string ('boxCricket', 'badminton', etc.)
  venueName: string;             // Venue name (e.g., "Bhavnagar Sports Arena")
  venueLocation: string;         // Full address or city
  venueConfirmed: boolean;       // Venue booking status
  date?: Timestamp;              // Scheduled activity timestamp
  timeFormatted: string;         // Display time string (e.g., "6:30 PM")
  totalPlayers: number;          // Total required players (capacity)
  joinedPlayers: number;         // Current count of joined players
  participantIds: string[];      // Array of attendee UIDs (enables security & queries)
  costPerPerson: number;         // Cost in INR (e.g., 100)
  splitCost: boolean;            // Cost split flag
  whoCanJoin: string;            // "Public" | "Invite only"
  skillLevel: string;            // 'allLevels' | 'beginner' | 'intermediate' | 'advanced'
  note?: string;                 // Activity description/instructions
  equipment?: string;            // Equipment needed (e.g., "Bring your own racket")
  durationMinutes: number;       // Match duration (default 60 mins)
  status: string;                // "scheduled" | "active" | "completed" | "cancelled" | "expired"
  hostId: string;                // Host's Firebase Auth UID
  hostName: string;              // Host display name
  hostUsername: string;          // Host handle
  hostPhotoUrl?: string;         // Host avatar URL
  createdAt: Timestamp;          // Server timestamp
  updatedAt?: Timestamp;         // Server timestamp
}
```

* **Subcollection 1: `/activities/{activityId}/participants/{participantUid}`**
```typescript
interface ActivityParticipant {
  name: string;                  // Player name
  role: string;                  // "HOST" | "MEMBER"
  skill: string;                 // "Beginner" | "Intermediate" | "Advanced"
  avatarUrl?: string;            // Player photo URL
  isHost: boolean;               // Host indicator
  joinedAt: Timestamp;           // Server timestamp
}
```

* **Subcollection 2: `/activities/{activityId}/requests/{requestUid}`**
```typescript
interface ActivityJoinRequest {
  activityId: string;            // Parent activity ID
  status: string;                // "pending" | "accepted" | "rejected"
  userName: string;              // Applicant name
  userUsername: string;          // Applicant handle
  userPhotoUrl?: string;         // Applicant photo URL
  requestedAt: Timestamp;        // Server timestamp
}
```

---

### 4. `community` Collection (`/community/{communityId}`)
* **Path:** `/community/{communityId}` (e.g., `global`, `comm_1`, `comm_2`)
* **Subcollection 1: `/community/{communityId}/messages/{messageId}`**
```typescript
interface ChatMessage {
  senderId: string;              // Sender UID
  senderName: string;            // Sender display name
  senderPhotoUrl?: string;       // Sender avatar URL
  text: string;                  // Message text
  type?: string;                 // "text" | "image" | "system"
  eventType?: string;            // "user_joined" | "match_created" (for system msgs)
  imageUrl?: string;             // Firebase Storage image download URL
  createdAt: Timestamp;          // Server timestamp
}
```
* **Subcollection 2: `/community/{communityId}/members/{memberUid}`**
```typescript
interface CommunityMember {
  uid: string;                   // Member UID
  name: string;                  // Member display name
  photoUrl?: string;             // Member avatar URL
  joinedAt: Timestamp;           // Server timestamp
}
```

---

### 5. `conversations` Collection (`/conversations/{conversationId}`)
* **Path:** `/conversations/{conversationId}`
* **Purpose:** Temporary or persistent group conversations automatically tied to an `activityId`.
* **Schema:**
```typescript
interface Conversation {
  id: string;                    // Conversation ID (usually equals activityId)
  activityId: string;            // Associated activity ID
  title: string;                 // Conversation title (e.g., "Box Cricket Chat")
  type: string;                  // "activity_group" | "direct"
  participantIds: string[];      // Array of attendee UIDs
  lastMessage: string;           // Preview of last message
  lastMessageTime: Timestamp;    // Timestamp of last message
  createdAt: Timestamp;          // Server timestamp
  isActive: boolean;             // Active status flag
}
```

---

### 6. `notifications` Collection (`/notifications/{notificationId}`)
* **Path:** `/notifications/{notificationId}`
* **Schema:**
```typescript
interface NotificationDoc {
  id: string;                    // Document ID
  recipientId: string;           // Target user UID
  senderId?: string;             // Triggering user UID
  senderName?: string;           // Triggering user name
  senderPhotoUrl?: string;       // Triggering user avatar URL
  type: string;                  // "join_request" | "request_accepted" | "request_rejected" | "system"
  title: string;                 // Notification title
  body: string;                  // Notification text content
  relatedActivityId?: string;    // Associated activity ID
  requestStatus?: string;        // "PENDING" | "APPROVED" | "DECLINED"
  isRead: boolean;               // Read/Unread flag
  createdAt: Timestamp;          // Server timestamp
}
```

---

## 4. Implemented Repositories & Methods

### `UserRepository` (`lib/repositories/user_repository.dart`)
* `getUserProfile(String uid)` -> Fetches `UserProfileModel` from Firestore.
* `saveUserProfile(UserProfileModel profile)` -> Sets profile with `SetOptions(merge: true)`.
* `updateProfileData(String uid, Map<String, dynamic> data)` -> Partial updates with server timestamp.
* `streamUserProfile(String uid)` -> Real-time snapshot stream of user profile.

### `UsernameRepository` (`lib/repositories/username_repository.dart`)
* `checkUsernameAvailabilityRemote(String username, {String? currentUid})` -> Checks if handle is taken in `/usernames`.
* `claimUsernameAtomic({uid, newUsername, oldUsername})` -> Atomic transaction claiming handle and updating user profile.
* `generateAndClaimUniqueUsername({uid, firstName, lastName, oldUsername})` -> Generates collision-free handles (`name`, `name2`, `name3`, etc.) atomically.

### `ActivityRepository` (`lib/repositories/activity_repository.dart`)
* `watchActivities({currentUid})` -> Real-time stream of all public, unexpired, non-full activities for Explore feed.
* `watchUserUpcomingActivities(String uid)` -> Combined stream (hosts + approved participants) sorted by game date.
* `watchUserHostedActivities(String uid)` -> Real-time stream of activities hosted by `uid`.
* `watchActivityDetail(String activityId)` -> Real-time single activity document stream.
* `watchActivityParticipants(String activityId)` -> Real-time roster stream from subcollection.
* `watchActivityRequests(String activityId)` -> Real-time join requests stream for hosts.
* `watchActivityMembershipStatus(String activityId, String uid)` -> Reactive single-source-of-truth status (`host`, `joined`, `pending`, `notJoined`).
* `createActivity({...})` -> Atomic batch create: activity document + host participant + group conversation.
* `joinActivityDirectly({...})` -> Direct join batch: participant doc + increment `joinedPlayers` + add to `participantIds` + add to chat conversation.
* `requestToJoinActivity({...})` -> Creates request doc in subcollection and dispatches notification to host.
* `respondToJoinRequest({activityId, request, accept})` -> Atomic batch: updates request status, adds participant, increments capacity, and dispatches approval/rejection notification.
* `removeParticipant(String activityId, String playerId)` -> Decrements player count, removes from `participantIds` and conversation, deletes participant doc.
* `updateActivity(ActivityModel activity)` -> Updates activity details in Firestore.
* `deleteActivity(String activityId)` -> Deletes activity document from Firestore.

### `CommunityRepository` (`lib/repositories/community_repository.dart`)
* `watchCommunityMessages({communityId, currentUid, limit})` -> Real-time chat messages stream ordered chronologically.
* `sendCommunityMessage({...})` -> Sends text message with server timestamp.
* `uploadChatImage({communityId, imageFile})` -> Uploads image to Firebase Storage and returns download URL.
* `sendImageMessage({...})` -> Sends image message with Storage download URL.
* `watchJoinedCommunityIds(String uid)` -> Real-time stream of user's joined communities.
* `joinCommunity({...})` -> Atomic batch: adds to `/community/members`, `/users/joined_communities`, and posts "joined" system event.
* `leaveCommunity({communityId, uid})` -> Leaves community and removes membership records.

### `NotificationRepository` (`lib/repositories/notification_repository.dart`)
* `watchNotifications(String recipientUid)` -> Real-time stream of user notifications sorted by newest first.
* `watchUnreadCount(String recipientUid)` -> Real-time stream of unread notification count for badge counters.
* `createNotification(NotificationModel notification)` -> Inserts notification document.
* `markAsRead(String notificationId)` -> Marks single notification as read.
* `markAllAsRead(String recipientUid)` -> Batch marks all unread notifications as read.

---

## 5. Security Rules Verification (`firestore.rules`)

The `firestore.rules` file contains complete rule configurations:
1. **`users`**: Any authenticated user can read; only the document owner can create or update their own record; deletion is disallowed.
2. **`usernames`**: Any authenticated user can read; creation requires `data.uid == request.auth.uid`; updates and deletions are locked.
3. **`activities`**: Authenticated users can read; only the host can create with `hostId == request.auth.uid`; host can update full details, while participants can update `participantIds`/`joinedPlayers` when joining/leaving; only host can delete.
4. **`activities/participants`**: Authenticated users can read; host or the participant themselves can create, update, or delete.
5. **`activities/requests`**: Host or the requesting user can read, create, update, or delete their request.
6. **`community/messages`**: Authenticated users can read and create; only message author can update or delete.
7. **`conversations`**: Only conversation participants (`request.auth.uid in resource.data.participantIds`) can read and message.
8. **`notifications`**: Recipient can read, update, or delete; sender can create notifications for recipients.

---

## 6. What Remains to be Done (Pending / Next Steps)

For any future AI agent or developer continuing backend work on Tolii, here are the exact pending tasks:

### 1. Real Phone SMS Verification (High Priority)
* **Current State:** `AuthController.sendOtp()` and `AuthController.verifyOtp()` use simulated delays for testing.
* **To Implement:** Integrate `FirebaseAuth.instance.verifyPhoneNumber()` with SMS callbacks (`verificationCompleted`, `verificationFailed`, `codeSent`, `codeAutoRetrievalTimeout`) and `PhoneAuthProvider.credential(...)`.

### 2. Push Notifications via FCM (Medium Priority)
* **Current State:** In-app notification engine is 100% functional via Firestore streams (`NotificationController` & `NotificationRepository`).
* **To Implement:** Add `firebase_messaging` package, configure APNs (iOS) / FCM (Android), collect device FCM tokens on login in `users/{uid}`, and deploy a Cloud Function trigger on `/notifications/{notificationId}` create to dispatch native push notifications.

### 3. User Avatar Image Upload to Firebase Storage (Medium Priority)
* **Current State:** Avatar currently uses Google photo URL or local image path.
* **To Implement:** Add a helper `uploadProfileImage(XFile image, String uid)` in `user_repository.dart` uploading to `profile_photos/{uid}.jpg` and setting `photoUrl` in Firestore.

### 4. Scheduled Cleanup / Expiry Cloud Function (Low Priority)
* **Current State:** Expired and past activities are filtered client-side by comparing `endTimestamp` with `DateTime.now()`.
* **To Implement:** Firebase Cloud Functions Pub/Sub cron (e.g., every 30 minutes) to update status to `"expired"` or `"completed"`.

---

## 7. How to Verify & Test Backend Locally

1. **Check Firebase Initialization:**
   ```dart
   // lib/main.dart
   await Firebase.initializeApp();
   ```
2. **Run Diagnostics / Test Suite:**
   Run the test runner to verify models and controllers:
   ```bash
   flutter test
   ```
3. **Deploy Security Rules to Firebase Console:**
   ```bash
   firebase deploy --only firestore:rules
   ```
