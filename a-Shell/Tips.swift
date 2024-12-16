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
