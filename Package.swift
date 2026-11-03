// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "ProbePackage",
    platforms: [.macOS(.v12), .iOS(.v15)],
    products: [.library(name: "ProbePackage", targets: ["ProbeBinary"])],
    targets: [.binaryTarget(name: "ProbeBinary",
        url: "https://github.com/comsy-devex-lab/spm-probe-public/releases/download/v0.1.0/ProbeBinary.xcframework.zip",
        checksum: "a424746d17c5737897745e1c886156660fb58c68d732488d353ac05ef667a54e")]
)
