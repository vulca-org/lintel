// swift-tools-version: 6.2
import PackageDescription

// LintelCore：活动协议、登记、校验、排序、看过、心跳。只依赖 Foundation，全部可单测。
// LintelUI：刘海舞台、形状、弹簧、胶囊、让位、内容块与面板的画法（从许愿柳 f4d6690 搬来，见 docs/baseline/inventory.md）。
// lintel：宿主程序与命令行（register / validate / 演示）。
let package = Package(
    name: "lintel",
    platforms: [.macOS(.v26)],
    targets: [
        .target(
            name: "LintelCore",
            path: "Sources/LintelCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "LintelUI",
            dependencies: ["LintelCore"],
            path: "Sources/LintelUI",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "lintel",
            dependencies: ["LintelCore", "LintelUI"],
            path: "Sources/lintel",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "LintelCoreTests",
            dependencies: ["LintelCore"],
            path: "Tests/LintelCoreTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "LintelUITests",
            dependencies: ["LintelUI", "LintelCore"],
            path: "Tests/LintelUITests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
