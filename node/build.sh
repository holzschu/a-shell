#!/usr/bin/env bash
# Build pinned upstream Node archives and package the native a-Shell command.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
app=$(cd "$here/.." && pwd)
rev=v26.12.1
sha=717244a8d757672ec86aae5077fca31e50f84b094441ec51bdf397aab12c304e
cache=${NODE_IOS_CACHE:-$HOME/.cache/a-shell-node/$rev}
source=$cache/source
stage=${1:-node}
ios_system=${IOS_SYSTEM_XCFRAMEWORK:-$app/xcfs/.build/artifacts/xcfs/ios_system/ios_system.xcframework}
jobs=${NODE_IOS_JOBS:-4}
libraries="ada brotli cares crdtp icui18n icuucx icudata icustubdata histogram llhttp nbytes ncrypto ncrypto_engine nghttp2 sfparse merve node node_base openssl simdjson simdutf sqlite uv uvwasi ffi highway v8_base_without_compiler v8_compiler v8_initializers v8_libbase v8_libplatform v8_snapshot v8_zlib v8_init abseil zlib zlib_data_chunk_simd zlib_adler32_simd zstd"
die() {
  echo "$*" >&2
  exit 1
}
# Run a long step with its output in a log; on failure show where it stopped.
logged() {
  local log=$1
  shift
  if ! "$@" >"$log" 2>&1; then
    echo "Failed: $* (log: $log)" >&2
    tail -n 30 "$log" >&2
    return 1
  fi
}
# Patch a fresh tree. -N turns an already-applied hunk into an error instead of a skip.
apply_patches() {
  local tree=$1 name
  shift
  for name; do
    if ! patch -s -N -F 0 -p1 -d "$tree" <"$here/$name.patch"; then
      echo "Patch $name.patch does not apply to $tree" >&2
      return 1
    fi
  done
}
check() {
  [[ $(uname -m) == arm64 ]] || die "Apple Silicon is required."
  command -v xcodebuild >/dev/null || die "xcodebuild not found; install Xcode."
  case $stage in
    node | device)
      # Node's configure.py only runs on these Pythons and looks for them in this order.
      local py
      for py in python3.14 python3.13 python3.12 python3.11 python3.10 python3; do
        if command -v "$py" >/dev/null && "$py" -c 'import sys; sys.exit(not (3, 10) <= sys.version_info[:2] <= (3, 14))'; then break; fi
        py=
      done
      [[ -n $py ]] || die "Node 26 needs Python 3.10-3.14 on PATH (for example: brew install python@3.14)."
      ;;
    sdk) [[ -n ${IOS_SYSTEM_SOURCE:-} && -f $IOS_SYSTEM_SOURCE/ios_system.xcodeproj/project.pbxproj ]] || die "Set IOS_SYSTEM_SOURCE to an ios_system source tree." ;;
    package)
      command -v npm >/dev/null
      local platform name
      for platform in simulator device; do
        for name in $libraries; do
          [[ -f $cache/$platform-libs/lib$name.a ]] || {
            echo "Missing $platform archive lib$name.a; complete its native build first (build.sh $([[ $platform == simulator ]] && echo node || echo device); see $cache/make.log)." >&2
            exit 1
          }
        done
      done
      [[ -f $ios_system/ios-arm64/ios_system.framework/Headers/ios_system.h && -f $ios_system/ios-arm64-simulator/ios_system.framework/Headers/ios_system.h ]] || die "IOS_SYSTEM_XCFRAMEWORK $ios_system has no ios_system slices; run build.sh sdk."
      local slice
      for slice in ios-arm64 ios-arm64-simulator; do
        if ! xcrun nm -gU "$ios_system/$slice/ios_system.framework/ios_system" | grep ' T _ashell_register_owned_streams$' >/dev/null; then
          echo 'Build the patched ios_system first: build.sh sdk' >&2
          exit 1
        fi
      done
      ;;
    *)
      echo 'Usage: build.sh sdk|node|device|package [--dry-run]' >&2
      exit 2
      ;;
  esac
}
plan() {
  echo "Stage $stage; pinned Node $rev; cache $cache; package $app/xcfs/node.xcframework"
}
apply() (
  mkdir -p "$cache"
  case $stage in
    sdk)
      local sdk_source=$cache/ios-system-source platform slice
      local sdk_frameworks=()
      local sdk_changed=0
      local sdk_excludes=(--exclude .git --exclude build --exclude tests --exclude docs --exclude .deps)
      # The patched copy is rebuilt from pristine input whenever the input or a patch changed.
      local sdk_stamp
      sdk_stamp=$(
        {
          cat "$here/ios-system-streams.patch" "$here/command-path.patch"
          tar "${sdk_excludes[@]}" -cf - -C "$IOS_SYSTEM_SOURCE" .
        } | shasum -a 256
      )
      if [[ ! -f $sdk_source/.patched || $(<"$sdk_source/.patched") != "$sdk_stamp" ]]; then
        rm -rf "$sdk_source"
        mkdir -p "$sdk_source"
        rsync -a "${sdk_excludes[@]}" "$IOS_SYSTEM_SOURCE/" "$sdk_source/"
        apply_patches "$sdk_source" ios-system-streams command-path || die "Use ios_system revision fb7a9057874290bff2765f82b4ba3ba1d76dadb3 or merge these patches into your tree."
        echo "$sdk_stamp" >"$sdk_source/.patched"
      else
        echo "ios_system source already carries these patches."
      fi
      for platform in iphonesimulator iphoneos; do
        slice=ios-arm64
        [[ $platform != iphonesimulator ]] || slice=ios-arm64-simulator
        logged "$cache/sdk-$platform.log" xcodebuild -project "$sdk_source/ios_system.xcodeproj" -target ios_system -sdk "$platform" \
          -configuration Release -jobs 2 ARCHS=arm64 IPHONEOS_DEPLOYMENT_TARGET=16.0 \
          CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CONFIGURATION_BUILD_DIR="$cache/sdk-$platform" \
          build
        sdk_frameworks+=(-framework "$cache/sdk-$platform/ios_system.framework")
        if ! cmp -s "$cache/sdk-$platform/ios_system.framework/ios_system" "$ios_system/$slice/ios_system.framework/ios_system"; then
          sdk_changed=1
        fi
      done
      if [[ $sdk_changed == 1 || ! -f $ios_system/Info.plist ]]; then
        if [[ -d $cache/ios-system.xcframework ]]; then rm -rf "$cache/ios-system.xcframework"; fi
        logged "$cache/sdk-package.log" xcodebuild -create-xcframework "${sdk_frameworks[@]}" -output "$cache/ios-system.xcframework"
        mkdir -p "$ios_system"
        rsync -a --delete "$cache/ios-system.xcframework/" "$ios_system/"
      fi
      ;;
    node | device)
      if [[ ! -f $cache/pinned.tar.gz ]]; then
        curl --http1.1 --remove-on-error -fL --retry 2 --max-time 600 "https://nodejs.org/dist/$rev/node-$rev.tar.gz" -o "$cache/pinned.tar.gz"
      fi
      [[ $(shasum -a 256 "$cache/pinned.tar.gz" | awk '{print $1}') == "$sha" ]] || die "$cache/pinned.tar.gz does not match the pinned checksum; delete it and rerun."
      # The node and device stages share this tree. Extract and patch it once per patch set;
      # any other state (older patches, interrupted run) is discarded with its build output.
      local node_patches="ios-platform host-tools command-options command-errors command-environment child-process"
      local node_stamp command_patch
      node_stamp=$(
        {
          echo "$sha"
          for command_patch in $node_patches; do cat "$here/$command_patch.patch"; done
        } | shasum -a 256
      )
      if [[ ! -f $source/.patched || $(<"$source/.patched") != "$node_stamp" ]]; then
        [[ ! -e $source ]] || echo "Node source tree is not at the current patch set; extracting a fresh copy (full rebuild)."
        rm -rf "$source"
        mkdir -p "$source"
        tar -xzf "$cache/pinned.tar.gz" -C "$source" --strip-components=1
        apply_patches "$source" $node_patches
        echo "$node_stamp" >"$source/.patched"
      else
        echo "Node source already carries the current patches."
      fi
      (
        cd "$source"
        # configure probes the bundled OpenSSL with $CC and the include variables; drop user overrides so the build matches a clean shell.
        unset CC CXX CC_host CXX_host CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH OBJC_INCLUDE_PATH
        export GYP_DEFINES="target_arch=arm64 host_os=mac target_os=ios v8_enable_turbofan=0 v8_enable_sparkplug=0 v8_enable_maglev=0 v8_enable_drumbrake=0"
        # GYP's lite flag does not itself disable compiler source sets in this branch.
        local iossim=true
        local configure_args=(--dest-os=ios --dest-cpu=arm64 --with-intl=small-icu --cross-compiling --openssl-no-asm --v8-options=--jitless --v8-lite-mode --without-node-code-cache --without-node-snapshot --v8-disable-temporal-support --v8-disable-maglev)
        if [[ $stage == device ]]; then
          iossim=false
        else
          configure_args+=(--ios-simulator)
        fi
        if [[ ! -f config.gypi ]] || ! python3 -c 'import json,sys; v=json.loads(open("config.gypi").read().split("\n",1)[1])["variables"]; sys.exit(not (v["iossim"] == sys.argv[1] and v["icu_small"] == "true" and v["v8_enable_lite_mode"] == 1 and v["v8_enable_webassembly"] == 0 and v["v8_enable_pointer_compression"] == 0 and v["v8_enable_maglev"] == 0 and v["node_v8_options"] == "--jitless" and v["openssl_version"] >= 0x3000000f))' "$iossim" || [[ tools/v8_gypfiles/v8.gyp -nt out/Makefile || tools/v8_gypfiles/features.gypi -nt out/Makefile || tools/gyp/pylib/gyp/generator/make.py -nt out/Makefile || common.gypi -nt out/Makefile ]]; then
          logged "$cache/configure.log" ./configure "${configure_args[@]}"
        fi
        # A failed probe leaves openssl_version 0 (only a warning); engine.cc then builds without engine compat and make dies in ncrypto.
        python3 -c 'import json,sys; sys.exit(json.loads(open("config.gypi").read().split("\n",1)[1])["variables"]["openssl_version"] < 0x3000000f)' || die "configure did not detect the bundled OpenSSL 3 headers; see the OpenSSL warnings in $cache/configure.log."
        local targets=(libnode) name
        for name in $libraries; do
          case $name in
            node) ;;
            ffi) targets+=(libffi) ;;
            uv) targets+=(libuv) ;;
            *) targets+=("$name") ;;
          esac
        done
        # Build archive targets only; the default also compiles unused V8 tools.
        # GYP emits DWARF even in Release; stock trailing flags keep caches compact.
        CFLAGS="${CFLAGS:-} -g0" CXXFLAGS="${CXXFLAGS:-} -g0" \
          CFLAGS_host="${CFLAGS_host:-} -g0" CXXFLAGS_host="${CXXFLAGS_host:-} -g0" \
          logged "$cache/make.log" /usr/bin/time -p make -C out BUILDTYPE=Release -j"$jobs" "${targets[@]}"
      )
      xcrun nm -gU "$source/out/Release/libnode_base.a" 2>/dev/null | grep 'InitializeOncePerProcess' >/dev/null || die "make finished without a usable libnode_base.a; see $cache/make.log."
      local platform=simulator name
      [[ $stage != device ]] || platform=device
      mkdir -p "$cache/$platform-libs"
      for name in $libraries; do
        if [[ ! -f $cache/$platform-libs/lib$name.a || $source/out/Release/lib$name.a -nt $cache/$platform-libs/lib$name.a ]]; then
          cp "$source/out/Release/lib$name.a" "$cache/$platform-libs/lib$name.a"
          xcrun strip -S "$cache/$platform-libs/lib$name.a"
        fi
      done
      ;;
    package)
      # Core and libuv patches are already compiled by the archive stages.
      # Match the archive's public V8 feature/ABI definitions.
      local adapter_defines adapter_config=$source/out/tools/v8_gypfiles/v8_base_without_compiler.target.mk
      read -r -a adapter_defines <<<"$(
        python3 - "$adapter_config" <<'PYABI'
