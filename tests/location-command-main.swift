UserDefaults.standard.set(true, forKey: "background_mode")
DispatchQueue.global().async {
    let strings = ["location", "--timeout", "0.1"].map { value in value.withCString { strdup($0) } }
    let rc = strings.withUnsafeBufferPointer { args in
        ashellLocation(argc: Int32(args.count), argv: UnsafeMutablePointer(mutating: args.baseAddress))
    }
    for pointer in strings { free(pointer) }
    DispatchQueue.main.async {
        let strings = ["background", "status"].map { value in value.withCString { strdup($0) } }
        _ = strings.withUnsafeBufferPointer { args in
            ashellBackground(argc: Int32(args.count), argv: UnsafeMutablePointer(mutating: args.baseAddress))
        }
        for pointer in strings { free(pointer) }
        fflush(stdout)
        exit(rc)
    }
}
RunLoop.main.run()
