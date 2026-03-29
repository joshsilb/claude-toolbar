//
//  NotchWindowController.swift
//  ClaudeIsland
//
//  Controls the panel window positioning and lifecycle
//

import AppKit
import Combine
import SwiftUI

class NotchWindowController: NSWindowController {
    let viewModel: NotchViewModel
    private var cancellables = Set<AnyCancellable>()

    init(statusItemRect: CGRect, screen: NSScreen) {
        let screenFrame = screen.frame

        self.viewModel = NotchViewModel(
            statusItemRect: statusItemRect,
            screenRect: screenFrame
        )

        let initialSize = viewModel.openedSize
        let panelFrame = viewModel.geometry.panelFrame(for: initialSize)

        let notchWindow = NotchPanel(
            contentRect: panelFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        super.init(window: notchWindow)

        let hostingController = NotchViewController(viewModel: viewModel)
        notchWindow.contentViewController = hostingController

        notchWindow.setFrame(panelFrame, display: true)

        viewModel.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.handleStatusChange(status)
            }
            .store(in: &cancellables)

        viewModel.$contentType
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.repositionPanel()
            }
            .store(in: &cancellables)

        notchWindow.ignoresMouseEvents = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateStatusItemRect(_ rect: CGRect) {
        viewModel.updateStatusItemRect(rect)
        if viewModel.status == .opened {
            repositionPanel()
        }
    }

    private func handleStatusChange(_ status: NotchStatus) {
        guard let panel = window as? NotchPanel else { return }

        switch status {
        case .opened:
            repositionPanel()
            panel.ignoresMouseEvents = false
            panel.orderFront(nil)
            if viewModel.openReason != .notification {
                NSApp.activate(ignoringOtherApps: false)
                panel.makeKey()
            }
        case .closed:
            panel.ignoresMouseEvents = true
            panel.orderOut(nil)
        }
    }

    private func repositionPanel() {
        guard let panel = window else { return }
        let size = viewModel.openedSize
        let frame = viewModel.geometry.panelFrame(for: size)
        panel.setFrame(frame, display: true)
    }
}
