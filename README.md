# Worth — is your subscription worth it?

Privacy-first iOS app: log every use of your subscriptions from an
interactive widget; see cost-per-use and a green/yellow/red verdict.
All data local (SwiftData). Built entirely from Windows via GitHub Actions.

## Status: Phase 1 — pipeline proof (unsigned build)

## Your next steps (Windows, ~10 min)

1. Create a **public** GitHub repo called `worth`.
2. In a terminal in this folder:
   ```
   git init
   git add .
   git commit -m "Phase 1: app skeleton + CI"
   git branch -M main
   git remote add origin https://github.com/YOUR_USERNAME/worth.git
   git push -u origin main
   ```
3. Open the repo → **Actions** tab → watch "Build (unsigned)" run (~5-8 min).
   Green check = Phase 1 verified. Red X = paste the failing log into Claude.
4. In parallel, start `docs/APPLE_SETUP.md` (Apple approval can take 1-2 days,
   so kick it off now).

## Roadmap
- [x] Phase 1: repo + unsigned CI build
- [ ] Phase 2: signing + TestFlight upload (release.yml, fastlane)
- [x] Phase 3: core app — onboarding presets, verdict rings, waste headline
- [ ] Phase 4: interactive widgets (Quick-Log AppIntent, Verdict, Next Due, Smart Stack)
- [ ] Phase 5: renewal-eve notifications
- [ ] Phase 6: StoreKit 2 Pro + Founder's cohort (free forever for week-1 users)
- [ ] Phase 7: App Store submission

## Structure
- `project.yml` — XcodeGen definition (the CI Mac generates the .xcodeproj)
- `Sources/Worth` — app
- `Sources/Shared` — models + App Group model container (compiled into both targets)
- `Sources/WorthWidgets` — widget extension
- `.github/workflows/build.yml` — CI
