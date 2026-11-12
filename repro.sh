#!/bin/bash
# Builds ReproducerApp in Release and runs it on iOS: on the booted simulator, or on a device.
#
#   ./repro.sh                           build for the booted simulator, install, launch, report
#   ./repro.sh build-device              build for a device: signed when DEVELOPMENT_TEAM is set, unsigned otherwise
#   ./repro.sh run-device <udid> <app>   install a signed build on the device, launch, report, uninstall
#
# The app's library registers its own descriptors for View and for Paragraph (<Text>) from +load. Once the app's
# first render is mounted, the app prints how many shadow nodes each of them adopted, and ends.
#
# Exit status: 1 while React Native uses the library's View descriptor and not its Paragraph descriptor, 0 once it
# uses both, and 2 when a step fails before that or the app reports neither.
# runs outside Git Bash: on macOS, whose bash 3.2 this script keeps to
set -uo pipefail

root=$(cd "$(dirname "$0")" && pwd)
app_folder="$root/ReproducerApp"
derived_data="$app_folder/ios/build"
launch_bound_seconds=300

fail() {
  echo "step failed: $*"
  exit 2
}

# Runs a command, ending it once it outlives the bound in seconds: macOS has no timeout(1).
bounded() {
  perl -e 'alarm shift; exec @ARGV or exit 127' "$@"
}

install_dependencies() {
  cd "$app_folder" || fail "no ReproducerApp folder"
  if command -v yarn > /dev/null; then
    yarn install --frozen-lockfile --non-interactive || fail "yarn install"
  else
    npx --yes yarn@1.22.22 install --frozen-lockfile --non-interactive || fail "yarn install"
  fi
  local version xcode
  version=$(node -p "require('react-native/package.json').version") || fail "no react-native in node_modules"
  echo "react-native: $version"
  (cd ios && pod install) || fail "pod install"
  xcode=$(xcodebuild -version) || fail "xcodebuild -version"
  echo "$xcode" | tr '\n' ' '
  echo
}

# Usage: build <destination> <products folder> [xcodebuild setting...]
build() {
  local destination=$1 products=$2
  shift 2
  cd "$app_folder/ios" || fail "no ios folder"
  xcodebuild -workspace ReproducerApp.xcworkspace -scheme ReproducerApp -configuration Release \
    -destination "$destination" -derivedDataPath "$derived_data" "$@" -quiet build || fail "xcodebuild"
  app="$derived_data/Build/Products/$products/ReproducerApp.app"
  [ -d "$app" ] || fail "no app at $app"
  echo "built $app"
}

bundle_identifier_of() {
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$1/Info.plist"
}

# Reads the app's report from its console output and ends the run with the verdict.
# Usage: verdict <console log> <platform>
verdict() {
  local log=$1 platform=$2 version view paragraph
  version=$(node -p "require('$app_folder/node_modules/react-native/package.json').version")
  grep '^library: ' "$log"
  view=$(sed -n 's/^library: LibraryViewComponentDescriptor adopted \([0-9]*\) shadow nodes.*/\1/p' "$log" | tail -n 1)
  paragraph=$(sed -n 's/^library: LibraryParagraphComponentDescriptor adopted \([0-9]*\) shadow nodes.*/\1/p' "$log" | tail -n 1)
  if [ -z "$view" ] || [ -z "$paragraph" ]; then
    echo "summary: react-native $version on $platform: the app printed no report"
    exit 2
  fi
  if [ "$view" -eq 0 ]; then
    echo "summary: react-native $version on $platform: the library's View descriptor adopted no shadow node, so the library's registration did not run"
    exit 2
  fi
  if [ "$paragraph" -eq 0 ]; then
    echo "summary: react-native $version on $platform: React Native used the library's View descriptor ($view shadow nodes) and not its Paragraph descriptor (0), keeping its own for <Text>"
    exit 1
  fi
  echo "summary: react-native $version on $platform: React Native used the library's View descriptor ($view shadow nodes) and its Paragraph descriptor ($paragraph)"
  exit 0
}

run_on_simulator() {
  local runtime bundle log
  runtime=$(xcrun simctl list devices booted | sed -n 's/^-- \(.*\) --$/\1/p' | head -n 1)
  [ -n "$runtime" ] || fail "no booted simulator: boot one first"
  install_dependencies
  build 'generic/platform=iOS Simulator' Release-iphonesimulator
  bundle=$(bundle_identifier_of "$app")
  xcrun simctl install booted "$app" || fail "simctl install"
  log="$derived_data/console.log"
  bounded "$launch_bound_seconds" xcrun simctl launch --console-pty --terminate-running-process booted "$bundle" \
    --exit-after-report > "$log" 2>&1
  verdict "$log" "the booted $runtime simulator"
}

build_for_device() {
  install_dependencies
  if [ -n "${DEVELOPMENT_TEAM:-}" ]; then
    build 'generic/platform=iOS' Release-iphoneos "DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM" CODE_SIGN_STYLE=Automatic \
      -allowProvisioningUpdates
  else
    build 'generic/platform=iOS' Release-iphoneos CODE_SIGNING_ALLOWED=NO
  fi
}

# Usage: run_on_device <udid> <app>
run_on_device() {
  local udid=$1 app=$2 bundle log device launch_status
  bundle=$(bundle_identifier_of "$app") || fail "no Info.plist in $app"
  mkdir -p "$derived_data"
  xcrun devicectl list devices --json-output "$derived_data/devices.json" > /dev/null 2>&1 || fail "devicectl list devices"
  device=$(/usr/bin/python3 -c '
import json, sys
for device in json.load(open(sys.argv[1]))["result"]["devices"]:
    hardware = device["hardwareProperties"]
    if hardware.get("udid") == sys.argv[2]:
        print("%s (%s), iOS %s" % (hardware.get("marketingName"), hardware.get("productType"),
                                    device["deviceProperties"].get("osVersionNumber")))
' "$derived_data/devices.json" "$udid")
  [ -n "$device" ] || fail "devicectl lists no device $udid"
  echo "device: $device"
  xcrun devicectl device install app --device "$udid" "$app" > /dev/null || fail "devicectl install"
  echo "installed $bundle"
  log="$derived_data/console-$udid.log"
  bounded "$launch_bound_seconds" xcrun devicectl device process launch --device "$udid" --console \
    --terminate-existing "$bundle" --exit-after-report > "$log" 2>&1
  launch_status=$?
  xcrun devicectl device uninstall app --device "$udid" "$bundle" > /dev/null && echo "uninstalled $bundle"
  [ "$launch_status" -eq 142 ] && echo "the app outlived ${launch_bound_seconds}s"
  verdict "$log" "$device"
}

case "${1:-simulator}" in
  simulator) run_on_simulator ;;
  build-device) build_for_device ;;
  run-device)
    [ $# -eq 3 ] || fail "usage: ./repro.sh run-device <udid> <app>"
    run_on_device "$2" "$3"
    ;;
  *) fail "usage: ./repro.sh [simulator | build-device | run-device <udid> <app>]" ;;
esac
