//
//  WindowManager.swift
//  ClaudeIsland
//
//  Manages the panel window lifecycle
//

import AppKit
import os.log

private let logger = Logger(subsystem: "com.claudeisland", category: "Window")

class WindowManager {
    private(set) var windowController: NotchWindowController?

    func setupPanelWindow(statusItemRect: CGRect) -> NotchWindowController? {
        guard let screen = NSScreen.main else {
            logger.warning("No screen found")
            return nil
        }

        if let existingController = windowController {
            existingController.window?.orderOut(nil)
            existingController.window?.close()
            windowController = nil
        }

        windowController = NotchWindowController(
            statusItemRect: statusItemRect,
            screen: screen
        )

        return windowController
    }
}