import pathlib, shlex, sys
text = pathlib.Path(sys.argv[1]).read_text()
body = text.split('DEFS_Release :=', 1)[1].split('\n\n', 1)[0]
flags = shlex.split(body.replace('\\\n', ' '))
# Branding is a quoted string, not a layout define; Node supplies its own name.
print(' '.join(['-DNDEBUG'] + [flag for flag in flags if flag.startswith(('-DV8_', '-DCPPGC')) and not flag.startswith('-DV8_EMBEDDER_STRING=')]))
PYABI
      )"
      mkdir -p "$cache/fetch"
      printf '{"name":"node-ios-fetch","dependencies":{"node-fetch":"3.3.2"}}\n' >"$cache/fetch/package.json"
      cp "$here/fetch-lock.json" "$cache/fetch/package-lock.json"
      logged "$cache/fetch-install.log" npm ci --prefix "$cache/fetch" --cache "$cache/npm-cache" --ignore-scripts --no-audit --no-fund
      local platform sdk target slice framework name input relink
      local framework_args=()
      local package_changed=0
      for platform in simulator device; do
        [[ -d $cache/$platform-libs ]] || continue
        sdk=iphonesimulator
        target=arm64-apple-ios16.0-simulator
        slice=ios-arm64-simulator
        if [[ $platform == device ]]; then
          sdk=iphoneos
          target=arm64-apple-ios16.0
          slice=ios-arm64
        fi
        framework=$cache/framework/$platform/node.framework
        mkdir -p "$framework"
        if [[ ! -f $cache/child-process-$platform.o || $here/child-process.cc -nt $cache/child-process-$platform.o ]]; then
          xcrun --sdk "$sdk" clang++ -x objective-c++ -std=c++20 -fmodules -fmodules-cache-path="$cache/clang-modules" -target "$target" \
            -isysroot "$(xcrun --sdk "$sdk" --show-sdk-path)" \
            -isystem "$source/deps/uv/include" \
            -isystem "$ios_system/$slice/ios_system.framework/Headers" -Wall -Wextra -Werror \
            -c "$here/child-process.cc" -o "$cache/child-process-$platform.o"
        fi
        if [[ ! -f $cache/node-command-$platform.o || $here/node-command.cc -nt $cache/node-command-$platform.o || $here/build.sh -nt $cache/node-command-$platform.o || $adapter_config -nt $cache/node-command-$platform.o ]]; then
          xcrun --sdk "$sdk" clang++ -x objective-c++ -std=c++20 -fmodules -fmodules-cache-path="$cache/clang-modules" -target "$target" \
            -isysroot "$(xcrun --sdk "$sdk" --show-sdk-path)" "${adapter_defines[@]}" \
            -isystem "$source/src" -isystem "$source/deps/v8/include" -isystem "$source/deps/uv/include" \
            -isystem "$ios_system/$slice/ios_system.framework/Headers" -Wall -Wextra -Werror -c "$here/node-command.cc" -o "$cache/node-command-$platform.o"
        fi
        local link_inputs=("$cache/node-command-$platform.o" "$cache/child-process-$platform.o")
        for name in $libraries; do
          [[ -f $cache/$platform-libs/lib$name.a ]]
          link_inputs+=("$cache/$platform-libs/lib$name.a")
        done
        relink=0
        for input in "${link_inputs[@]}" "$here/build.sh"; do
          [[ -f $framework/node && ! $input -nt $framework/node ]] || relink=1
        done
        if [[ $relink == 1 ]]; then
          xcrun --sdk "$sdk" clang++ -dynamiclib -target "$target" \
            -isysroot "$(xcrun --sdk "$sdk" --show-sdk-path)" \
            -Wl,-install_name,@rpath/node.framework/node -Wl,-exported_symbol,_node_ios_main \
            -Wl,-exported_symbol,_npm_ios_main -Wl,-exported_symbol,_npx_ios_main \
            -Wl,-dead_strip -F "$ios_system/$slice" \
            -framework ios_system -framework Foundation "${link_inputs[@]}" -o "$framework/node"
          xcrun strip -x "$framework/node"
        fi
        if [[ ! -f $framework/Info.plist ]] || ! grep -q "<string>${rev#v}</string>" "$framework/Info.plist"; then
          cat >"$framework/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>org.nodejs.node</string>
