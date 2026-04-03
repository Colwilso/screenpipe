#!/bin/bash
# Verification script for paywall removal after merge
# Run this after completing the merge to ensure no paywall features returned

set -e

echo "🔍 Verifying paywall features remain removed..."
echo ""

ERRORS=0

# Test 1: No "buy credits" UI
echo "1. Checking for 'buy credits' strings..."
if grep -r "buy credits" apps/screenpipe-app-tauri/components/ 2>/dev/null; then
    echo "   ❌ FAILED: Found 'buy credits' UI"
    ERRORS=$((ERRORS + 1))
else
    echo "   ✅ PASSED: No 'buy credits' UI found"
fi

# Test 2: No credits_exhausted handling
echo "2. Checking for credits_exhausted handling..."
if grep -r "credits_exhausted" apps/screenpipe-app-tauri/components/ 2>/dev/null; then
    echo "   ❌ FAILED: Found credits_exhausted handling"
    ERRORS=$((ERRORS + 1))
else
    echo "   ✅ PASSED: No credits_exhausted handling"
fi

# Test 3: API URL points to localhost
echo "3. Checking SCREENPIPE_API_URL points to localhost..."
TAURI_URL=$(grep "SCREENPIPE_API_URL" apps/screenpipe-app-tauri/src-tauri/src/pi.rs | grep -o '"[^"]*"')
CORE_URL=$(grep "SCREENPIPE_API_URL" crates/screenpipe-core/src/agents/pi.rs | grep -o '"[^"]*"')

if [[ "$TAURI_URL" == *"localhost:4000"* ]]; then
    echo "   ✅ PASSED: Tauri API URL = $TAURI_URL"
else
    echo "   ❌ FAILED: Tauri API URL = $TAURI_URL (expected localhost:4000)"
    ERRORS=$((ERRORS + 1))
fi

if [[ "$CORE_URL" == *"localhost:4000"* ]]; then
    echo "   ✅ PASSED: Core API URL = $CORE_URL"
else
    echo "   ❌ FAILED: Core API URL = $CORE_URL (expected localhost:4000)"
    ERRORS=$((ERRORS + 1))
fi

# Test 4: No api.screenpi.pe references in Rust
echo "4. Checking for api.screenpi.pe in Rust code..."
if grep -r "api.screenpi.pe" apps/screenpipe-app-tauri/src-tauri/ crates/screenpipe-core/ 2>/dev/null; then
    echo "   ❌ FAILED: Found api.screenpi.pe references"
    ERRORS=$((ERRORS + 1))
else
    echo "   ✅ PASSED: No api.screenpi.pe in Rust code"
fi

# Test 5: Account/Team/Referral sections commented out
echo "5. Checking Account/Team/Referral sections are hidden..."
if grep -q "Account, Team, and Referral sections hidden" apps/screenpipe-app-tauri/app/settings/page.tsx; then
    echo "   ✅ PASSED: Settings sections properly commented"
else
    echo "   ❌ FAILED: Comment marker not found"
    ERRORS=$((ERRORS + 1))
fi

# Test 6: Cloud Archive tab commented out
echo "6. Checking Cloud Archive tab is hidden..."
if grep -q "Cloud Archive tab hidden" apps/screenpipe-app-tauri/components/settings/storage-section.tsx 2>/dev/null; then
    echo "   ✅ PASSED: Cloud Archive tab commented"
else
    echo "   ⚠️  WARNING: Comment marker not found (may not be implemented yet)"
fi

# Test 7: Sidebar shows "Alioth"
echo "7. Checking sidebar header..."
if grep -q "Alioth" apps/screenpipe-app-tauri/app/settings/page.tsx; then
    echo "   ✅ PASSED: Sidebar shows 'Alioth'"
else
    echo "   ❌ FAILED: Sidebar doesn't show 'Alioth'"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $ERRORS -eq 0 ]; then
    echo "✅ All verification checks passed!"
    echo "   Paywall features remain properly removed."
    exit 0
else
    echo "❌ $ERRORS verification check(s) failed!"
    echo "   Review the failures above and fix manually."
    exit 1
fi
