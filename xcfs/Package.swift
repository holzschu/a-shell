// swift-tools-version:5.3
import PackageDescription

_ = Package(
    name: "xcfs",
    platforms: [.macOS("11")],
    dependencies: [
        .package(url: "https://github.com/yury/FMake", from: "0.0.16")
    ],
    
    targets: [
        // ssh_cmd, curl_ios
        .binaryTarget(
            name: "libssh2",
            url: "https://github.com/yury/libssh2-apple/releases/download/v1.9.0/libssh2-dynamic.xcframework.zip",
            checksum: "07952e484eb511b1badb110c15d4621bb84ef98b28ea4d6e1d3a067d420806f5"
        ),
        .binaryTarget(
            name: "openssl",
            url: "https://github.com/yury/openssl-apple/releases/download/v1.1.1i/openssl-dynamic.xcframework.zip",
            checksum: "d07917d2db5480add458a7373bb469b2e46e9aba27ab0ebd3ddc8654df58e60f"
        ),
        // ios_system:
        .binaryTarget(
            name: "ios_system",
            url: "https://github.com/holzschu/ios_system/releases/download/v2.7.0/ios_system.xcframework.zip",
            checksum: "e98c075c088f916649426720afa50df03904aa36d321fe072c9bd6ccbc12806c"
        ),
        .binaryTarget(
            name: "awk",
            url: "https://github.com/holzschu/ios_system/releases/download/v2.7.0/awk.xcframework.zip",
            checksum: "663554d7fca4fcdc670ab91c2f10c175bd10ca8dca3977fbeb6ee8dcd9571e05"
        ),
        .binaryTarget(
            name: "curl_ios",
            url: "https://github.com/holzschu/ios_system/releases/download/v2.7.0/curl_ios.xcframework.zip",
            checksum: "bd1b1f430693c3dc3c0e03bccea810391e5d0d348fbd3ca2d31ff56b5026d1bb"
        ),
        .binaryTarget(
            name: "files",
            url: "https://github.com/holzschu/ios_system/releases/download/v2.7.0/files.xcframework.zip",
            checksum: "c1fbd93d35d3659d3f600400f079bfd3b29f9f869be6d1c418e3ac0e7ad8e56a"
        ),
        .binaryTarget(
            name: "shell",
            url: "https://github.com/holzschu/ios_system/releases/download/v2.7.0/shell.xcframework.zip",
            checksum: "726bafd246106424b807631ac81cc99aed42f8d503127a03ea6d034c58c7e020"
        ),
        .binaryTarget(
            name: "ssh_cmd",
            url: "https://github.com/holzschu/ios_system/releases/download/v2.7.0/ssh_cmd.xcframework.zip",
            checksum: "8c769ad16bdab29617f59a5ae4514356be5296595ec5daf4300440a1dc7b3bf7"
        ),
        .binaryTarget(
            name: "tar",
            url: "https://github.com/holzschu/ios_system/releases/download/v2.7.0/tar.xcframework.zip",
            checksum: "25b817baab9229952c47babc2a885313070a0db1463d7cd43d740164bd1f951b"
        ),
        .binaryTarget(
            name: "text",
            url: "https://github.com/holzschu/ios_system/releases/download/v2.7.0/text.xcframework.zip",
            checksum: "54acd52b21ae9cfa85e3c54d743009593dd78bf6b53387185fd81cf95d8ddf05"
        ),
        .binaryTarget(
            name: "mandoc",
            url: "https://github.com/holzschu/ios_system/releases/download/2.7/mandoc.xcframework.zip",
            checksum: "428eadde2515ad58ede9943a54e0bd56f8cd2980cf89a7b1762c7f36594737f5"
        ),
        // network_ios
        .binaryTarget(
            name: "network_ios",
            url: "https://github.com/holzschu/network_ios/releases/download/v0.2/network_ios.xcframework.zip",
            checksum: "89a465b32e8aed3fcbab0691d8cb9abeecc54ec6f872181dad97bb105b72430a"
        ),
        .target(
            name: "build",
            dependencies: ["FMake"]
        ), 
    ]
)
