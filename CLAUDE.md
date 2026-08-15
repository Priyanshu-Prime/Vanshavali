# Project Context: Community Lineage App (Vanshavali)

## 1. Project Overview
**Goal:** Build a scalable, zero-cost mobile application for a village community (~500 initial users) to track ancestry and lineage.
**Core Function:** Users sign up, create their profile, and link themselves to parents/children/spouses to form a visual family tree.
**Target Audience:** Community members of varying tech literacy. UI must be extremely simple.
**Languages:** English and Gujarati (Bilingual support is mandatory).

## 2. Tech Stack & Constraints
* **Frontend:** Flutter (Dart).
* **Backend/Database:** Supabase (PostgreSQL).
* **Auth:** Supabase Auth (Magic Links via Email to keep costs $0, or Phone Auth if budget allows later).
* **Cost:** **Strict Zero-Cost** for development and initial deployment. Use Supabase Free Tier.
* **Platform:** Android & iOS (Mobile only).

## 3. Database Schema (Supabase PostgreSQL)
The app relies on a **Self-Referencing Table** for the lineage.

```sql
-- Table: family_members
create table public.family_members (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default now(),
  
  -- Auth Link: If NULL, this is a placeholder/ghost profile created by a relative.
  -- If NOT NULL, this is a real registered user.
  auth_user_id uuid references auth.users(id),

  -- Lineage Links (Self-Referencing)
  father_id uuid references public.family_members(id),
  mother_id uuid references public.family_members(id),
  spouse_id uuid references public.family_members(id),

  -- Basic Details
  first_name_en text not null,
  first_name_gu text, -- Gujarati
  last_name_en text not null,
  last_name_gu text, -- Gujarati
  gender text check (gender in ('Male', 'Female', 'Other')),
  dob date,
  is_alive boolean default true,
  
  -- Search/Filter
  village_origin text,
  current_city text,

  -- Deep Data (Flexible)
  -- Structure: { "education": "...", "occupation": "...", "medical": "..." }
  deep_details jsonb default '{}'::jsonb
);

-- RLS Policies (Security)
-- 1. Everyone can read everyone (Public Tree).
-- 2. Users can only update their own row (where auth_user_id = current_user).
```

## 4. Key Feature Logic

### A. The "Invite & Claim" System

Since users may already exist in the tree as "placeholders" (added by their brother/father), we need a claiming logic.

1. **Scenario:** User A creates a node for their brother, User B. `family_members` row created for B (`auth_user_id` is NULL).
2. **Action:** User A clicks "Invite" on User B's profile.
3. **Logic:** App generates a deep link containing User B's `UUID`.
4. **Onboarding:** When User B installs the app and signs in via the link:
* The app detects the `UUID` in the invite parameters.
* The app runs an RPC function to update User B's row: `UPDATE family_members SET auth_user_id = 'NEW_USER_ID' WHERE id = 'INVITE_UUID'`.
* User B instantly inherits their place in the tree.

### B. Tree Visualization

* **Library:** Use `graphview` or a custom painter.
* **Optimization:** Do **NOT** fetch the whole village.
* **Fetch Logic:** Fetch "Ego-centric" network: The User + Parents + Children + Spouse.
* **Navigation:** Tapping a node makes that node the new "Center" and fetches their connections.

### C. Localization (i18n)

* Use `flutter_localizations`.
* Store language preference in `shared_preferences`.
* All static text must be in `.arb` files (`app_en.arb`, `app_gu.arb`).

---

## 5. UI/UX Guidelines

* **Simplicity:** High contrast, large buttons.
* **Input:** When typing names, allow users to type in English and use a translation API (or manual entry) for the Gujarati field.
* **Visuals:** Use standard genealogical symbols (Box for Male, Circle for Female, Lines for relationships).

---

## 6. Development Phases (Instruction for AI)

When generating code, follow this sequence:

1. **Phase 1:** Setup Supabase client and Auth (Login Screen).
2. **Phase 2:** Profile Creation Form (Bilingual inputs).
3. **Phase 3:** The Dashboard (View my profile + Edit).
4. **Phase 4:** The Logic (Adding a family member + linking IDs).
5. **Phase 5:** The Visualization (Rendering the Tree).