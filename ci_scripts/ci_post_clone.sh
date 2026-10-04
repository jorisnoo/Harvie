#!/bin/sh
set -e

# Sync version from Git tag to Xcode project
# This script runs after Xcode Cloud clones the repository

if [ -n "${CI_TAG:-}" ]; then
    # Release tags are stable numeric versions, without a prefix.
    VERSION="$CI_TAG"
    if ! printf '%s\n' "$VERSION" | grep -Eq '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'; then
        echo "Invalid release tag: $CI_TAG (expected X.Y.Z without v)" >&2
        exit 1
    fi

    cd "$CI_PRIMARY_REPOSITORY_PATH"

    # Update marketing version (user-facing version like 1.2.0)
    agvtool new-marketing-version "$VERSION"

    # Use Xcode Cloud’s increasing build number for this submission.
    agvtool new-version -all "${CI_BUILD_NUMBER:?Missing Xcode Cloud build number}"

    echo "Set version to $VERSION from tag $CI_TAG"
else
    echo "No CI_TAG found, using version from project"
fi
