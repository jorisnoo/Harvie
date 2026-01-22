#!/bin/sh
set -e

# Sync version from Git tag to Xcode project
# This script runs after Xcode Cloud clones the repository

if [ -n "$CI_TAG" ]; then
    # Remove 'v' prefix if present (e.g., v1.2.0 -> 1.2.0)
    VERSION=$(echo "$CI_TAG" | sed 's/^v//')

    cd "$CI_PRIMARY_REPOSITORY_PATH"

    # Update marketing version (user-facing version like 1.2.0)
    agvtool new-marketing-version "$VERSION"

    # Increment build number
    agvtool next-version -all

    echo "Set version to $VERSION from tag $CI_TAG"
else
    echo "No CI_TAG found, using version from project"
fi
