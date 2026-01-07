//
//  SignalNoiseWidgetBundle.swift
//  SignalNoiseWidget
//
//  Created by Luke Brevoort on 12/22/25.
//

import WidgetKit
import SwiftUI

@main
struct SignalNoiseWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.1, *) {
            SignalNoiseWidgetLiveActivity()
        }
    }
}
