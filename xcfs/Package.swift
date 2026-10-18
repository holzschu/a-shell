// swift-tools-version:5.3
import PackageDescription

_ = Package(
    name: "xcfs",
    platforms: [.macOS("11")],
    dependencies: [
        .package(url: "https://github.com/holzschu/FMake", from: "0.0.19")
    ],
    
    targets: [
        // libssh2
        .binaryTarget(
            name: "libssh2",
            url: "https://github.com/holzschu/libssh2-apple/releases/download/v1.11.0/libssh2-dynamic.xcframework.zip",
            checksum: "cacfe1789b197b727119f7e32f561eaf9acc27bf38cd19975b74fce107f868a6"
        ),
        .binaryTarget(
            name: "openssl",
            url: "https://github.com/holzschu/openssl-apple/releases/download/v1.1.1w/openssl-dynamic.xcframework.zip",
            checksum: "329e8317cf9bee8e138da5d032330a7a1bd2473cf44c9c083cb2f0636abb8b80"
        ),
        .binaryTarget(
            name: "ios_system",
            url: "https://github.com/holzschu/ios_system/releases/download/v3.0.5/ios_system.xcframework.zip",
            checksum: "d429e68102926f58bedd8e8b7105dcd169478cd6da1cef494a5f468482d1c8f5"
        ),
        .binaryTarget(
            name: "awk",
            url: "https://github.com/holzschu/ios_system/releases/download/v3.0.5/awk.xcframework.zip",
            checksum: "283f368df6c44ed9d49d15651ca4281706cdd86eb2b6ddb81808c8a3b18a4f7d"
        ),
        .binaryTarget(
            name: "curl_ios",
            url: "https://github.com/holzschu/ios_system/releases/download/v3.0.5/curl_ios.xcframework.zip",
            checksum: "d7e2f05c9f2689d103db32f83ab045bfb6ab28ce84e3017e0c23e4b4db7ab169"
        ),
        .binaryTarget(
            name: "files",
            url: "https://github.com/holzschu/ios_system/releases/download/v3.0.5/files.xcframework.zip",
            checksum: "b0ee1f58c65ba306f178cd559fd6bce79ec8f275280526908c2a992bfcafedd5"
        ),
        .binaryTarget(
            name: "shell",
            url: "https://github.com/holzschu/ios_system/releases/download/v3.0.5/shell.xcframework.zip",
            checksum: "855ff9b12bfbbdbd5298324377d91e18e6ac97dbb19d3c9311ce5a023ee51b2e"
        ),
        .binaryTarget(
            name: "ssh_cmd",
            url: "https://github.com/holzschu/ios_system/releases/download/v3.0.5/ssh_cmd.xcframework.zip",
            checksum: "0943d53cfec57909fbdb121bafa3d1845a82e7accf896e1dd7864aa640a57836"
        ),
        .binaryTarget(
            name: "ssh_cmdA",
            url: "https://github.com/holzschu/ios_system/releases/download/v3.0.5/ssh_cmdA.xcframework.zip",
            checksum: "87ca4a8f3b4729173297b784a696aad96f6d1b9d81a06cda15aa70f0b88839a1"
        ),
        .binaryTarget(
            name: "ssh_agent",
            url: "https://github.com/holzschu/ios_system/releases/download/v3.0.5/ssh_agent.xcframework.zip",
            checksum: "3d0022084855fa3c1e1da3c51437b97e6e5532e9c4133bd4c651ebf5d1017eaa"
        ),
        .binaryTarget(
            name: "sshd",
            url: "https://github.com/holzschu/ios_system/releases/download/v3.0.5/sshd.xcframework.zip",
            checksum: "e682f5c445799a77dd8b133c5d3f51481236a277fba488556a5a5d4f918d681f"
        ),
        .binaryTarget(
            name: "tar",
            url: "https://github.com/holzschu/ios_system/releases/download/v3.0.5/tar.xcframework.zip",
            checksum: "207ab260f8dfb3101938c9e2a949cfd7b76f0e90a000637bbfd6aff47b014a68"
        ),
        .binaryTarget(
            name: "text",
            url: "https://github.com/holzschu/ios_system/releases/download/v3.0.5/text.xcframework.zip",
            checksum: "6fed763c6e941817b2a2af2051871bdfb8a1af4177fad1ab7837f72023dffb79"
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
            checksum: "02acb74bec3e6b4ba9c120873a19a770773e3c3e2d141365808a9342ddf41fe7"
        ),
        .binaryTarget(
            name: "xxd",
            url: "https://github.com/holzschu/vim/releases/download/ios_1.0/xxd.xcframework.zip",
            checksum: "1c48b9f77310b71499a7bd76a16882405c8a81b55f56c7c7577ae2a0ce347ba6"
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
            url: "https://github.com/holzschu/texlive-source/releases/download/texlive-2022/texlua53.xcframework.zip",
            checksum: "99e66932e5025a91496acd1228b6a0d03d19043db7585c2b608d0fc5f9eb5cff"
        ),
        .binaryTarget(
            name: "kpathsea",
            url: "https://github.com/holzschu/texlive-source/releases/download/texlive-2022/kpathsea.xcframework.zip",
            checksum: "2f04e8d8c589eecf3d022a34f71b57292a9271c88d48a7a767c68fdcfc937f23"
        ),
        .binaryTarget(
            name: "makeindex",
            url: "https://github.com/holzschu/texlive-source/releases/download/texlive-2022/makeindex.xcframework.zip",
            checksum: "91b7c0bcaf3f1cd75d550a3115f91d45a7e31e9752b82bc1eb46095aa77687ed"
        ),
        .binaryTarget(
            name: "luatex",
            url: "https://github.com/holzschu/texlive-source/releases/download/texlive-2022/luatex.xcframework.zip",
            checksum: "36beb9e8811a5d51f3a938b9fb057b4b769333cf1069247d19b5e82ed8a8e40a"
        ),
        .binaryTarget(
            name: "luahbtex",
            url: "https://github.com/holzschu/texlive-source/releases/download/texlive-2022/luahbtex.xcframework.zip",
            checksum: "fdda49fa86031e9d13d2e53485f5b3c9874d03c11a8b241598f64c28964a0eba"
        ),
        .binaryTarget(
            name: "pdftex",
            url: "https://github.com/holzschu/texlive-source/releases/download/texlive-2022/pdftex.xcframework.zip",
            checksum: "e98163dbe715f621c1d44e14eb8484ba4e906129c02b6e0cd3e8dcc206775bd7"
        ),
        .binaryTarget(
            name: "bibtex",
            url: "https://github.com/holzschu/texlive-source/releases/download/texlive-2022/bibtex.xcframework.zip",
            checksum: "70b0608f634e3f7cbac88b8623d28e98113d67c8d5052abefd26e92544c59b80"
        ),
        .binaryTarget(
            name: "kpsewhich",
            url: "https://github.com/holzschu/texlive-source/releases/download/texlive-2022/kpsewhich.xcframework.zip",
            checksum: "0908aeb72d34d47ab8f530cf5e822d366b060c2c9a7b7f2d4a799082775373c7"
        ),
        .binaryTarget(
            name: "texlua53A",
            url: "https://github.com/holzschu/texlive-source/releases/download/texlive-2022/texlua53A.xcframework.zip",
            checksum: "5bdcafed346a1bf713dd6a2cc2fefd8ebc70199c5df0a120d02be13ee58f9610"
        ),
        .binaryTarget(
            name: "kpathseaA",
            url: "https://github.com/holzschu/texlive-source/releases/download/texlive-2022/kpathseaA.xcframework.zip",
            checksum: "b304a4080eb3cfc1d90187a74b8327a32c400ba5b466e4fda1051e0d5d55194a"
        ),
        .binaryTarget(
            name: "luatexA",
            url: "https://github.com/holzschu/texlive-source/releases/download/texlive-2022/luatexA.xcframework.zip",
            checksum: "e572cf1ea77ed50f895a7a6f74d6996b46ef614b89435f4a7eaae95983748aac"
        ),
        .binaryTarget(
            name: "luahbtexA",
            url: "https://github.com/holzschu/texlive-source/releases/download/texlive-2022/luahbtexA.xcframework.zip",
            checksum: "71f7f4b17f77fe8ff67be4a3abce40ab8f3f360636d0f73edb5156bcc5e88da6"
        ),
        .binaryTarget(
            name: "pdftexA",
            url: "https://github.com/holzschu/texlive-source/releases/download/texlive-2022/pdftexA.xcframework.zip",
            checksum: "16130dd0486e8fb352be4bc461f382733436576a5ad5c0ecccec847f3db8c506"
        ),
        // freetype and harfbuzz:
        .binaryTarget(
            name: "freetype",
            url: "https://github.com/holzschu/Python-aux/releases/download/1.0/freetype.xcframework.zip",
            checksum: "8fdf22c7911a2ea47c60df723a0ee268bd5606a1153023f338b3e6395149089e"
        ),
        .binaryTarget(
            name: "harfbuzz",
            url: "https://github.com/holzschu/Python-aux/releases/download/1.0/harfbuzz.xcframework.zip",
            checksum: "9a983795826d1662ba354f563b19a7b980e4c744138b3afb68491991e2c8a66a"
        ),
        // Perl and make (single-architecture xcframeworks... for now)
        .binaryTarget(
            name: "perl",
            url: "https://github.com/holzschu/perl5/releases/download/iOS_1.0/perl.xcframework.zip",
            checksum: "98a680b9cd2411e1133a55eaac7f7429b0d3d184a25b9a7b9c4c047dbe0626d4"
        ),
        .binaryTarget(
            name: "perlA",
            url: "https://github.com/holzschu/perl5/releases/download/iOS_1.0/perlA.xcframework.zip",
            checksum: "20a18a5aa496dc54af7a3a11161a1ef2b7bbf3bd037d527673f371f800e72665"
        ),
        .binaryTarget(
            name: "perlB",
            url: "https://github.com/holzschu/perl5/releases/download/iOS_1.0/perlB.xcframework.zip",
            checksum: "593ba4f8f734d669040f9d9be63092e275d5dba72f1b1826c6806f3c4cec7604"
        ),
        .binaryTarget(
            name: "lg2",
            url: "https://github.com/holzschu/libgit2/releases/download/ios_1.0/lg2.xcframework.zip",
            checksum: "7d205a771be8d120a80d2f7281135dfffd21a3713c86eb4f1957638f6b4b365e"
        ),
        // Packages that don't have their own repository: 
        .binaryTarget(
            name: "mandoc",
            url: "https://github.com/holzschu/ios_system/releases/download/Auxiliary/mandoc.xcframework.zip",
            checksum: "86428238cb357ece2da6b813fe493dfcee1f4efc91ec535d73b3e581d9b8e21b"
        ),
        .binaryTarget(
            name: "make",
            url: "https://github.com/holzschu/ios_system/releases/download/Auxiliary/make.xcframework.zip",
            checksum: "6f9dca82bfdee1be8ad0ec1e52870bee6b3e309ac29f0995a6d5a41003c26d4f"
        ),
        .binaryTarget(
            name: "dash",
            url: "https://github.com/holzschu/ios_system/releases/download/Auxiliary/dash.xcframework.zip",
            checksum: "9a30ac6b3780dd68d2268d10467902214e32333e980c59090faa6099f0d250fc"
        ),
        .binaryTarget(
            name: "dashA",
            url: "https://github.com/holzschu/ios_system/releases/download/Auxiliary/dashA.xcframework.zip",
            checksum: "a45eb647bf81caf0fd80dba704326842ce03668c60499488d387dce26cf30ee6"
        ),
        .binaryTarget(
            name: "dashB",
            url: "https://github.com/holzschu/ios_system/releases/download/Auxiliary/dashB.xcframework.zip",
            checksum: "c0de9fdc7c9cc2386012a1dccdbb112cf4b15243699ffcf49c9dbc6d17163bce"
        ),
        .binaryTarget(
            name: "dashC",
            url: "https://github.com/holzschu/ios_system/releases/download/Auxiliary/dashC.xcframework.zip",
            checksum: "553d98fa8c5705754a9cdd2f4d2f5d3cd5d1dc5f765921f5fb0f3422848e09bf"
        ),
        .binaryTarget(
            name: "dashD",
            url: "https://github.com/holzschu/ios_system/releases/download/Auxiliary/dashD.xcframework.zip",
            checksum: "7aa457e359b3bb215fdd56df5b689b826863f2e96d72a87a3046a3116f2dd30c"
        ),
        .binaryTarget(
            name: "dashE",
            url: "https://github.com/holzschu/ios_system/releases/download/Auxiliary/dashE.xcframework.zip",
            checksum: "9f79675fa3c797257931853ca746337a66f8218157d44736d1c14425030aff3e"
        ),
        .binaryTarget(
            name: "unrar",
            url: "https://github.com/holzschu/ios_system/releases/download/Auxiliary/unrar.xcframework.zip",
            checksum: "b1c2318db3b89a668abd66f69036ec9c3c5d474b2d75a0b1ffbaf2ac47b02782"
        ),
        .binaryTarget(
            name: "vimproc",
            url: "https://github.com/holzschu/ios_system/releases/download/Auxiliary/vimproc.xcframework.zip",
            checksum: "400dcf3f4414562a9c62f1541b349be4176bdae9f7fcd95a5c7ed34046586982"
        ),
        .binaryTarget(
            name: "ffmpeg",
            url: "https://github.com/holzschu/ios_system/releases/download/Auxiliary/ffmpeg.xcframework.zip",
            checksum: "627a9392a8d4704e4e04636692e3baeacb7af4f273e61fe676270aa16b1ef371"
        ),
        .binaryTarget(
            name: "ffprobe",
            url: "https://github.com/holzschu/ios_system/releases/download/Auxiliary/ffprobe.xcframework.zip",
            checksum: "c66df5198becb1e0432c27c8f0df628fa185224c9f0bcff2039e3bd21246b130"
        ),
        .binaryTarget(
            name: "jq",
            url: "https://github.com/fprimex/jq/releases/download/ios/jq.xcframework.zip",
            checksum: "d3c4486e5ed788995b0ad9586465d3407e463d90f4e91b843846cabfe21f297f"
        ),
        // TODO: add vimproc binary.
        .target(
            name: "build",
            dependencies: ["FMake"]
        ), 
    ]
)
