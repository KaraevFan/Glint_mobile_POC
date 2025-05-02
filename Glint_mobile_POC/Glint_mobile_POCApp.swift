//
//  Glint_mobile_POCApp.swift
//  Glint_mobile_POC
//
//  Created by Tomoyuki Kano on 5/2/25.
//

import SwiftUI

@main
struct Glint_mobile_POCApp: App {

    init() {
        ModelLoaderUtil.verifyModels()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
