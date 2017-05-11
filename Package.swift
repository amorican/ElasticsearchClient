// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "ElasticsearchClient",
    dependencies: [
        .Package(url: "https://github.com/amorican/CommonCrypto.git", versions: Version(0,3,0) ..< Version(1,0,0)),
        .Package(url: "https://github.com/amorican/Gloss.git", majorVersion: 1, minor: 2),
        .Package(url: "https://github.com/amorican/SimpleStateMachine.git", majorVersion: 1)
    ]
)
