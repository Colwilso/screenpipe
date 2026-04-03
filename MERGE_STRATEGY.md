# Merge Strategy: Mainline → Fork (Preserving Paywall Removals)

**Goal**: Pull 50 commits from origin/main while preserving all paywall/subscription feature removals.

## Pre-Merge Checklist

- [ ] Commit all local changes
- [ ] Create backup branch: `git branch backup-before-merge`
- [ ] Review this strategy document

## Your Paywall Removals (Must Preserve)

### 1. Credit/Billing UI Removed
**Commit**: `a30aa85ae` "Route pipes through local LiteLLM proxy, remove credit UI"
**Files**:
- `apps/screenpipe-app-tauri/components/settings/pipes-section.tsx`
  - Removed: Credit exhausted banner
  - Removed: Buy credits button
  - Removed: Daily limit tracking
  - Removed: `parsePipeError()` rate limit categorization
- `apps/screenpipe-app-tauri/src-tauri/src/pi.rs`
  - Changed: `SCREENPIPE_API_URL` = `http://localhost:4000/v1` (was `https://api.screenpi.pe/v1`)
- `crates/screenpipe-core/src/agents/pi.rs`
  - Changed: `SCREENPIPE_API_URL` = `http://localhost:4000/v1`

### 2. Cloud Account Features Hidden
**Commit**: `ba8491f25` "Add native AWS Bedrock provider, hide cloud account features"
**Files**:
- `apps/screenpipe-app-tauri/app/settings/page.tsx`
  - Removed: Account settings section (commented out)
  - Removed: Team settings section (commented out)
  - Removed: Referral ("Get free month") section (commented out)
  - Removed: Team promo card
  - Changed: Sidebar header from "screenpipe" to "Alioth"
- `apps/screenpipe-app-tauri/components/settings/storage-section.tsx`
  - Removed: Cloud Archive tab (commented out)

### 3. BYOK Upgrade Dialog Suppressed
**Commit**: `e51db6d93` "Fix pipes ignoring default AI preset and suppress upgrade dialog"
**Files**:
- (Need to identify specific files)

## Mainline Changes That May Re-Introduce Paywall Features

### High Risk (Manual Review Required)

1. **ai-presets.tsx** - Changed in both branches
   - Mainline: `10d6523f0` added cost tier badges
   - Your fork: Added Bedrock provider UI
   - **Action**: Accept your version, manually verify cost badges didn't return

2. **pipes-section.tsx** - Changed in both branches
   - Mainline: `e98eeb316` removed buy credits button (aligns with your changes!)
   - Your fork: Removed all credit tracking
   - **Action**: Use 3-way merge, verify no credit UI returned

3. **settings/page.tsx** - You modified, mainline may have too
   - **Action**: Manually verify Account/Team/Referral sections stay hidden

4. **pi.rs** (both versions)
   - Mainline: Various Pi improvements
   - Your fork: Changed API URL to localhost:4000
   - **Action**: Keep your localhost:4000 URL, accept other improvements

### Medium Risk (Automated Merge OK, Spot Check)

5. **standalone-chat.tsx** - Mainline added features
6. **recording-settings.tsx** - Mainline added work hours schedule
7. **store.rs** - Mainline may have added team/account state

## Merge Commands

```bash
# 1. Create merge branch
git checkout feat/activity-dashboard-public
git checkout -b merge-mainline-$(date +%Y%m%d)

# 2. Start merge (expect conflicts)
git merge origin/main --no-commit --no-ff

# 3. Check conflict status
git status

# 4. For each conflict, choose strategy:
```

## File-Specific Merge Strategies

### Auto-Accept Yours (Paywall Removals)
```bash
# These files should keep YOUR version to preserve paywall removals
git checkout --ours apps/screenpipe-app-tauri/app/settings/page.tsx
git checkout --ours apps/screenpipe-app-tauri/components/settings/storage-section.tsx
```

### Manual 3-Way Merge (Both Changed)
```bash
# These need manual conflict resolution
code apps/screenpipe-app-tauri/components/settings/pipes-section.tsx
code apps/screenpipe-app-tauri/components/settings/ai-presets.tsx
code apps/screenpipe-app-tauri/src-tauri/src/pi.rs
code crates/screenpipe-core/src/agents/pi.rs
```

**For each file**:
1. Open in VS Code (shows 3-way diff)
2. Accept YOUR changes for paywall-related code
3. Accept THEIRS for new features/bug fixes
4. Key checks:
   - `SCREENPIPE_API_URL` stays `localhost:4000/v1`
   - No "buy credits" buttons
   - No credit/daily limit tracking
   - No Account/Team/Referral UI sections

### Auto-Accept Theirs (New Features)
```bash
# These are new files or unrelated changes - safe to accept mainline
git checkout --theirs apps/screenpipe-app-tauri/components/settings/recording-settings.tsx
```

## Post-Merge Verification

### 1. Grep for Paywall Patterns
```bash
# Should return ZERO results:
grep -r "buy credits" apps/screenpipe-app-tauri/components/
grep -r "credits_exhausted" apps/screenpipe-app-tauri/components/
grep -r "api.screenpi.pe" apps/screenpipe-app-tauri/src-tauri/
grep -r "api.screenpi.pe" crates/screenpipe-core/
```

### 2. Check API URL
```bash
# Should show localhost:4000, not api.screenpi.pe:
grep -n "SCREENPIPE_API_URL" apps/screenpipe-app-tauri/src-tauri/src/pi.rs
grep -n "SCREENPIPE_API_URL" crates/screenpipe-core/src/agents/pi.rs
```

### 3. Check Settings UI
```bash
# Should show commented-out sections:
grep -A 2 "Account, Team, and Referral sections hidden" apps/screenpipe-app-tauri/app/settings/page.tsx
```

### 4. Visual Verification
- [ ] Launch app: `cd apps/screenpipe-app-tauri && bun tauri dev`
- [ ] Check Settings sidebar - no "Account", "Team", "Get free month" options
- [ ] Check Pipes page - no credit warnings or "buy credits" buttons
- [ ] Check Storage settings - no "Cloud Archive" tab
- [ ] Check sidebar header - shows "Alioth" not "screenpipe"

## Rollback Plan

If merge introduces paywall features:
```bash
# Abort merge
git merge --abort

# Or reset to pre-merge state
git reset --hard backup-before-merge
```

## Success Criteria

✅ All 50 mainline commits merged
✅ No "buy credits" UI anywhere
✅ No credit/daily limit tracking
✅ API URL points to localhost:4000/v1
✅ Account/Team/Referral settings hidden
✅ Cloud Archive tab hidden
✅ Sidebar shows "Alioth"
✅ App builds and runs
✅ LiteLLM proxy still works for pipes

## Notes

- Mainline commit `e98eeb316` already removed buy credits button - our changes align!
- Mainline commit `f975d863c` removed Claude OAuth - also aligns with our goals
- Some new mainline features (work hours, triggers) are safe - they don't re-enable paywall
