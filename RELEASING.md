# Releasing

Release from `main` using an explicit version without a `v` prefix. `CHANGELOG.md` is the source of truth for GitHub release notes. The repo-local Python helper requires Python 3.9+, Git, and the project’s existing build/test tools; Shipmark is no longer used.

## Prepare

1. Review changes since the last release and choose the version from compatibility: patch for fixes, minor for compatible additions, major for breaking changes. For a pre-1.0 package, describe incompatible changes explicitly and normally bump the minor version. Do not infer the bump solely from commit prefixes.
2. Add a curated entry at the top of `CHANGELOG.md`: `## [X.Y.Z] - YYYY-MM-DD`. Use only relevant sections such as Added, Changed, Fixed, and Breaking. Explain user-visible behavior and migrations; combine related commits and omit routine dependency/CI noise. Preserve all historical entries. Use `X.Y.Z` everywhere, including release links.
3. Update the version files and build outputs described below. Run the relevant checks, review the complete diff, and commit only the intended release changes (normally `release: X.Y.Z`). Respect configured Git commit signing. Never include unrelated local work.

Configured release checks:

```sh
xcodebuild -project Harvie.xcodeproj -scheme Harvie -configuration Debug -derivedDataPath /tmp/Harvie-release-check CODE_SIGNING_ALLOWED=NO build
```

Install the project’s normal dependencies first. The helper runs these checks when publishing; dry-run prints them without executing them. Run any additional checks needed for the changed behavior before committing.

## Release

From the repository root, replace `X.Y.Z` with the chosen version:

```sh
python3 scripts/release.py X.Y.Z --dry-run
python3 scripts/release.py X.Y.Z
```

The helper requires the configured release branch, a clean working tree, a unique nonempty changelog entry, matching version files, a newer version than reachable local release tags, and an unpublished remote tag. Fetch origin and its tags before preparing a release so the local history is current. Dry-run reads remote refs but does not modify files, run checks, tag, or push.

Publishing runs the configured checks, creates a signed annotated tag, and atomically pushes the branch and that specific tag to origin. It never generates changelog text, edits version files, stages files, commits, or pushes other tags. `.release.json` holds the branch, checks, version files and signing policy. A signing failure is an error; configure the agent’s signing access rather than silently disabling signing.

The tag workflow validates the same changelog entry and publishes it with the exact version as the release title. It uses `--verify-tag` and links to the changelog at the released commit. Only this workflow creates the GitHub release. Package prereleases such as `1.2.3-beta.1` are marked prerelease and do not become Latest.

Verify the workflow and published release/assets before reporting success. If a push fails after local tagging, the helper can reuse that tag only while it still points to the same HEAD and is unpublished remotely. For runner or secret failures, fix the configuration and rerun the workflow. For a problem in the tagged source, prepare a corrected new version. Never move, delete, or recreate a published tag. The workflows reuse an existing GitHub release on reruns so downstream publishing steps can recover. App workflows download the already-published assets before calculating cask checksums; unchanged cask/website updates do not create another commit.

## Project details

The tag workflow builds, signs and notarises the app, then publishes the DMG and ZIP with these notes. Keep the existing signing secrets and asset naming: the ZIP must contain one top-level `.app`, its bundle version must match the tag, and AppUpdater must be able to find the versioned ZIP. The build script receives the tag as `--version`; do not edit generated archives or introduce a second GitHub release command.

The existing workflow also updates the Homebrew tap and website download URL.

For a local signed build, use `./scripts/build-release.sh --clean --notarise --version X.Y.Z`. GitHub Actions remains responsible for publishing release assets.

Apple app releases use stable numeric `X.Y.Z` versions. Keep the app’s marketing version in sync with the release tag; use an increasing build number for TestFlight/App Store submissions.

## Maintaining the release tools

When changing the helper, run `python3 scripts/test_release.py`. The tests use temporary repositories and local bare remotes, including a temporary SSH signing key; they never contact GitHub or publish real releases. Keep the helper and its tests consistent across the packages and release-enabled apps.
