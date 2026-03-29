//
//  NotchViewController.swift
//  ClaudeIsland
//
//  Hosts the SwiftUI NotchView in AppKit
//

import AppKit
import SwiftUI

class NotchViewController: NSViewController {
    private let viewModel: NotchViewModel

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let hostingView = NSHostingView(rootView: NotchView(viewModel: viewModel))
        self.view = hostingView
    }
}
