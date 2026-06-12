# Aqarat — عقارات

B2B Multi-Tenant Real Estate Management SaaS (Flutter + Firebase).

## Overview
- **Frontend:** Flutter (Android & iOS), Riverpod state management.
- **Backend:** Firebase — Firestore, Auth, Storage.
- **Multi-tenancy:** every document carries `company_id`; data is isolated per company and enforced by Firestore security rules.

## Roles
- **Super Admin** — provisions companies, admins, and users (document-based: `users/{uid}.role == "super_admin"`).
- **Company Admin** — company-wide oversight + full user access (creates contracts, sees all agents).
- **Agent** — creates and sees only their own contracts.

## Key features
- Rent & Sale contracts (3-step Stepper), 12-month rent installments.
- On-device PDF generation with Kurdish/Arabic RTL (SPEDA font), branded with company logo/phones/address.
- Global B2B market for public listings with click-to-call.
- Pre-aggregated `company_stats` updated via Firestore transactions.

## Setup
```bash
flutter pub get
flutterfire configure   # regenerates lib/firebase_options.dart
flutter run
```

Deploy backend rules/indexes:
```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```
