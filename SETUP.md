# DeskHive – Setup & Deployment Guide

## 1. Install Node.js (required for Cloud Functions)
```bash
brew install node
```

## 2. Install Firebase CLI
```bash
npm install -g firebase-tools
firebase login
```

## 3. Install Cloud Functions dependencies
```bash
cd /Users/sum/Desktop/DeskHive/functions
npm install
npm run build      # compile TypeScript → lib/
```

## 4. Configure Gmail credentials (for sending welcome emails)
```bash
# Use a Gmail account with an App Password (not your normal password)
# https://myaccount.google.com/apppasswords
firebase functions:config:set gmail.user="youremail@gmail.com" gmail.app_password="your-app-password"
```

## 5. Deploy everything
```bash
cd /Users/sum/Desktop/DeskHive
firebase deploy --only functions,firestore:rules
```

## 6. In Xcode – make sure these packages are added via SPM:
• firebase-ios-sdk   (FirebaseAuth, FirebaseFirestore, FirebaseFunctions)

Go to: File → Add Packages → https://github.com/firebase/firebase-ios-sdk
Add targets: FirebaseAuth, FirebaseFirestore, FirebaseFunctions

## Project file structure created
```
DeskHive/
├── Models/
│   └── UserModel.swift           # DeskHiveUser model + UserRole enum
├── State/
│   └── AppState.swift            # Global navigation state
├── ViewModels/
│   ├── AuthViewModel.swift       # Login, admin signup, session restore, signout
│   └── AdminViewModel.swift      # Fetch members, add member (Cloud Fn), toggle role
├── Views/
│   ├── SharedComponents.swift    # DeskHiveTextField, PrimaryButton, cards, etc.
│   ├── SplashView.swift          # Animated splash screen (fade + scale)
│   ├── Auth/
│   │   ├── LoginView.swift       # Email/password login
│   │   └── AdminSignUpView.swift # One-time admin registration
│   ├── Admin/
│   │   ├── AdminDashboardView.swift   # Stats, quick actions, members tab
│   │   └── AddMemberSheet.swift       # Bottom sheet to add a member
│   ├── Member/
│   │   └── MemberDashboardView.swift
│   └── ProjectLead/
│       └── ProjectLeadDashboardView.swift
├── DeskHiveApp.swift             # @main entry point + RootView navigation switch
└── ContentView.swift             # Preview wrapper only

functions/
├── src/
│   └── index.ts                  # createMember Cloud Function (TypeScript)
├── package.json
└── tsconfig.json

firestore.rules                   # Secure Firestore rules (admin-only writes)
firebase.json                     # Firebase project config
```

## Firestore Security Rules summary
- Users can only **read** their own document (admin reads all)
- Only **admin** can create member documents
- Users **cannot change their own role**
- Admin can update/delete any document
- All other documents are **denied by default**

## Flow
1. App opens → Splash (2.5s) → Login
2. First run: tap "Register as Admin" → one-time admin signup
3. Admin logs in → AdminDashboard
   - Home tab: stats + quick actions
   - Members tab: list with role badges + Make/Remove Project Lead buttons
   - "Add Member" sheet: enter email → Cloud Function creates Auth user,
     stores Firestore doc, sends welcome email (password never visible to admin)
4. Member logs in with credentials from email → MemberDashboard
5. ProjectLead logs in → ProjectLeadDashboard

## Authentication Notes (No-Behavior Setup Reference)
- Firebase Auth is the source of truth for credentials.
- Firestore `users/{uid}` is the source of truth for role-based navigation.
- Login succeeds only when both Auth sign-in and Firestore profile lookup succeed.
- If profile data is missing or invalid, the app routes back to login.

## Auth Smoke Test Checklist
1. Register an admin account from the login screen.
2. Confirm an admin profile document is created in `users/{uid}` with role `admin`.
3. Sign out and sign in again using the same admin account.
4. Verify session restore returns the same user role on relaunch.
5. Validate a wrong-password attempt shows a friendly auth error message.
