#!/usr/bin/env bash
set -euo pipefail

# Fork release script
# Merges an upstream version tag, bumps major version +1, builds Release, and
# creates a GitHub release on the fork remote.
#
# Usage:
#   ./scripts/fork-release.sh v0.64.10        # merge upstream tag, build & release as v1.64.10
#   ./scripts/fork-release.sh v0.64.10 --no-merge  # skip merge (already merged), just build & release

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

FORK_REMOTE="fork"
FORK_BRANCH="fork/main"
FORK_REPO="ripley-xl/cmux"
BUILD_DIR="$REPO_ROOT/build-fork-release"

# --- Parse args ---
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <upstream-tag> [--no-merge]" >&2
  echo "  Example: $0 v0.64.10" >&2
  exit 1
fi

UPSTREAM_TAG="$1"
SKIP_MERGE=false
if [[ "${2:-}" == "--no-merge" ]]; then
  SKIP_MERGE=true
fi

# --- Compute fork version ---
# Strip leading 'v' to get version numbers
UPSTREAM_VER="${UPSTREAM_TAG#v}"
IFS='.' read -r UP_MAJOR UP_MINOR UP_PATCH <<< "$UPSTREAM_VER"
FORK_MAJOR=$((UP_MAJOR + 1))
FORK_VER="${FORK_MAJOR}.${UP_MINOR}.${UP_PATCH}"
FORK_TAG="v${FORK_VER}"

echo "============================================"
echo "  Upstream tag:  $UPSTREAM_TAG"
echo "  Fork version:  $FORK_TAG"
echo "============================================"

# --- Ensure on fork/main ---
CURRENT_BRANCH="$(git branch --show-current)"
if [[ "$CURRENT_BRANCH" != "$FORK_BRANCH" ]]; then
  echo "Switching to $FORK_BRANCH..."
  git checkout "$FORK_BRANCH"
fi

# --- Merge upstream tag ---
if [[ "$SKIP_MERGE" == false ]]; then
  echo ""
  echo ">>> Merging $UPSTREAM_TAG into $FORK_BRANCH..."
  if ! git merge-base --is-ancestor "$UPSTREAM_TAG" HEAD; then
    git merge "$UPSTREAM_TAG" -m "Merge upstream $UPSTREAM_TAG"
  else
    echo "    Already up to date with $UPSTREAM_TAG."
  fi
fi

# --- Update version in project ---
echo ""
echo ">>> Updating MARKETING_VERSION to $FORK_VER..."
PROJECT_FILE="cmux.xcodeproj/project.pbxproj"
CURRENT_MARKETING=$(grep -m1 'MARKETING_VERSION = ' "$PROJECT_FILE" | sed 's/.*= \(.*\);/\1/')
CURRENT_BUILD=$(grep -m1 'CURRENT_PROJECT_VERSION = ' "$PROJECT_FILE" | sed 's/.*= \(.*\);/\1/')
NEW_BUILD=$((CURRENT_BUILD + 1))

sed -i '' "s/MARKETING_VERSION = $CURRENT_MARKETING;/MARKETING_VERSION = $FORK_VER;/g" "$PROJECT_FILE"
sed -i '' "s/CURRENT_PROJECT_VERSION = $CURRENT_BUILD;/CURRENT_PROJECT_VERSION = $NEW_BUILD;/g" "$PROJECT_FILE"
echo "    MARKETING_VERSION: $CURRENT_MARKETING -> $FORK_VER"
echo "    CURRENT_PROJECT_VERSION: $CURRENT_BUILD -> $NEW_BUILD"

# --- Commit version bump ---
git add "$PROJECT_FILE"
if ! git diff --cached --quiet; then
  git commit -m "Bump version to $FORK_VER (upstream $UPSTREAM_TAG)"
fi

# --- Build Release (arm64 only, local machine) ---
echo ""
echo ">>> Building Release configuration..."
rm -rf "$BUILD_DIR"
xcodebuild -project cmux.xcodeproj -scheme cmux -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build 2>&1 | tail -5

APP_PATH="$(find "$BUILD_DIR/Build/Products/Release" -name '*.app' -maxdepth 1 | head -1)"
if [[ -z "$APP_PATH" ]]; then
  echo "Error: No .app found in build output!" >&2
  exit 1
fi
echo "    Built: $APP_PATH"

