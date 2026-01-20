#!/bin/bash
set -e

VERSION=$(grep 'version:' version.yml | sed 's/version: //')

if [ -z "$VERSION" ]; then
    echo "Error: Could not read version from version.yml"
    exit 1
fi

echo "Syncing version $VERSION to Xcode project..."

sed -i '' "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $VERSION;/g" \
    HarvestQRBill.xcodeproj/project.pbxproj

echo "Version synced to $VERSION"
