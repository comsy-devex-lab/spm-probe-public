#!/bin/bash
set -euo pipefail
# Public test fixture only. Builds consumers, never rebuilds the C binary fixture.
DEVELOPER_DIR="$(xcode-select -p)"
if [[ "$DEVELOPER_DIR" != /Applications/Xcode*.app/Contents/Developer ]]; then
  echo "Full Xcode under /Applications is required: $DEVELOPER_DIR" >&2
  exit 1
fi
ROOT="$(mktemp -d "$(cd "$(dirname "$0")" && pwd)/remote-consumer.XXXXXX")"
mkdir -p "$ROOT/home" "$ROOT/tmp"
touch "$ROOT/home/.netrc"
# No inherited tokens, proxy credentials, cookies, Git settings or package caches.
# Empty helper/extraHeader values reset any inherited Git multi-value configuration.
env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin \
  HOME="$ROOT/home" CFFIXED_USER_HOME="$ROOT/home" TMPDIR="$ROOT/tmp/" \
  DEVELOPER_DIR="$DEVELOPER_DIR" \
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
xcodebuild -version
mkdir -p "$ROOT/MacConsumer/Sources/ProbeConsumer" "$ROOT/IOSConsumer/ProbeConsumer.xcodeproj"
cat > "$ROOT/MacConsumer/Package.swift" <<'EOF'
// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "ProbeConsumer",
    platforms: [.macOS(.v12)],
    dependencies: [.package(url: "https://github.com/comsy-devex-lab/spm-probe-public.git", exact: "0.1.0")],
    targets: [.executableTarget(name: "ProbeConsumer", dependencies: [
        .product(name: "ProbePackage", package: "spm-probe-public")
    ])]
)
EOF
cat > "$ROOT/MacConsumer/Sources/ProbeConsumer/main.swift" <<'EOF'
import ProbeBinary
precondition(probe_value() == 42)
print("remote probe_value=42")
EOF
# SwiftPM explicitly disables both credential stores; fresh paths avoid local reuse.
(cd "$ROOT/MacConsumer" && swift run --disable-keychain --disable-netrc \
  --cache-path "$ROOT/mac-cache" --config-path "$ROOT/mac-config" \
  --security-path "$ROOT/mac-security" ProbeConsumer)
cat > "$ROOT/IOSConsumer/App.swift" <<'EOF'
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
cat > "$ROOT/IOSConsumer/ProbeConsumer.xcodeproj/project.pbxproj" <<'EOF'
// !$*UTF8*$!
{
 archiveVersion = 1;
 classes = {};
 objectVersion = 56;
 objects = {
  100000000000000000000001 = {isa = PBXProject; buildConfigurationList = 100000000000000000000002; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en, Base); mainGroup = 100000000000000000000003; productRefGroup = 100000000000000000000004; projectDirPath = ""; projectRoot = ""; packageReferences = (100000000000000000000010); targets = (100000000000000000000005); };
  100000000000000000000002 = {isa = XCConfigurationList; buildConfigurations = (100000000000000000000006); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };
  100000000000000000000003 = {isa = PBXGroup; children = (100000000000000000000007, 100000000000000000000004); sourceTree = "<group>"; };
  100000000000000000000004 = {isa = PBXGroup; children = (100000000000000000000008); name = Products; sourceTree = "<group>"; };
  100000000000000000000005 = {isa = PBXNativeTarget; buildConfigurationList = 100000000000000000000009; buildPhases = (10000000000000000000000A, 10000000000000000000000B); buildRules = (); dependencies = (); name = ProbeConsumer; packageProductDependencies = (100000000000000000000011); productName = ProbeConsumer; productReference = 100000000000000000000008; productType = "com.apple.product-type.application"; };
  100000000000000000000006 = {isa = XCBuildConfiguration; buildSettings = {SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 15.0; }; name = Release; };
  100000000000000000000007 = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = App.swift; sourceTree = "<group>"; };
  100000000000000000000008 = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = ProbeConsumer.app; sourceTree = BUILT_PRODUCTS_DIR; };
  100000000000000000000009 = {isa = XCConfigurationList; buildConfigurations = (10000000000000000000000C); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };
  10000000000000000000000A = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (10000000000000000000000D); runOnlyForDeploymentPostprocessing = 0; };
  10000000000000000000000B = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (10000000000000000000000E); runOnlyForDeploymentPostprocessing = 0; };
  10000000000000000000000C = {isa = XCBuildConfiguration; buildSettings = {CODE_SIGNING_ALLOWED = NO; GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = invalid.example.ProbeConsumer; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = "1,2"; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; }; name = Release; };
  10000000000000000000000D = {isa = PBXBuildFile; fileRef = 100000000000000000000007; };
  10000000000000000000000E = {isa = PBXBuildFile; productRef = 100000000000000000000011; };
  100000000000000000000010 = {isa = XCRemoteSwiftPackageReference; repositoryURL = "https://github.com/comsy-devex-lab/spm-probe-public.git"; requirement = {kind = exactVersion; version = 0.1.0; }; };
  100000000000000000000011 = {isa = XCSwiftPackageProductDependency; package = 100000000000000000000010; productName = ProbePackage; };
 };
 rootObject = 100000000000000000000001;
}
EOF
# System Git obeys the empty helper/header/cookie settings. Xcode's package
# authorization uses only the empty netrc in this isolated home, never Keychain.
xcodebuild -project "$ROOT/IOSConsumer/ProbeConsumer.xcodeproj" \
  -scheme ProbeConsumer -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$ROOT/DerivedData" \
  -clonedSourcePackagesDirPath "$ROOT/ios-packages" \
  -packageCachePath "$ROOT/ios-cache" \
  -scmProvider system -packageAuthorizationProvider netrc \
  CODE_SIGNING_ALLOWED=NO build
printf '\nPASS: anonymous remote Git exact 0.1.0 + remote ZIP, macOS import/link/run=42, unsigned iOS simulator build.\n'
printf 'NOT TESTED: simulator execution, physical device deployment, product repositories, production promotion workflow.\n'
CLEAN
printf 'Consumer outputs: %s\n' "$ROOT"