# --- Build cmuxd-remote and embed in app bundle ---
echo ""
echo ">>> Building cmuxd-remote daemon assets..."
REMOTE_ASSETS_DIR="$BUILD_DIR/remote-daemon-assets"
"$SCRIPT_DIR/build_remote_daemon_release_assets.sh" \
  --version "$FORK_VER" \
  --release-tag "$FORK_TAG" \
  --repo "$FORK_REPO" \
  --output-dir "$REMOTE_ASSETS_DIR"

echo ">>> Embedding cmuxd-remote binaries into app bundle Resources..."
APP_RESOURCES="$APP_PATH/Contents/Resources"
for target_file in "$REMOTE_ASSETS_DIR"/cmuxd-remote-*; do
  fname="$(basename "$target_file")"
  # Skip checksums and manifest files, only embed binaries
  case "$fname" in
    cmuxd-remote-checksums*|cmuxd-remote-manifest*) continue ;;
  esac
  cp "$target_file" "$APP_RESOURCES/$fname"
  chmod 755 "$APP_RESOURCES/$fname"
  echo "    Embedded: $fname"
done

echo ">>> Injecting cmuxd-remote manifest into app Info.plist..."
APP_PLIST="$APP_PATH/Contents/Info.plist"
MANIFEST_JSON="$(python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1], encoding="utf-8")), separators=(",",":")))' "$REMOTE_ASSETS_DIR/cmuxd-remote-manifest.json")"
plutil -remove CMUXRemoteDaemonManifestJSON "$APP_PLIST" >/dev/null 2>&1 || true
plutil -insert CMUXRemoteDaemonManifestJSON -string "$MANIFEST_JSON" "$APP_PLIST"
echo "    Manifest injected for version $FORK_VER"

# --- Create DMG ---
echo ""
echo ">>> Creating DMG..."
DMG_PATH="$BUILD_DIR/cmux-macos-${FORK_VER}.dmg"
hdiutil create -volname "cmux" -srcfolder "$APP_PATH" -ov -format UDZO "$DMG_PATH" 2>/dev/null
echo "    DMG: $DMG_PATH"

# --- Push and create release ---
echo ""
echo ">>> Pushing to $FORK_REMOTE..."
git push "$FORK_REMOTE" "$FORK_BRANCH"

# Tag
git tag -f "$FORK_TAG"
git push "$FORK_REMOTE" "$FORK_TAG" --force

echo ""
echo ">>> Creating GitHub release..."
# Delete existing release if present (allows re-running the script)
gh release delete "$FORK_TAG" --repo "$FORK_REPO" --yes 2>/dev/null || true
gh release create "$FORK_TAG" \
  --repo "$FORK_REPO" \
  --target "$FORK_BRANCH" \
  --title "$FORK_TAG" \
  --notes "合入上游 $UPSTREAM_TAG 版本" \
  "$DMG_PATH" \
  "$REMOTE_ASSETS_DIR"/cmuxd-remote-darwin-arm64 \
  "$REMOTE_ASSETS_DIR"/cmuxd-remote-darwin-amd64 \
  "$REMOTE_ASSETS_DIR"/cmuxd-remote-linux-arm64 \
  "$REMOTE_ASSETS_DIR"/cmuxd-remote-linux-amd64 \
  "$REMOTE_ASSETS_DIR"/cmuxd-remote-checksums.txt \
  "$REMOTE_ASSETS_DIR"/cmuxd-remote-manifest.json

# --- Install locally ---
echo ""
echo ">>> Installing to /Applications..."
# Quit running cmux if any
osascript -e 'quit app "cmux"' 2>/dev/null || true
sleep 1

# Remove old version and install new one
rm -rf /Applications/cmux.app
cp -R "$APP_PATH" /Applications/cmux.app
# Remove quarantine attribute for unsigned builds
xattr -cr /Applications/cmux.app 2>/dev/null || true
echo "    Installed: /Applications/cmux.app"

# Relaunch
echo ">>> Launching cmux..."
open /Applications/cmux.app

echo ""
echo "============================================"
echo "  Release created: $FORK_TAG"
echo "  https://github.com/$FORK_REPO/releases/tag/$FORK_TAG"
echo "  Installed & launched: /Applications/cmux.app"
echo "============================================"

# --- Done (keep build artifacts) ---
echo "  App: $APP_PATH"
echo "  DMG: $DMG_PATH"