<key>CFBundleName</key><string>node</string>
<key>CFBundleExecutable</key><string>node</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleVersion</key><string>${rev#v}</string>
<key>CFBundleShortVersionString</key><string>${rev#v}</string>
<key>MinimumOSVersion</key><string>16.0</string>
</dict></plist>
EOF
        fi
        cp "$source/LICENSE" "$framework/LICENSE"
        framework_args+=(-framework "$framework")
        if [[ $relink == 1 ]] || ! cmp -s "$framework/Info.plist" "$app/xcfs/node.xcframework/$slice/node.framework/Info.plist" || ! cmp -s "$framework/node" "$app/xcfs/node.xcframework/$slice/node.framework/node" || [[ -e $app/xcfs/node.xcframework/$slice/node.framework/npm || -e $app/xcfs/node.xcframework/$slice/node.framework/fetch ]]; then
          package_changed=1
        fi
      done
      # The App Store treats every .js and .py file inside a framework as unsigned code, so the
      # JavaScript lives in the app bundle's resources: the project copies these two folders to
      # $APPDIR/npm and $APPDIR/node-fetch. Node's pinned tree ships its matching npm, including its dependency tree.
      mkdir -p "$app/Resources/npm" "$app/Resources/node-fetch/fetch"
      rsync -a --delete "$source/deps/npm/" "$app/Resources/npm/"
      patch -s -F 0 -p1 -d "$app/Resources/npm" <"$here/npm-native.patch"
      cp "$here/fetch-preload.mjs" "$here/fetch-lock.json" "$app/Resources/node-fetch/"
      rsync -a --delete "$cache/fetch/node_modules" "$app/Resources/node-fetch/fetch/"
      if [[ $package_changed == 1 || ! -d $app/xcfs/node.xcframework ]]; then
        if [[ -d $app/xcfs/node.xcframework ]]; then
          rm -rf "$app/xcfs/node.xcframework"
        fi
        logged "$cache/framework.log" xcodebuild -create-xcframework "${framework_args[@]}" -output "$app/xcfs/node.xcframework"
      fi
      # The App Store rejects the upload when a framework holds script files it cannot sign.
      if scripts=$(find "$app/xcfs/node.xcframework" \( -name '*.js' -o -name '*.mjs' -o -name '*.cjs' -o -name '*.py' \) -print -quit) && [[ -n $scripts ]]; then
        die "$scripts is a script inside node.xcframework; app-store frameworks must hold none."
      fi
      ;;
  esac
)
check
plan
if [[ ${2:-} != --dry-run ]]; then apply; fi
