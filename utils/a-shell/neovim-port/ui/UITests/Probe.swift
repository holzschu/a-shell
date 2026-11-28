import XCTest

final class Probe: XCTestCase {
    private var app: XCUIApplication {
        let bundle = ProcessInfo.processInfo.environment["NVIM_APP_BUNDLE"] ?? "local.herdr.hostbridge.a-Shell-mini"
        return XCUIApplication(bundleIdentifier: bundle)
    }

    // AXe drives terminal input; XCTest supplies only the device rotation action.
    func testPortraitOrientation() {
        app.activate()
        XCUIDevice.shared.orientation = .portrait
    }

    func testLandscapeOrientation() {
        app.activate()
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    func testStockServerSpawnFailure() {
        app.activate()
        let terminal = app.textViews.firstMatch
        XCTAssertTrue(terminal.waitForExistence(timeout: 10))
        terminal.typeText("herdr\n")
        Thread.sleep(forTimeInterval: 2)
        terminal.typeText("nvim -u NONE sample.lua 2> stock-spawn.err\n")
        Thread.sleep(forTimeInterval: 3)
        terminal.typeText("echo STOCK_SPAWN_RECOVERED > stock-spawn-recovered.out\n")
        Thread.sleep(forTimeInterval: 2)
    }

    func testNativeEditorInHerdr() {
        XCUIDevice.shared.orientation = .portrait
        app.activate()
        let terminal = app.textViews.firstMatch
        XCTAssertTrue(terminal.waitForExistence(timeout: 10))
        terminal.typeText("cd ~/Documents\nherdr\n")
        Thread.sleep(forTimeInterval: 2)
        terminal.typeText("nvim --version > version.out 2> version.err\n")
        Thread.sleep(forTimeInterval: 3)
        terminal.typeText("nvim -u .config/nvim/init.lua sample.lua\n")
        Thread.sleep(forTimeInterval: 4)
        terminal.typeText("Go-- edited in Herdr")
        print(app.buttons.debugDescription)
        let escape = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'escape' OR label == 'esc'")).firstMatch
        XCTAssertTrue(escape.waitForExistence(timeout: 3))
        escape.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        Thread.sleep(forTimeInterval: 1)
        terminal.typeText(":lua vim.fn.writefile({tostring(vim.o.columns), tostring(vim.o.lines)}, 'portrait-state.out')\n")
        Thread.sleep(forTimeInterval: 1)
        let before = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        before.name = "neovim-portrait"; before.lifetime = .keepAlways; add(before)
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 4)
        let resized = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        resized.name = "neovim-resized"; resized.lifetime = .keepAlways; add(resized)
        terminal.typeText(":lua local c=vim.treesitter.get_captures_at_pos(0,0,0)[1]; vim.fn.writefile({tostring(vim.g.port_init), vim.bo.filetype, tostring(vim.o.columns), tostring(vim.o.lines), _VERSION, c.lang..':'..c.capture}, 'editor-state.out')\n")
        terminal.typeText(":wq\n")
        Thread.sleep(forTimeInterval: 3)
        terminal.typeText("echo NVIM_RECOVERED > recovered.out\nnvim -u .config/nvim/init.lua sample.lua\n")
        Thread.sleep(forTimeInterval: 3)
        terminal.typeText("Go-- discarded with Ctrl-C")
        let control = app.buttons.matching(NSPredicate(format: "label == 'control'")).firstMatch
        XCTAssertTrue(control.waitForExistence(timeout: 3))
        control.tap()
        terminal.typeText("c")
        Thread.sleep(forTimeInterval: 1)
        terminal.typeText(":lua vim.fn.writefile({vim.api.nvim_get_mode().mode}, 'ctrl-c.out')\n")
        terminal.typeText(":q!\n")
        Thread.sleep(forTimeInterval: 3)
        terminal.typeText("nvim --headless -u NONE '+call writefile([\"SECOND_SESSION\"], \"second.out\")' +qa\nnvim --headless -u NONE '+luafile lazy-smoke.lua' +qa > lazy.stdout 2> lazy.err\necho LAZY_RECOVERED > lazy-recovered.out\ndash phone-subprocess.sh ~/Documents/pane-subprocess ~/Documents > pane-subprocess.out 2>&1\n")
        Thread.sleep(forTimeInterval: 5)
    }
}
