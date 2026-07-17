# The Ipalibos – Product Logic & Functional Specification

## Vision
The Ipalibos is a secure, cross-platform family management platform for iOS, Android, tablets and the web. It combines family scheduling, messaging, chores, parental controls, location safety and rewards into one application.

---

# 1. Platforms

- iOS
- Android
- Web
- Tablet

Cloud-synchronised in real time.

---

# 2. User Roles

## Parent
Permissions:
- Create/manage family
- Invite adults
- Create child accounts
- Promote/demote parents
- Create/edit appointments
- Create chores & routines
- View reports
- Manage GPS
- Approve unlock requests
- Configure parental controls
- View all chats
- Manage rewards

## Child
Permissions:
- View family calendar
- Receive tasks
- Complete tasks
- Chat
- Request unlock
- Emergency SOS

Restrictions:
- Cannot disable GPS
- Cannot become parent
- Cannot remove chores
- Cannot alter parental settings

Only a Parent can designate an account as a Child.

---

# 3. Core Modules

1. Authentication
2. Family Dashboard
3. Shared Calendar
4. Chore & Routine Engine
5. Family Chat
6. GPS Safety
7. Parent Controls
8. Device Unlock Workflow
9. Rewards
10. Homework & Reading
11. Reports
12. Notifications
13. Emergency SOS
14. Settings

---

# 4. Authentication

- Email
- Phone
- Apple Sign In
- Google Sign In
- Face ID
- Fingerprint
- PIN
- Two-factor authentication

---

# 5. Shared Calendar

Each appointment contains:
- Title
- Person
- Date
- Start/End Time
- Location
- Notes
- Reminder
- Repeat rule
- Attachments

Views:
- Day
- Week
- Month
- Family Timeline

Parents may edit everyone's events.
Children edit only their own unless restricted.

---

# 6. Chore & Routine Engine

Task fields:
- Title
- Description
- Rich text
- Images
- Video
- Voice instructions
- Category
- Priority
- Due time
- Grace period
- Repeat
- Assigned members

Status:
- Upcoming
- Due
- Completed
- Late
- Missed
- Approved

Completion:
- Button
- Optional photo
- Optional note
- Timestamp

---

# 7. Automatic Reminder Logic

Trigger reminders:
- At due time
- After configurable intervals
- Until completed

Escalation:
1. Push reminder
2. Audible reminder
3. Persistent notification
4. Parent notified
5. Device restriction workflow (platform capabilities permitting)

---

# 8. Device Unlock Workflow

Requested behaviour:
- Child ignores task
- Grace period expires
- Restricted mode activates
- Child requests unlock
- Parent receives request
- Parent generates one-time code
- Code valid for 5 minutes
- Single-use only
- Parent may:
  - Unlock
  - Unlock temporarily
  - Deny
  - Mark task complete

Note:
Android can support deeper controls through device management. iOS must use Apple's approved Family Controls/Screen Time APIs rather than full-device locking.

---

# 9. GPS Safety

Parents can:
- View live location
- View history
- Create safe zones
- Receive arrival/departure alerts
- Receive low battery alerts
- Receive GPS disabled alerts

Children cannot disable location sharing.

---

# 10. Family Chat

Features:
- WhatsApp-style conversations
- Family group
- Private chats
- Voice notes
- Photos
- Videos
- Documents
- Emoji
- Reactions
- Replies
- Search
- Pinned messages
- Read receipts
- Typing indicators

Future:
- Voice calls
- Video calls

---

# 11. Homework & Reading

Homework:
- Subject
- Due date
- Attachments
- Status

Reading:
- Book
- Pages
- Minutes
- Questions
- Reading streak
- Weekly reports

---

# 12. Rewards

- Stars
- Points
- Badges
- Levels
- Weekly rewards
- Parent-defined incentives

---

# 13. Parent Dashboard

Cards:
- Today's tasks
- Missed tasks
- Unlock requests
- Live locations
- Calendar
- Rewards
- Reading progress
- Homework
- Announcements
- Recent activity

---

# 14. Child Dashboard

Cards:
- Today's chores
- Homework
- Reading
- Appointments
- Rewards
- Chat
- SOS

---

# 15. Notifications

- Appointments
- Chores
- Homework
- Reading
- Unlock requests
- GPS alerts
- Chat
- Announcements
- Emergency alerts

---

# 16. Emergency SOS

One tap sends:
- GPS
- Time
- Battery
- Message
to all parents.

---

# 17. Security

- End-to-end encrypted chat
- Encrypted cloud storage
- Role-based permissions
- Audit logs
- Automatic backups
- Biometric authentication

---

# 18. Suggested UI

## Brand

Name:
**The Ipalibos**

Theme:
- Deep Emerald (#0D4B45)
- Gold (#C8A44D)
- Ivory (#F8F7F2)

Typography:
- Elegant serif headings
- Modern sans-serif body

## Mobile Navigation

Bottom tabs:
- Home
- Calendar
- Tasks
- Chat
- Family
- More

## Parent Home

Top:
- Greeting
- Notification bell
- Family selector

Middle:
- KPI cards
- Upcoming schedule
- Unlock requests
- Live location preview

Bottom:
- Recent activity

## Child Home

- Today's tasks
- Big "I've Completed This" button
- Rewards progress
- Next appointment

## Calendar

Month view
Colour-coded events
Tap for details
Quick add

## Tasks

Pinned cards
Progress ring
Due badges
Completion confirmation

## Chat

Bubble layout
Voice notes
Media previews
Pinned announcements

## Family Map

Live map
Safe zones
Battery
Travel history

---

# 19. Backend Architecture

Frontend:
- Flutter (recommended)
- Alternative: React Native

Backend:
- Firebase or Supabase

Database:
- PostgreSQL / Firestore

Storage:
- Cloud Storage

Notifications:
- Firebase Cloud Messaging
- Apple Push Notification Service

Maps:
- Google Maps / Apple Maps

Authentication:
- Firebase Auth

Analytics:
- Crashlytics
- Analytics

---

# 20. Future Roadmap

- AI family assistant
- Grocery scanner
- Meal planner
- Budget tracker
- Medical records
- School portal integration
- Smart home integration
- Wearable support
- Voice assistant
- Shared photo memories

This document serves as the master functional specification for The Ipalibos.
