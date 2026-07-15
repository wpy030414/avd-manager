#!/usr/bin/env zsh
set -euo pipefail

# bundle-app.sh — Package the SwiftPM executable into AVDManager.app
# macOS 27 Liquid Glass 2 native AVD manager by im.xrl.avd_manager

SCRIPT_DIR="${0:A:h}"
SRC_DIR="${SCRIPT_DIR}/.."
BUILD_DIR="${SRC_DIR}/.build"
APP_NAME="AVDManager"
BUNDLE_ID="im.xrl.avd_manager"
APP_DIR="${SRC_DIR}/${APP_NAME}.app"

# Resolve toolchain
SWIFT_VERSION=$(swift --version | head -n1)
echo "🍥 Bundling ${APP_NAME}.app with ${SWIFT_VERSION}"

# Clean previous bundle
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"
mkdir -p "${APP_DIR}/Contents/Resources/en.lproj"
mkdir -p "${APP_DIR}/Contents/Resources/zh-Hans.lproj"

# Build release executable
echo "🔨 Building release executable..."
cd "${SRC_DIR}" && swift build -c release --product AVDManager

# Copy executable
EXECUTABLE_SOURCE="${BUILD_DIR}/release/AVDManager"
if [[ ! -f "${EXECUTABLE_SOURCE}" ]]; then
  EXECUTABLE_SOURCE="${BUILD_DIR}/release/${APP_NAME}"
fi
cp "${EXECUTABLE_SOURCE}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# Copy resources
RESOURCE_DIR="${SRC_DIR}/Resources"
if [[ -d "${RESOURCE_DIR}/Assets.xcassets" ]]; then
  cp -R "${RESOURCE_DIR}/Assets.xcassets" "${APP_DIR}/Contents/Resources/"
fi
if [[ -f "${RESOURCE_DIR}/Info.plist" ]]; then
  cp "${RESOURCE_DIR}/Info.plist" "${APP_DIR}/Contents/"
fi
for lang in en zh-Hans; do
  if [[ -d "${RESOURCE_DIR}/${lang}.lproj" ]]; then
    cp -R "${RESOURCE_DIR}/${lang}.lproj" "${APP_DIR}/Contents/Resources/"
  fi
done

# Ensure Info.plist exists
INFO_PLIST="${APP_DIR}/Contents/Info.plist"
if [[ ! -f "${INFO_PLIST}" ]]; then
  cat > "${INFO_PLIST}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>27.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.developer-tools</string>
</dict>
</plist>
EOF
fi

# Localize display names
for lang in en zh-Hans; do
  STRINGS_DIR="${APP_DIR}/Contents/Resources/${lang}.lproj"
  mkdir -p "${STRINGS_DIR}"
  if [[ ! -f "${STRINGS_DIR}/InfoPlist.strings" ]]; then
    if [[ "${lang}" == "en" ]]; then
      echo 'CFBundleDisplayName = "AVD Manager";' > "${STRINGS_DIR}/InfoPlist.strings"
      echo 'CFBundleName = "AVD Manager";' >> "${STRINGS_DIR}/InfoPlist.strings"
    else
      echo 'CFBundleDisplayName = "AVD管理器";' > "${STRINGS_DIR}/InfoPlist.strings"
      echo 'CFBundleName = "AVD管理器";' >> "${STRINGS_DIR}/InfoPlist.strings"
    fi
  fi
done

# Ad-hoc code sign
echo "🔏 Ad-hoc signing ${APP_NAME}.app..."
codesign --force --deep --sign - "${APP_DIR}"

echo "✅ ${APP_NAME}.app ready at ${APP_DIR}"
echo "   Bundle ID: ${BUNDLE_ID}"
echo "   Launch:    open '${APP_DIR}'"
