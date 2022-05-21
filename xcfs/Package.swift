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
            url: "https://github.com/holzschu/ios_system/releases/download/v3.0.1/ios_system.xcframework.zip",
            checksum: "635fc346304416f05f94a61ded08a2a5792f5072081eca7c142834326366d4d0"
        ),
        .binaryTarget(
            name: "awk",
            url: "https://github.com/holzschu/ios_system/releases/download/v3.0.1/awk.xcframework.zip",
            checksum: "d8fc59849698f9b0b43b5fa77d7d38410ec95482965e3a11afe03e6bebd06b88"
        ),
        .binaryTarget(
            name: "curl_ios",
            url: "https://github.com/holzschu/ios_system/releases/download/v3.0.1/curl_ios.xcframework.zip",
            checksum: "c07f2fca448a1cc23ba98bd979962a44587b4017508e101e1f7dcb4d0ca27b60"
        ),
        .binaryTarget(
            name: "files",
            url: "https://github.com/holzschu/ios_system/releases/download/v3.0.1/files.xcframework.zip",
            checksum: "c24641cf21f710d6db0832399e261c01b3504caf86ff6d13dcf0dcbaa1dd1172"
        ),
        .binaryTarget(
            name: "shell",
            url: "https://github.com/holzschu/ios_system/releases/download/v3.0.1/shell.xcframework.zip",
            checksum: "cbd1a7675990777cef0d19c85295915f9d5af4430d1c7c631322d6e19495b148"
        ),
        .binaryTarget(
            name: "ssh_cmd",
            url: "https://github.com/holzschu/ios_system/releases/download/v3.0.1/ssh_cmd.xcframework.zip",
            checksum: "67174120060604888ee15c7b5f71686b671d80224f1cd9576f8d24381ed96759"
        ),
        .binaryTarget(
            name: "tar",
            url: "https://github.com/holzschu/ios_system/releases/download/v3.0.1/tar.xcframework.zip",
            checksum: "e5e1ca866576d291a75b9f8ae18cdf215a6b70efde3144e7a0905488b0d42dc5"
        ),
        .binaryTarget(
            name: "text",
            url: "https://github.com/holzschu/ios_system/releases/download/v3.0.1/text.xcframework.zip",
            checksum: "c832c4e6b234c297526f2e16cfbf197da5be332dc69a3bdf452e135f8c33a77c"
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
            checksum: "0ccdab671f31c20daf8833452cc36598b49f84441851d7142b305443425bc527"
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
            checksum: "0a1d915355b7f7301cfabffb8bb543355ace8377a174d73065f488816d464c93"
        ),
        .binaryTarget(
            name: "xxd",
            url: "https://github.com/holzschu/vim/releases/download/ios_1.0/xxd.xcframework.zip",
            checksum: "e4497125969914be5dd7fc8012b71646dbc7a5b3f50f50d8254682a8a369dd5b"
        ),
        // LLVM:
        .binaryTarget(
            name: "ar",
            url: "https://github.com/holzschu/llvm-project/releases/download/14.0.0/ar.xcframework.zip",
            checksum: "69727d7f851ad5b0a77732e7cff70112a0cf8ec12d8e8fc869f6470a1880c1c5"
        ),
        .binaryTarget(
            name: "lld",
            url: "https://github.com/holzschu/llvm-project/releases/download/14.0.0/lld.xcframework.zip",
            checksum: "240c1cd5cfc7557dd859af9b9d20aa9623f935dc92746a8be21edba8dbd11f34"
        ),
        .binaryTarget(
            name: "llc",
            url: "https://github.com/holzschu/llvm-project/releases/download/14.0.0/llc.xcframework.zip",
            checksum: "bfd1cf1e42a5af03716bdd0d3d5404cde7d56f86c52cfebcc69a7ecbd2d5127b"
        ),
        .binaryTarget(
            name: "clang",
            url: "https://github.com/holzschu/llvm-project/releases/download/14.0.0/clang.xcframework.zip",
            checksum: "9de9f72334c99f27d3ac5844b8d3feffcaed3086997e7c2538f887667e8ca179"
        ),
        .binaryTarget(
            name: "dis",
            url: "https://github.com/holzschu/llvm-project/releases/download/14.0.0/dis.xcframework.zip",
            checksum: "6613ee063331e39fdea044cc119511ef61df8eb247e6db2e376240af224623c7"
        ),
        .binaryTarget(
            name: "libLLVM",
            url: "https://github.com/holzschu/llvm-project/releases/download/14.0.0/libLLVM.xcframework.zip",
            checksum: "bbae5b3a7952b2f1e89fb93b25b41931a53b6d8c99d24dfe6a893e615b177428"
        ),
        .binaryTarget(
            name: "link",
            url: "https://github.com/holzschu/llvm-project/releases/download/14.0.0/link.xcframework.zip",
            checksum: "3bf79972c961f418c9964df04dec81794dd6beae88f07702e8b51e074ed2085f"
        ),
        .binaryTarget(
            name: "lli",
            url: "https://github.com/holzschu/llvm-project/releases/download/14.0.0/lli.xcframework.zip",
            checksum: "a7976820f7349daf1c136ae513d506c954502ff10b92a92dbd3538bd625e0719"
        ),
        .binaryTarget(
            name: "nm",
            url: "https://github.com/holzschu/llvm-project/releases/download/14.0.0/nm.xcframework.zip",
            checksum: "3c004f6d5345bde727bb34d2daa252c46a9cf5ee3e053c7a18b2933cf0df16c0"
        ),
        .binaryTarget(
            name: "opt",
            url: "https://github.com/holzschu/llvm-project/releases/download/14.0.0/opt.xcframework.zip",
            checksum: "616d858d3bfd3f2782baedda34ba1fb6c449704faeae0db59e742d27169710ab"
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
        ),
        // TODO: update TeX binaries, update perl/make/man binaries, add dash binary.
        .target(
            name: "build",
            dependencies: ["FMake"]
        ), 
    ]
)
