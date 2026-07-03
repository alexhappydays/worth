# Phase 2 — Apple signing setup (you do this, ~30 min)

You create the keys; they go into GitHub Secrets only. Never paste any of
these values into a chat, commit them, or store them in the repo.

## A. Apple Developer Program
1. Enroll at https://developer.apple.com/programs/enroll ($99/yr).
   Individual enrollment is fine. Wait for approval email (can take 24-48h).
2. Note your **Team ID** (10 characters): developer.apple.com → Membership.

## B. App IDs
developer.apple.com → Certificates, Identifiers & Profiles → Identifiers → +
1. App ID `com.YOURTEAM.worth`  — capabilities: **App Groups**
2. App ID `com.YOURTEAM.worth.widgets` — capabilities: **App Groups**
3. App Group `group.com.YOURTEAM.worth` (Identifiers → App Groups → +),
   then attach it to both App IDs.

## C. App Store Connect API key (lets CI upload builds)
appstoreconnect.apple.com → Users and Access → Integrations → App Store Connect API
1. Generate a **Team key**, role **App Manager**.
2. Download the `.p8` file (one-time download — keep it safe).
3. Note the **Key ID** and **Issuer ID** shown on that page.

## D. Create the app record
appstoreconnect.apple.com → Apps → + → New App
- Platform iOS, name "Worth" (if taken, e.g. "Worth — Subscription Value"),
  bundle ID `com.YOURTEAM.worth`, SKU `worth-001`.

## E. GitHub repo secrets
Repo → Settings → Secrets and variables → Actions → New repository secret:

| Secret name              | Value                                  |
|--------------------------|----------------------------------------|
| `ASC_KEY_ID`             | Key ID from step C                     |
| `ASC_ISSUER_ID`          | Issuer ID from step C                  |
| `ASC_PRIVATE_KEY`        | full text contents of the `.p8` file   |
| `APPLE_TEAM_ID`          | your 10-char Team ID                   |

That's everything. The release workflow (added in Phase 2) uses fastlane
with these secrets to create certificates/profiles automatically (fastlane
`match`-free "cert/sigh" or App Store Connect API signing) and upload to
TestFlight. You will never need to touch a keychain.

## F. Tell Claude Code
Once secrets are in, update `project.yml`:
- replace `com.YOURTEAM.worth` everywhere with your real bundle id
- set `DEVELOPMENT_TEAM` to your Team ID
Then push — the release pipeline takes over.
