// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StarCore",
    platforms: [.iOS(.v15)],
    products: [
        .executable(name: "StarCore", targets: ["StarCoreApp"])
    ],
    targets: [
        .executableTarget(
            name: "StarCoreApp",
            path: "StarCore",
            resources: [
                .process("App/Info.plist")
            ]
        )
    ]
)
