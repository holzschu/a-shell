import Foundation

// Verify the argument contract used by the terminal command.
@main
struct TermContract {
    static func main() throws {
        let bytes = try TermRequest.parse(["keys", #"\e[6~\x00\xff"#, "--window", "target"])
        precondition(bytes.bytes == Data([27, 91, 54, 126, 0, 255]))
        precondition(bytes.window == "target")
        let text = try TermRequest.parse(["type", "--key", "enter", "--", "--literal Привет"])
        precondition(text.text == "--literal Привет" && text.keys == ["enter"])
        let colors = try TermRequest.parse(["screen", "--colors"])
        precondition(colors.colors && colors.json)
        let size = try TermRequest.parse(["resize", "80x24"])
        precondition(size.columns == 80 && size.rows == 24)
        print("PASS: literal Unicode, raw bytes, explicit window, geometry and color requests")
    }

}
