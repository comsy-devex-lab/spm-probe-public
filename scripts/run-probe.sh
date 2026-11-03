#!/bin/bash
set -euo pipefail

# A self-contained fixture. No product source, certificate, App token or secret.
ROOT="$(cd "$(dirname "$0")" && pwd)/work"
if [[ -e "$ROOT" ]]; then
  echo "Refusing to overwrite existing probe output: $ROOT" >&2
  exit 1
fi
DEVELOPER_DIR="$(xcode-select -p)"
export DEVELOPER_DIR
if [[ "$DEVELOPER_DIR" != /Applications/Xcode*.app/Contents/Developer ]]; then
  echo "Full Xcode under /Applications is required; selected: $DEVELOPER_DIR" >&2
  exit 1
fi
xcodebuild -version
mkdir -p "$ROOT/source" "$ROOT/ProbePackage" "$ROOT/Consumer/Sources/ProbeConsumer"
cat > "$ROOT/source/probe.h" <<'EOF'
#ifndef PROBE_H
#define PROBE_H
int probe_value(void);
#endif
EOF
cat > "$ROOT/source/probe.c" <<'EOF'
#include "probe.h"
int probe_value(void) { return 42; }
EOF
cat > "$ROOT/source/module.modulemap" <<'EOF'
module ProbeBinary { header "probe.h" export * }
EOF

# Build two macOS architectures, one device architecture, two simulator
# architectures. These are unsigned static libraries, never a device deployment.
build_arch() {
  local sdk="$1" arch="$2" target="$3" out="$ROOT/$1-$2"
  mkdir -p "$out"
  xcrun --sdk "$sdk" clang -target "$target" \
    -isysroot "$(xcrun --sdk "$sdk" --show-sdk-path)" \
    -c "$ROOT/source/probe.c" -o "$out/probe.o"
  xcrun libtool -static -o "$out/libProbeBinary.a" "$out/probe.o"
}
build_arch macosx arm64 arm64-apple-macosx12.0
build_arch macosx x86_64 x86_64-apple-macosx12.0
build_arch iphoneos arm64 arm64-apple-ios15.0
build_arch iphonesimulator arm64 arm64-apple-ios15.0-simulator
build_arch iphonesimulator x86_64 x86_64-apple-ios15.0-simulator
mkdir -p "$ROOT/macos-universal" "$ROOT/simulator-universal"
xcrun lipo -create "$ROOT/macosx-arm64/libProbeBinary.a" \
  "$ROOT/macosx-x86_64/libProbeBinary.a" -output "$ROOT/macos-universal/libProbeBinary.a"
xcrun lipo -create "$ROOT/iphonesimulator-arm64/libProbeBinary.a" \
  "$ROOT/iphonesimulator-x86_64/libProbeBinary.a" -output "$ROOT/simulator-universal/libProbeBinary.a"
xcodebuild -create-xcframework \
  -library "$ROOT/macos-universal/libProbeBinary.a" -headers "$ROOT/source" \
  -library "$ROOT/iphoneos-arm64/libProbeBinary.a" -headers "$ROOT/source" \
  -library "$ROOT/simulator-universal/libProbeBinary.a" -headers "$ROOT/source" \
  -output "$ROOT/ProbePackage/ProbeBinary.xcframework"
cat > "$ROOT/ProbePackage/Package.swift" <<'EOF'
// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "ProbePackage",
    platforms: [.macOS(.v12), .iOS(.v15)],
    products: [.library(name: "ProbePackage", targets: ["ProbeBinary"])],
    targets: [.binaryTarget(name: "ProbeBinary", path: "ProbeBinary.xcframework")]
)
EOF
cat > "$ROOT/Consumer/Package.swift" <<'EOF'
// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "ProbeConsumer",
    platforms: [.macOS(.v12)],
    dependencies: [.package(path: "../ProbePackage")],
    targets: [.executableTarget(name: "ProbeConsumer", dependencies: [
        .product(name: "ProbePackage", package: "ProbePackage")
    ])]
)
EOF
cat > "$ROOT/Consumer/Sources/ProbeConsumer/main.swift" <<'EOF'
import ProbeBinary
precondition(probe_value() == 42)
print("probe_value=42")
EOF
# This executes a linked macOS consumer through SwiftPM's local binary target.
(cd "$ROOT/Consumer" && swift run ProbeConsumer)

# An iOS application imports and links the same local Swift package through Xcode.
# Build only: no simulator boot, install, execution, signing or device deployment.
mkdir -p "$ROOT/IOSConsumer/ProbeConsumer.xcodeproj"
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
  100000000000000000000010 = {isa = XCLocalSwiftPackageReference; relativePath = ../ProbePackage; };
  100000000000000000000011 = {isa = XCSwiftPackageProductDependency; package = 100000000000000000000010; productName = ProbePackage; };
 };
 rootObject = 100000000000000000000001;
}
EOF
xcodebuild -project "$ROOT/IOSConsumer/ProbeConsumer.xcodeproj" \
  -scheme ProbeConsumer -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$ROOT/DerivedData" \
  CODE_SIGNING_ALLOWED=NO build
printf '\nPASS: macOS local SwiftPM execution; unsigned iOS simulator consumer build.\n'
printf 'NOT TESTED: remote ZIP/checksum, anonymous public install, Private Source to Official promotion, device deployment.\n'

# Build the archive once; later transfer tests must preserve these exact bytes.
ditto -c -k --keepParent "$ROOT/ProbePackage/ProbeBinary.xcframework" "$ROOT/ProbeBinary.xcframework.zip"
(cd "$ROOT" && swift package compute-checksum ProbeBinary.xcframework.zip > ProbeBinary.sha256)
python3 - "$ROOT" <<'CHECKSUM'
from pathlib import Path
import hashlib,sys
p=Path(sys.argv[1])
assert hashlib.sha256((p/'ProbeBinary.xcframework.zip').read_bytes()).hexdigest()==(p/'ProbeBinary.sha256').read_text().strip()
print('PASS: Swift package checksum equals SHA-256 of the exact archive')
CHECKSUM
