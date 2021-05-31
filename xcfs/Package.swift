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
            url: "https://github.com/blinksh/openssl-apple/releases/download/v1.1.1k/openssl-dynamic.xcframework.zip",
            checksum: "9a7cc2686122e62445b85a8ce04f49379d99c952b8ea3534127c004b8a00af59"
        ),
        // ios_system:
        .binaryTarget(
            name: "ios_system",
            url: "https://github.com/holzschu/ios_system/releases/download/v2.9.0/ios_system.xcframework.zip",
            checksum: "6a41de307993536beca9b9c1b126085f80921ab8722ad890a8d54f1e8f6079ae"
        ),
        .binaryTarget(
            name: "awk",
            url: "https://github.com/holzschu/ios_system/releases/download/v2.9.0/awk.xcframework.zip",
            checksum: "d4063a5c4a1eeac56f9ff9167e0a9e754f35fc8217476970700b9cf200e5c715"
        ),
        .binaryTarget(
            name: "curl_ios",
            url: "https://github.com/holzschu/ios_system/releases/download/v2.9.0/curl_ios.xcframework.zip",
            checksum: "40f4d113484d3d935320044940ab9791369fa839f4605056c309087fa99ff89f"
        ),
        .binaryTarget(
            name: "files",
            url: "https://github.com/holzschu/ios_system/releases/download/v2.9.0/files.xcframework.zip",
            checksum: "0447973bcb65f88cc84f66bb9f540fb8462b50a94c80fd634d4da19ff793e119"
        ),
        .binaryTarget(
            name: "shell",
            url: "https://github.com/holzschu/ios_system/releases/download/v2.9.0/shell.xcframework.zip",
            checksum: "aa22db5bb759ecfca021edfebad7442dea0c2bc09abfdb311c059985e4ea3391"
        ),
        .binaryTarget(
            name: "ssh_cmd",
            url: "https://github.com/holzschu/ios_system/releases/download/v2.9.0/ssh_cmd.xcframework.zip",
            checksum: "8483ce068ed6751343583ed29daed90d70d17dd595d3f46967ef8226dd784dfb"
        ),
        .binaryTarget(
            name: "tar",
            url: "https://github.com/holzschu/ios_system/releases/download/v2.9.0/tar.xcframework.zip",
            checksum: "dd60d2d4f63f666f7a3391410714f2a6f61457ace2cbf8de7ee070f20854eddc"
        ),
        .binaryTarget(
            name: "text",
            url: "https://github.com/holzschu/ios_system/releases/download/v2.9.0/text.xcframework.zip",
            checksum: "2053a9d30c07968b0b10c51c5235feac006c1799828876e7a04436bfe5b40625"
        ),
        .binaryTarget(
            name: "mandoc",
            url: "https://github.com/holzschu/ios_system/releases/download/2.7/mandoc.xcframework.zip",
            checksum: "02b952191ec311fe04df0001e85e8812f68473b6616eaed4a03c045aed111a43"
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
            checksum: "b490cce70155afa85cb7477f248b625f3da3359a47d29aa67d5ada849588f9df"
        ),
        .binaryTarget(
            name: "xxd",
            url: "https://github.com/holzschu/vim/releases/download/ios_1.0/xxd.xcframework.zip",
            checksum: "51564908abd1e19678d24e424ed32bb4e39dd8e177e5d27a8b851402ea15937b"
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
        // Perl and make (single-architecture xcframeworks... for now)
        .binaryTarget(
            name: "perl",
            url: "https://github.com/holzschu/ios_system/releases/download/2.7/perl.xcframework.zip",
            checksum: "7f470ea838139a4aaa4dee8f3f0505c3a5d8769a54fcda9336b5d60b60abec62"
        ),
        .binaryTarget(
            name: "perlA",
            url: "https://github.com/holzschu/ios_system/releases/download/2.7/perlA.xcframework.zip",
            checksum: "8015a11ab6fa15aeb16c417b229d10b28e28e756c533b7f3faf3b6029b83dc49"
        ),
        .binaryTarget(
            name: "perlB",
            url: "https://github.com/holzschu/ios_system/releases/download/2.7/perlB.xcframework.zip",
            checksum: "fd2ca9fb3853aba1d6744c03db6cc88783d170ed0c119bd97e8ebe6fa3ec30b3"
        ),
        .binaryTarget(
            name: "make",
            url: "https://github.com/holzschu/ios_system/releases/download/2.7/make.xcframework.zip",
            checksum: "942a05e1cd165c4fb955b274e08a1069e388ae6706770e617e47ce55927b2b2f"
        )
    ]
)
