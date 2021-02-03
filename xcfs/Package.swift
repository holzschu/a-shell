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
        // bc:
        .binaryTarget(
            name: "bc_ios",
            url: "https://github.com/holzschu/bc/releases/download/v1.0/bc_ios.xcframework.zip",
            checksum: "e3d72c562f726614e273efb06f6e63ccd23f9e38b14c468cf9febd4302df5fdd"
        ),
        // lua:
        .binaryTarget(
            name: "lua_ios",
            url: "https://github.com/holzschu/lua_ios/releases/download/1.0/lua_ios.xcframework.zip",
            checksum: "117eeae75290a59259b12d04bda1fe9a2c6683b54f54ef5141f9afd720adc3e2"
        ),
        // ImageMagick:
        .binaryTarget(
            name: "magick",
            url: "https://github.com/holzschu/ImageMagick/releases/download/1.0/magick.xcframework.zip",
            checksum: "15366ec4c270a21008cffcfefed6862619dcee193112fa634213ae5ce4437aba"
        ),
        // taskwarrior:
        .binaryTarget(
            name: "task",
            url: "https://github.com/holzschu/taskwarrior/releases/download/1.0/task.xcframework.zip",
            checksum: "3fcc3b3fdd9e9247f9b08c1140343e790d38070e02a0a79edff43eb148abf043"
        ),
        .binaryTarget(
            name: "lex",
            url: "https://github.com/holzschu/taskwarrior/releases/download/1.0/lex.xcframework.zip",
            checksum: "d4a8e9d7519e4120ea12c18b50f652f3c8188d21c6cc066adf716869c159ad8b"
        ),
        .binaryTarget(
            name: "calc",
            url: "https://github.com/holzschu/taskwarrior/releases/download/1.0/calc.xcframework.zip",
            checksum: "1fba531bbea928b983e3d72d786bf6ca0a6ca5de043357738a3fb0a4ce1233e9"
        ),
        // Vim:
        .binaryTarget(
            name: "vim",
            url: "https://github.com/holzschu/vim/releases/download/ios_1.0/vim.xcframework.zip",
            checksum: "be178d89820a7541b1a85d7eee6a3b7f730af24a25a8ff343355dfc2d461d782"
        ),
        // LLVM:
        .binaryTarget(
            name: "ar",
            url: "https://github.com/holzschu/llvm/releases/download/1.0/ar.xcframework.zip",
            checksum: "fd8f050c823c997abe12f28a2da64c8de0b5f7730c18e9daffc078753bf7718d"
        ),
        .binaryTarget(
            name: "lld",
            url: "https://github.com/holzschu/llvm/releases/download/1.0/lld.xcframework.zip",
            checksum: "c510fba90f82a6f7978b66be2090c07344c32807afe207830aee19badaddee66"
        ),
        .binaryTarget(
            name: "llc",
            url: "https://github.com/holzschu/llvm/releases/download/1.0/llc.xcframework.zip",
            checksum: "216620beb3df69c61e680e3394786afce367fae666641fdcdbc05b7420338988"
        ),
        .binaryTarget(
            name: "clang",
            url: "https://github.com/holzschu/llvm/releases/download/1.0/clang.xcframework.zip",
            checksum: "586a8346012c7b300ebbae56506e54f4fa73b3338e4e7689f59cd4ebc3a03bd4"
        ),
        .binaryTarget(
            name: "dis",
            url: "https://github.com/holzschu/llvm/releases/download/1.0/dis.xcframework.zip",
            checksum: "30f2cd4c5fa8c9fcb6a9d7e2765ea90c2aa2704027e6fd8f841e175c6c7c6e23"
        ),
        .binaryTarget(
            name: "libLLVM",
            url: "https://github.com/holzschu/llvm/releases/download/1.0/libLLVM.xcframework.zip",
            checksum: "04cd566981a9fba315f9c9cddf62cdbba26e440b8891619181ee1fcf16596315"
        ),
        .binaryTarget(
            name: "link",
            url: "https://github.com/holzschu/llvm/releases/download/1.0/link.xcframework.zip",
            checksum: "2d68bda344dbd57048e5c54d09a75a951010803f1037961fbd2d568254b55200"
        ),
        .binaryTarget(
            name: "lli",
            url: "https://github.com/holzschu/llvm/releases/download/1.0/lli.xcframework.zip",
            checksum: "0d53a1bc83b23ddc94ea4a56e7a4af928157b5310b7a0c0a6322c6f4e1c80dd9"
        ),
        .binaryTarget(
            name: "nm",
            url: "https://github.com/holzschu/llvm/releases/download/1.0/nm.xcframework.zip",
            checksum: "6f3badd6a407e3dc823a142d429a66cc37a75da32d456fe50ab3f3e6f7b84ff4"
        ),
        .binaryTarget(
            name: "opt",
            url: "https://github.com/holzschu/llvm/releases/download/1.0/opt.xcframework.zip",
            checksum: "910b87ba09daab59ad078d042467c3c71a9bf8bdedd2caca0d1400f3c99f8e90"
        ),
        // texlive: 
        .binaryTarget(
            name: "texlua53",
            url: "https://github.com/holzschu/lib-tex/releases/download/1.0/texlua53.xcframework.zip",
            checksum: "d22becd28e56c4653004605cbd4b726a4f86fd78588c1113e6c86498d9a935f3"
        ),
        .binaryTarget(
            name: "kpathsea",
            url: "https://github.com/holzschu/lib-tex/releases/download/1.0/kpathsea.xcframework.zip",
            checksum: "a5074f20ad8500e324655692e35c35872b3429b557e58a1c311f0098857522d7"
        ),
        .binaryTarget(
            name: "luatex",
            url: "https://github.com/holzschu/lib-tex/releases/download/1.0/luatex.xcframework.zip",
            checksum: "d2698c3b9b1390771d9b5eca17a5254d9ac68155208673eccb96e07f65bf1e91"
        ),
        .binaryTarget(
            name: "pdftex",
            url: "https://github.com/holzschu/lib-tex/releases/download/1.0/pdftex.xcframework.zip",
            checksum: "546b2cc2be8ea55928f59e372749e1927ef91e277538847f4f873437cca5a8ec"
        ),
        .binaryTarget(
            name: "bibtex",
            url: "https://github.com/holzschu/lib-tex/releases/download/1.0/bibtex.xcframework.zip",
            checksum: "aaf5273926947edb18fc32d7d8fc93badc4fa1bafd35533f390b9e8dca728076"
        ),        
        //
        .target(
            name: "build",
            dependencies: ["FMake"]
        ), 
    ]
)
