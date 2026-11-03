// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "ProbePackage", platforms: [.macOS(.v12), .iOS(.v15)],
    products: [.library(name: "ProbePackage", targets: ["ProbeBinary"])],
    targets: [.binaryTarget(name: "ProbeBinary", path: "ProbeBinary.xcframework")]
)
