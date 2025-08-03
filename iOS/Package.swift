// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CiteTrack-iOS",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "CiteTrackShared",
            targets: ["CiteTrackShared"]
        ),
        .executable(
            name: "CiteTrack-iOS",
            targets: ["CiteTrack-iOS"]
        )
    ],
    dependencies: [
        // Swift Charts for iOS 16+
        .package(url: "https://github.com/apple/swift-charts.git", from: "1.0.0"),
        
        // Combine utilities
        .package(url: "https://github.com/CombineCommunity/CombineExt.git", from: "1.8.0"),
        
        // Additional networking support
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0")
    ],
    targets: [
        // Shared code target
        .target(
            name: "CiteTrackShared",
            dependencies: [
                "CombineExt",
                "Alamofire"
            ],
            path: "../Shared",
            sources: [
                "Models",
                "Services", 
                "Managers",
                "Utilities"
            ]
        ),
        
        // iOS app target
        .executableTarget(
            name: "CiteTrack-iOS",
            dependencies: [
                "CiteTrackShared",
                .product(name: "Charts", package: "swift-charts"),
                "CombineExt"
            ],
            path: "CiteTrack-iOS",
            sources: [
                "App",
                "Views",
                "ViewModels"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        
        // Test targets
        .testTarget(
            name: "CiteTrackSharedTests",
            dependencies: ["CiteTrackShared"],
            path: "Tests/CiteTrackSharedTests"
        ),
        
        .testTarget(
            name: "CiteTrack-iOSTests", 
            dependencies: ["CiteTrack-iOS"],
            path: "Tests/CiteTrack-iOSTests"
        )
    ]
)