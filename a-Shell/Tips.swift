//
//  Tips.swift
//  a-Shell
//
//  Created by Nicolas Holzschuch on 12/07/2023.
//  Copyright © 2023 AsheKube. All rights reserved.
//

import Foundation
import TipKit

@available(iOS 17.0, *)
struct startInternalBrowser: Tip {

    var title: Text {
        Text("Use left-edge-swipe to go back, right-edge-swipe to go forward")
    }
    
    var message: Text {
        Text("")
    }

    var options: [TipOption] = [MaxDisplayCount(1)]
}


@available(iOS 17.0, *)
struct toolbarTip: Tip {

    var title: Text {
        Text("Extra keys: tab, control, escape, paste and the four arrows")
    }
    
    var message: Text {
        Text("")
    }

    var options: [TipOption] = [MaxDisplayCount(1)]
}

@available(iOS 17.0, *)
struct ArrowToolbarTip: Tip {
    // Set once toolbarTip is closed or will not show, so that toolbarTip comes first.
    @Parameter static var toolbarTipDone: Bool = false

    // The whole hint lives in the title.
    var title: Text { Text("Arrows: flick to move once, keep holding to repeat") }
    var rules: [Rule] { [#Rule(Self.$toolbarTipDone) { $0 }] }
    var options: [TipOption] = [MaxDisplayCount(1)]
}
