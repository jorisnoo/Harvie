# Building HarvestQRBill

This document explains how to build, sign, and notarize HarvestQRBill for distribution.

## Prerequisites

### Required Tools

- **Xcode**: Install from the Mac App Store or developer.apple.com
- **Xcode Command Line Tools**: `xcode-select --install`
- **create-dmg**: `brew install create-dmg`

### Code Signing Certificate

You need a **Developer ID Application** certificate installed in your Keychain. This is required for distributing macOS apps outside the Mac App Store.

To verify your certificate is installed:

```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
```

## One-Time Setup: Keychain Profile

For local builds, store your notarization credentials in your Keychain:

```bash
xcrun notarytool store-credentials "HarvestQRBill" \
    --apple-id "your@email.com" \
    --team-id "YOUR_TEAM_ID" \
    --password "xxxx-xxxx-xxxx-xxxx"
```

- `--apple-id`: Your Apple Developer account email
- `--team-id`: Your Developer Team ID (find it at developer.apple.com/account)
- `--password`: An app-specific password (generate at appleid.apple.com)

The profile name "HarvestQRBill" is the default used by the build scripts.

## Local Builds

### Build Only (No Notarization)

For quick testing without notarization:

```bash
./scripts/build-release.sh --build-only
```

This will:
1. Build and archive the app
2. Export the signed .app
3. Create ZIP and DMG packages

The artifacts won't be notarized, so macOS Gatekeeper will block them on other machines.

### Full Build with Notarization

For a complete release build:

```bash
./scripts/build-release.sh
```

This uses the default keychain profile "HarvestQRBill". To use a different profile:

```bash
NOTARY_PROFILE="MyProfile" ./scripts/build-release.sh
```

### Clean Build

Remove previous build artifacts before building:

```bash
./scripts/build-release.sh --clean
```

### Version Override

Override the version from version.yml:

```bash
./scripts/build-release.sh --version 1.2.3
```

## GitHub Actions (CI)

The GitHub Actions workflow (`.github/workflows/release.yml`) automatically builds and releases when a tag is pushed.

### Triggering a Release

1. Update version in `version.yml`
2. Commit the change
3. Tag and push:

```bash
git tag v1.2.3
git push origin v1.2.3
```

### CI Environment Variables

The workflow uses these secrets (configured in GitHub repository settings):

| Secret | Description |
|--------|-------------|
| `APPLE_ID` | Apple Developer account email |
| `APPLE_APP_PASSWORD` | App-specific password |
| `APPLE_TEAM_ID` | Developer Team ID |
| `MACOS_CERTIFICATE` | Base64-encoded .p12 certificate |
| `MACOS_CERTIFICATE_PASSWORD` | Password for the .p12 file |

The CI uses explicit Apple ID credentials (not a keychain profile) because the keychain profile cannot be transferred between machines.

## Build Artifacts

After a successful build, you'll find these in `build/`:

| File | Description |
|------|-------------|
| `HarvestQRBill.xcarchive/` | Xcode archive (for debugging) |
| `export/HarvestQRBill.app` | Signed (and stapled if notarized) app bundle |
| `HarvestQRBill-X.Y.Z.zip` | ZIP archive for distribution |
| `HarvestQRBill-X.Y.Z.dmg` | DMG installer for distribution |

## Troubleshooting

### Retry Notarization

If the build succeeded but notarization failed, use the standalone notarization script:

```bash
./scripts/notarize.sh build/HarvestQRBill-*.dmg
```

This will notarize, staple, and verify the file.

### Verify Code Signing

Check if an app is properly signed:

```bash
codesign -dv --verbose=4 build/export/HarvestQRBill.app
```

### Verify Notarization

Check if a DMG is properly notarized:

```bash
spctl -a -vvv -t install build/HarvestQRBill-*.dmg
```

For an app bundle:

```bash
spctl -a -vvv -t execute build/export/HarvestQRBill.app
```

### Check Notarization Status

If notarization is taking too long, check the status:

```bash
xcrun notarytool history --keychain-profile "HarvestQRBill"
```

Get details about a specific submission:

```bash
xcrun notarytool log <submission-id> --keychain-profile "HarvestQRBill"
```

### Common Issues

**"Developer ID Application certificate not found"**
- Ensure your Developer ID certificate is installed in the Keychain
- Check that it hasn't expired

**"Notarization credentials not configured"**
- Set up the keychain profile (see One-Time Setup above)
- Or provide explicit environment variables

**"Unable to upload" during notarization**
- Check your internet connection
- Verify your App-Specific Password is valid
- Ensure your Apple Developer account is in good standing
