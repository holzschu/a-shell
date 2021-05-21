// swift-tools-version:5.3
import PackageDescription

_ = Package(
    name: "xcfs",
    platforms: [.macOS("11")],
    dependencies: [
        .package(url: "https://github.com/yury/FMake", from: "0.0.16")
    ],
    
    targets: [
        // libssh2
        .binaryTarget(
            name: "libssh2",
            url: "https://github.com/blinksh/libssh2-apple/releases/download/v1.9.0/libssh2-dynamic.xcframework.zip",
            checksum: "a4b5d09cd799b32a019148168983499e8501d93c2a458a9cc547b03028d96040"
        ),
        .binaryTarget(
            name: "openssl",
            url: "https://github.com/blinksh/openssl-apple/releases/download/v1.1.1i/openssl-dynamic.xcframework.zip",
            checksum: "7f7e7cf7a1717dde6fdc71ef62c24e782f3c0ca1a2621e9376699362da990993"
        ),
        // ios_system:
        .binaryTarget(
            name: "ios_system",
            url: "https://github.com/holzschu/ios_system/releases/download/v2.8.0/ios_system.xcframework.zip",
            checksum: "4f8ff7fba7a053d8cbd79abb505c2c71c0c9756d5eea64e845dee6f0946ea032"
        ),
        .binaryTarget(
            name: "awk",
            url: "https://github.com/holzschu/ios_system/releases/download/v2.8.0/awk.xcframework.zip",
            checksum: "cea938659311902471d64e5345294780d364f20f983ae701ddd52870afb0bceb"
        ),
        .binaryTarget(
            name: "curl_ios",
            url: "https://github.com/holzschu/ios_system/releases/download/v2.8.0/curl_ios.xcframework.zip",
            checksum: "d21c43012a1966109f05a1f0c45bbcd74102204d9025ee243f4c0b31ae3651a7"
        ),
        .binaryTarget(
            name: "files",
            url: "https://github.com/holzschu/ios_system/releases/download/v2.8.0/files.xcframework.zip",
            checksum: "2c6a028702519e823481310676407c6525f652db7e9bfdb84680bfc89263e0c8"
        ),
        .binaryTarget(
            name: "shell",
            url: "https://github.com/holzschu/ios_system/releases/download/v2.8.0/shell.xcframework.zip",
            checksum: "9af7f9d87e1bc1e26ff7c076959ee08a2d6b6584b56bbf772bcdbe43563bdb10"
        ),
        .binaryTarget(
            name: "ssh_cmd",
            url: "https://github.com/holzschu/ios_system/releases/download/v2.8.0/ssh_cmd.xcframework.zip",
            checksum: "a3f19cd39b4ecb8e4f0983c4cbd78febc52a05e547ea4bdc85ddf74c2789b3ee"
        ),
        .binaryTarget(
            name: "tar",
            url: "https://github.com/holzschu/ios_system/releases/download/v2.8.0/tar.xcframework.zip",
            checksum: "13a188649adcb25ca483dcc35b4fd91538ba9629dd15e845cf7bac28f84d7526"
        ),
        .binaryTarget(
            name: "text",
            url: "https://github.com/holzschu/ios_system/releases/download/v2.8.0/text.xcframework.zip",
            checksum: "c56d164d7c0fd37d88f265fbd2aca47cd21dc42db536af33a1a469660794ad98"
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
            checksum: "18e96112ae86ec39390487d850e7732d88e446f9f233b2792d633933d4606d46"
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
            checksum: "ac6589d1e90ed5eb2a969d50a618f9c92da2a74305ef9f6caa2d8b4d36837b70"
        ),
        .binaryTarget(
            name: "lex",
            url: "https://github.com/holzschu/taskwarrior/releases/download/1.0/lex.xcframework.zip",
            checksum: "08916648891bd2070e61c0c202dcd6eed1840981ffd6dc38ffd940b03e31939b"
        ),
        .binaryTarget(
            name: "calc",
            url: "https://github.com/holzschu/taskwarrior/releases/download/1.0/calc.xcframework.zip",
            checksum: "4732b1eaad5f9060faaea73b33e43fb5d59af884b3eff678df27e2abb9b98cf0"
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
            url: "https://github.com/holzschu/llvm-project/releases/download/13.0.0/ar.xcframework.zip",
            checksum: "b64e6430fafa6353734229cf3f36efac3b3bb00cfa271ba83b95992a479f3704"
        ),
        .binaryTarget(
            name: "lld",
            url: "https://github.com/holzschu/llvm-project/releases/download/13.0.0/lld.xcframework.zip",
            checksum: "f49af64fcef79629277473d159db802f4772cc0fce4b76a30d77fc7177e572d1"
        ),
        .binaryTarget(
            name: "llc",
            url: "https://github.com/holzschu/llvm-project/releases/download/13.0.0/llc.xcframework.zip",
            checksum: "93952531fb43d799b0a0ffb6cc9cc351e71245edb133ee2e0ed4592df7b3f0c9"
        ),
        .binaryTarget(
            name: "clang",
            url: "https://github.com/holzschu/llvm-project/releases/download/13.0.0/clang.xcframework.zip",
            checksum: "d0f45645bca98f49a3acd926a34b80a9403586fde28ffbba5b766980d24776a8"
        ),
        .binaryTarget(
            name: "dis",
            url: "https://github.com/holzschu/llvm-project/releases/download/13.0.0/dis.xcframework.zip",
            checksum: "fc8c0aca29e0a8653aea5343b6585e94b3d550a40b35477d18549a0434df1b3a"
        ),
        .binaryTarget(
            name: "libLLVM",
            url: "https://github.com/holzschu/llvm-project/releases/download/13.0.0/libLLVM.xcframework.zip",
            checksum: "2e5f05afd237b79ed264759b602c31af0907cab5bc45af2851d971358f412d4f"
        ),
        .binaryTarget(
            name: "link",
            url: "https://github.com/holzschu/llvm-project/releases/download/13.0.0/link.xcframework.zip",
            checksum: "e4b3531bd3ca702ddf5c1f652da8c83b956ab6d8b19107de0972b4da3151e781"
        ),
        .binaryTarget(
            name: "lli",
            url: "https://github.com/holzschu/llvm-project/releases/download/13.0.0/lli.xcframework.zip",
            checksum: "469fa5fae7dc51c5195661505c5a32f3023a2136ed3057c79baae27b19eff220"
        ),
        .binaryTarget(
            name: "nm",
            url: "https://github.com/holzschu/llvm-project/releases/download/13.0.0/nm.xcframework.zip",
            checksum: "ddb50953b2b6b2e9331a992b7f861ad0f2581788b2520b526ec4c8ca86bada3b"
        ),
        .binaryTarget(
            name: "opt",
            url: "https://github.com/holzschu/llvm-project/releases/download/13.0.0/opt.xcframework.zip",
            checksum: "13c5748e2f5280879b7c28711c99648d850b75147c961e5031e0dabb8efd8cb9"
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
