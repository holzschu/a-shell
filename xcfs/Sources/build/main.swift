// use it from root folder:
// `swift run --package-path xcfs build [all, awk, tar, ios_system, ...]`

import FMake
import class Foundation.ProcessInfo

OutputLevel.default = .error

// TODO: We can add more platforms here
let platforms: [Platform] = [.iPhoneOS, .iPhoneSimulator, .Catalyst]

let args = ProcessInfo.processInfo.arguments 


