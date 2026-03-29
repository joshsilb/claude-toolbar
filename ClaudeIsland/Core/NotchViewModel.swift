//
//  NotchViewModel.swift
//  ClaudeIsland
//
//  State management for the panel
//

import AppKit
import Combine
import SwiftUI

enum NotchStatus: Equatable {
    case closed
    case opened
}

enum NotchOpenReason {
    case click
    case notification
    case unknown
}

enum NotchContentType: Equatable {
    case instances
    case menu
    case chat(SessionState)

    var id: String {
        switch self {
        case .instances: return "instances"
        case .menu: return "menu"
        case .chat(let session): return "chat-\(session.sessionId)"
        }
    }
}

@MainActor
class NotchViewModel: ObservableObject {
    // MARK: - Published State

    @Published var status: NotchStatus = .closed
    @Published var openReason: NotchOpenReason = .unknown
    @Published var contentType: NotchContentType = .instances

    // MARK: - Dependencies

    private let soundSelector = SoundSelector.shared

    // MARK: - Geometry

    var geometry: NotchGeometry

    var screenRect: CGRect { geometry.screenRect }

    var openedSize: CGSize {
        switch contentType {
        case .chat:
            return CGSize(
                width: min(screenRect.width * 0.5, 600),
                height: 580
            )
        case .menu:
            return CGSize(
                width: min(screenRect.width * 0.4, 480),
                height: 420 + soundSelector.expandedPickerHeight
            )
        case .instances:
            return CGSize(
                width: min(screenRect.width * 0.4, 480),
                height: 320
            )
        }
    }

    // MARK: - Animation

    var animation: Animation {
        .easeOut(duration: 0.25)
    }

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()
    private let events = EventMonitors.shared

    // MARK: - Initialization

    init(statusItemRect: CGRect, screenRect: CGRect) {
        self.geometry = NotchGeometry(
            statusItemRect: statusItemRect,
            screenRect: screenRect
        )
        setupEventHandlers()
        observeSelectors()
    }

    func updateStatusItemRect(_ rect: CGRect) {
        let screen = NSScreen.screens.first { $0.frame.contains(rect.origin) }
        geometry = NotchGeometry(
            statusItemRect: rect,
            screenRect: screen?.frame ?? geometry.screenRect
        )
    }

    private func observeSelectors() {
        soundSelector.$isPickerExpanded
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Event Handling

    private func setupEventHandlers() {
        events.mouseDown
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleMouseDown()
            }
            .store(in: &cancellables)
    }

    private var isInChatMode: Bool {
        if case .chat = contentType { return true }
        return false
    }

    private var currentChatSession: SessionState?

    private func handleMouseDown() {
        let location = NSEvent.mouseLocation

        switch status {
        case .opened:
            if geometry.isPointOutsidePanel(location, size: openedSize) {
                notchClose()
            }
        case .closed:
            break
        }
    }

    // MARK: - Actions

    func notchOpen(reason: NotchOpenReason = .unknown) {
        openReason = reason
        status = .opened

        if reason == .notification {
            currentChatSession = nil
            return
        }

        if let chatSession = currentChatSession {
            if case .chat(let current) = contentType, current.sessionId == chatSession.sessionId {
                return
            }
            contentType = .chat(chatSession)
        }
    }

    func notchClose() {
        if case .chat(let session) = contentType {
            currentChatSession = session
        }
        status = .closed
        contentType = .instances
    }

    func togglePanel() {
        if status == .opened {
            notchClose()
        } else {
            notchOpen(reason: .click)
        }
    }

    func toggleMenu() {
        contentType = contentType == .menu ? .instances : .menu
    }

    func showChat(for session: SessionState) {
        if case .chat(let current) = contentType, current.sessionId == session.sessionId {
            return
        }
        contentType = .chat(session)
    }

    func exitChat() {
        currentChatSession = nil
        contentType = .instances
    }
}
