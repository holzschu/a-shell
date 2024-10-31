//
//  WasmKit.swift
//  a-Shell
//
//  Created by Nicolas Holzschuch on 05/08/2024.
//  Copyright © 2024 AsheKube. All rights reserved.
//

import WasmKit
import WasmKitWASI
import WAT
import Foundation
import SystemPackage
import ios_system


@_cdecl("wasmKit")
public func wasmKit(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    if var args = convertCArguments(argc: argc, argv: argv) {
        
        do {
            args.removeFirst() // remove the "wasmKit" at the beginning
            // Parse a WASI-compliant WebAssembly module from a file.
            let module = try parseWasm(filePath: FilePath(stringLiteral: args[0]))
            
            // Create a WASI instance forwarding to the host environment.
            let wasi = try WASIBridgeToHost(args: args)
            // Create a runtime with WASI host modules.
            let runtime = Runtime(hostModules: wasi.hostModules)
            let instance = try runtime.instantiate(module: module)
                        
            // Start the WASI command-line application.
            let exitCode = try wasi.start(instance, runtime: runtime)
            // Exit the Swift program with the WASI exit code.
            return Int32(exitCode)
        }
        catch {
            fputs("Failure loading webAssembly: \(error)", thread_stderr)
        }
    }
    return 1;
}


