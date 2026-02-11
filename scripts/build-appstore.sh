#!/bin/bash
set -euo pipefail

# Wrapper script for building App Store distribution
# This calls build-release.sh with the Release-AppStore configuration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/build-release.sh" --configuration "Release-AppStore" "$@"
