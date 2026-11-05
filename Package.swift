// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Termi",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Termi", targets: ["Termi"])],
    dependencies: [.package(url: "https://github.com/migueldeicaza/SwiftTerm.git", exact: "1.20.0")],
    targets: [
        .executableTarget(name: "Termi", dependencies: ["SwiftTerm"], resources: [.copy("Resources")]),
        .testTarget(name: "TermiTests", dependencies: ["Termi"])
    ]
)
