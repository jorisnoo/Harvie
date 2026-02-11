#!/bin/bash
set -euo pipefail

# Standalone notarisation helper
# Use this to retry notarisation when build-release.sh fails at notarisation
# or when you need to notarise individual artifacts.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Auto-detect Xcode project
XCODE_PROJECT=$(ls -d "$PROJECT_ROOT"/*.xcodeproj 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo "")

if [[ -z "$XCODE_PROJECT" ]]; then
    echo "Error: Could not find *.xcodeproj in project root"
    exit 1
fi

# Extract app name from Xcode project
APP_NAME="${XCODE_PROJECT%.xcodeproj}"
NOTARY_PROFILE="${NOTARY_PROFILE:-$APP_NAME}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default notary profile for local builds (used when APPLE_ID is not set)
DEFAULT_NOTARY_PROFILE="$NOTARY_PROFILE"

print_usage() {
    cat << EOF
Usage: $(basename "$0") FILE [FILE...]

Notarise one or more files (ZIP or DMG) with Apple.

Environment Variables:
    NOTARY_PROFILE      Keychain profile name (recommended for local builds)

    Or use these three together:
    APPLE_ID            Apple ID email for notarisation
    APPLE_APP_PASSWORD  App-specific password
    APPLE_TEAM_ID       Developer Team ID

Examples:
    # With keychain profile:
    NOTARY_PROFILE="$NOTARY_PROFILE" ./scripts/notarise.sh build/*.dmg

    # With env vars:
    APPLE_ID="..." APPLE_APP_PASSWORD="..." APPLE_TEAM_ID="..." \\
    ./scripts/notarise.sh build/*.dmg

    # Multiple files:
    NOTARY_PROFILE="$NOTARY_PROFILE" ./scripts/notarise.sh \\
        build/$APP_NAME-1.0.0.zip \\
        build/$APP_NAME-1.0.0.dmg

One-time setup for keychain profile:
    xcrun notarytool store-credentials "$NOTARY_PROFILE" \\
        --apple-id "your@email.com" \\
        --team-id "YOUR_TEAM_ID" \\
        --password "xxxx-xxxx-xxxx-xxxx"
EOF
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_credentials() {
    # Prefer explicit Apple ID credentials (used by CI)
    if [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_APP_PASSWORD:-}" ] && [ -n "${APPLE_TEAM_ID:-}" ]; then
        log_info "Using Apple ID credentials for notarisation"
        return 0
    fi

    # Fall back to keychain profile (local builds)
    NOTARY_PROFILE="${NOTARY_PROFILE:-$DEFAULT_NOTARY_PROFILE}"
    log_info "Using keychain profile: $NOTARY_PROFILE"
    return 0
}

notarise_file() {
    local file_path="$1"

    if [ ! -f "$file_path" ]; then
        log_error "File not found: $file_path"
        return 1
    fi

    log_info "Submitting for notarisation: $file_path"

    # Prefer explicit Apple ID credentials (used by CI)
    if [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_APP_PASSWORD:-}" ] && [ -n "${APPLE_TEAM_ID:-}" ]; then
        xcrun notarytool submit "$file_path" \
            --apple-id "$APPLE_ID" \
            --password "$APPLE_APP_PASSWORD" \
            --team-id "$APPLE_TEAM_ID" \
            --wait
    else
        xcrun notarytool submit "$file_path" \
            --keychain-profile "$NOTARY_PROFILE" \
            --wait
    fi

    log_info "Notarisation complete for: $file_path"
}

staple_file() {
    local file_path="$1"

    log_info "Stapling notarisation ticket to: $file_path"
    xcrun stapler staple "$file_path"
    log_info "Stapled successfully: $file_path"
}

verify_file() {
    local file_path="$1"
    local extension="${file_path##*.}"

    log_info "Verifying notarisation: $file_path"

    if [ "$extension" = "dmg" ]; then
        spctl -a -vvv -t install "$file_path"
    elif [ "$extension" = "zip" ]; then
        # For ZIP, extract and verify the app inside
        local temp_dir
        temp_dir=$(mktemp -d)
        unzip -q "$file_path" -d "$temp_dir"
        local app_path
        app_path=$(find "$temp_dir" -name "*.app" -maxdepth 1 | head -1)
        if [ -n "$app_path" ]; then
            spctl -a -vvv -t execute "$app_path"
        else
            log_warn "No .app found in ZIP for verification"
        fi
        rm -rf "$temp_dir"
    else
        log_warn "Unknown file type, skipping verification: $file_path"
        return 0
    fi

    log_info "Verification passed: $file_path"
}

# Check for help or no arguments
if [ $# -eq 0 ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    print_usage
    exit 0
fi

# Main execution
main() {
    check_credentials

    local success_count=0
    local fail_count=0

    for file in "$@"; do
        echo ""
        echo "========================================"
        echo "Processing: $file"
        echo "========================================"

        if notarise_file "$file"; then
            staple_file "$file"
            if verify_file "$file"; then
                log_info "Successfully notarised and verified: $file"
                ((success_count++))
            else
                log_error "Verification failed: $file"
                ((fail_count++))
            fi
        else
            log_error "Notarisation failed: $file"
            ((fail_count++))
        fi
    done

    echo ""
    echo "========================================"
    echo "Summary"
    echo "========================================"
    echo "Successful: $success_count"
    echo "Failed:     $fail_count"
    echo "========================================"

    if [ $fail_count -gt 0 ]; then
        exit 1
    fi
}

main "$@"
