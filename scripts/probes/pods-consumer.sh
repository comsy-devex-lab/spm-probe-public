#!/bin/bash
set -euo pipefail
# Public test fixture only. CocoaPods consumes the already-committed XCFramework.
DEVELOPER_DIR="$(xcode-select -p)"
if [[ "$DEVELOPER_DIR" != /Applications/Xcode*.app/Contents/Developer ]]; then
  echo "Full Xcode under /Applications is required: $DEVELOPER_DIR" >&2
  exit 1
fi
POD="$(command -v pod)"  # Hosted runner's existing installation; never install tools.
RUBY="$(command -v ruby)"
ROOT="$(mktemp -d "$(cd "$(dirname "$0")" && pwd)/pods-consumer.XXXXXX")"
mkdir -p "$ROOT/home" "$ROOT/tmp" "$ROOT/pods-home" "$ROOT/pods-cache" "$ROOT/spec-repos"
touch "$ROOT/home/.netrc"
env -i PATH="$(dirname "$POD"):$(dirname "$RUBY"):/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  HOME="$ROOT/home" CFFIXED_USER_HOME="$ROOT/home" TMPDIR="$ROOT/tmp/" \
  LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
  DEVELOPER_DIR="$DEVELOPER_DIR" POD="$POD" \
  CP_HOME_DIR="$ROOT/pods-home" CP_CACHE_DIR="$ROOT/pods-cache" CP_REPOS_DIR="$ROOT/spec-repos" \
  COCOAPODS_DISABLE_STATS=true COCOAPODS_SKIP_UPDATE_MESSAGE=true \
  GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_TERMINAL_PROMPT=0 \
  GIT_ASKPASS=/usr/bin/false SSH_ASKPASS=/usr/bin/false \
  GIT_CONFIG_COUNT=4 \
  GIT_CONFIG_KEY_0=credential.helper GIT_CONFIG_VALUE_0= \
  GIT_CONFIG_KEY_1=http.extraHeader GIT_CONFIG_VALUE_1= \
  GIT_CONFIG_KEY_2=http.cookieFile GIT_CONFIG_VALUE_2=/dev/null \
  GIT_CONFIG_KEY_3=http.saveCookies GIT_CONFIG_VALUE_3=false \
  /bin/bash -s -- "$ROOT" <<'CLEAN'
set -euo pipefail
ROOT="$1"
for path in "$HOME" "$CP_HOME_DIR" "$CP_CACHE_DIR" "$CP_REPOS_DIR"; do
  if [[ -n "$(find "$path" -mindepth 1 ! -name .netrc -print -quit)" ]]; then
    echo "Expected an empty home/cache before installation: $path" >&2
    exit 1
  fi
  printf 'Fresh isolated home/cache before pod install: %s\n' "$path"
done
xcodebuild -version
"$POD" --version
mkdir -p "$ROOT/IOSConsumer/ProbeConsumer.xcodeproj"
cd "$ROOT/IOSConsumer"
cat > App.swift <<'EOF'
import UIKit
import ProbeBinary
@main final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        precondition(probe_value() == 42)
        return true
    }
}
EOF
cat > ProbeConsumer.xcodeproj/project.pbxproj <<'EOF'
// !$*UTF8*$!
{
 archiveVersion = 1;
 classes = {};
 objectVersion = 56;
 objects = {
  100000000000000000000001 = {isa = PBXProject; buildConfigurationList = 100000000000000000000002; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en, Base); mainGroup = 100000000000000000000003; productRefGroup = 100000000000000000000004; projectDirPath = ""; projectRoot = ""; targets = (100000000000000000000005); };
  100000000000000000000002 = {isa = XCConfigurationList; buildConfigurations = (100000000000000000000006); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };
  100000000000000000000003 = {isa = PBXGroup; children = (100000000000000000000007, 100000000000000000000004); sourceTree = "<group>"; };
  100000000000000000000004 = {isa = PBXGroup; children = (100000000000000000000008); name = Products; sourceTree = "<group>"; };
  100000000000000000000005 = {isa = PBXNativeTarget; buildConfigurationList = 100000000000000000000009; buildPhases = (10000000000000000000000A); buildRules = (); dependencies = (); name = ProbeConsumer; productName = ProbeConsumer; productReference = 100000000000000000000008; productType = "com.apple.product-type.application"; };
  100000000000000000000006 = {isa = XCBuildConfiguration; buildSettings = {SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 15.0; }; name = Release; };
  100000000000000000000007 = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = App.swift; sourceTree = "<group>"; };
  100000000000000000000008 = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = ProbeConsumer.app; sourceTree = BUILT_PRODUCTS_DIR; };
  100000000000000000000009 = {isa = XCConfigurationList; buildConfigurations = (10000000000000000000000C); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };
  10000000000000000000000A = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (10000000000000000000000D); runOnlyForDeploymentPostprocessing = 0; };
  10000000000000000000000C = {isa = XCBuildConfiguration; buildSettings = {CODE_SIGNING_ALLOWED = NO; GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = invalid.example.ProbeConsumer; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = "1,2"; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; }; name = Release; };
  10000000000000000000000D = {isa = PBXBuildFile; fileRef = 100000000000000000000007; };
 };
 rootObject = 100000000000000000000001;
}
EOF
cat > Podfile <<'EOF'
source 'https://github.com/comsy-devex-lab/spm-probe-public.git'
platform :ios, '15.0'
project 'ProbeConsumer.xcodeproj'
target 'ProbeConsumer' do
  use_frameworks! :linkage => :static
  pod 'ProbePod', '= 0.2.0'
end
EOF
"$POD" install
# Lockfile evidence comes from CocoaPods' own resolver, not a hand-written lock.
ruby -e 'require "yaml"; lock = YAML.load_file("Podfile.lock"); abort "wrong pod version" unless lock.fetch("PODS").include?("ProbePod (0.2.0)"); puts "Resolved ProbePod 0.2.0 from public Git spec index"'
xcodebuild -workspace ProbeConsumer.xcworkspace \
  -scheme ProbeConsumer -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$ROOT/DerivedData" \
  CODE_SIGNING_ALLOWED=NO build
printf '\nPASS: CocoaPods resolved/installed ProbePod 0.2.0; imported/linked ProbeBinary in unsigned iOS simulator build.\n'
printf 'NOT TESTED: runtime execution, physical device deployment, product repositories or production promotion.\n'
CLEAN
printf 'Consumer outputs: %s\n' "$ROOT"
