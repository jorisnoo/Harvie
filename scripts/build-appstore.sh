#!/bin/bash
set -euo pipefail

# Archive the Release-AppStore configuration and export an App Store Connect package.
# Xcode Cloud (see ci_scripts/) is the usual App Store route; this is the local equivalent.
#
# Usage: ./scripts/build-appstore.sh [--version X.Y.Z] [--build-number N]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/appstore"
ARCHIVE_PATH="$BUILD_DIR/Harvie.xcarchive"

extra_args=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            extra_args+=("MARKETING_VERSION=$2")
            shift 2
            ;;
        --build-number)
            extra_args+=("CURRENT_PROJECT_VERSION=$2")
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

xcodebuild archive \
    -project "$PROJECT_ROOT/Harvie.xcodeproj" \
    -scheme Harvie \
    -configuration Release-AppStore \
    -archivePath "$ARCHIVE_PATH" \
    -onlyUsePackageVersionsFromResolvedFile \
    -allowProvisioningUpdates \
    ${extra_args[@]+"${extra_args[@]}"}

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$SCRIPT_DIR/ExportOptions-AppStore.plist" \
    -exportPath "$BUILD_DIR/export" \
    -allowProvisioningUpdates

echo "App Store package exported to $BUILD_DIR/export"
