//
//  StatusItemManager.swift
//  ClaudeIsland
//
//  Manages the NSStatusItem in the menu bar tray
//

import AppKit
import Combine
import SwiftUI

@MainActor
class StatusItemManager: ObservableObject {
    private let statusItem: NSStatusItem
    private var hostingView: NSHostingView<StatusItemContentView>?
    private var cancellables = Set<AnyCancellable>()

    @Published var isProcessing: Bool = false
    @Published var hasPendingPermission: Bool = false
    @Published var hasWaitingForInput: Bool = false
    @Published var isBouncing: Bool = false

    private var waitingForInputTimestamps: [String: Date] = [:]
    private var previousWaitingForInputIds: Set<String> = []

    var onTogglePanel: (() -> Void)?

    var buttonFrame: CGRect? {
        statusItem.button?.window?.frame
    }

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        setupButton()
        setupHostingView()
        observeSessions()
    }

    private func setupButton() {
        guard let button = statusItem.button else { return }
        button.action = #selector(statusItemClicked)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupHostingView() {
        let contentView = StatusItemContentView(manager: self)
        let hosting = NSHostingView(rootView: contentView)
        hosting.frame = NSRect(x: 0, y: 0, width: 40, height: 22)

        guard let button = statusItem.button else { return }
        hosting.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: button.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])

        hostingView = hosting
    }

    @objc private func statusItemClicked() {
        onTogglePanel?()
    }

    func triggerBounce() {
        isBouncing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.isBouncing = false
        }
    }

    private func observeSessions() {
        SessionStore.shared.sessionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.updateIndicators(from: sessions)
            }
            .store(in: &cancellables)
    }

    private func updateIndicators(from sessions: [SessionState]) {
        isProcessing = sessions.contains { $0.phase == .processing || $0.phase == .compacting }
        hasPendingPermission = sessions.contains { $0.phase.isWaitingForApproval }

        let now = Date()
        let displayDuration: TimeInterval = 30
        let waitingSessions = sessions.filter { $0.phase == .waitingForInput }
        let currentIds = Set(waitingSessions.map { $0.stableId })
        let newIds = currentIds.subtracting(previousWaitingForInputIds)

        for session in waitingSessions where newIds.contains(session.stableId) {
            waitingForInputTimestamps[session.stableId] = now
        }

        let staleIds = Set(waitingForInputTimestamps.keys).subtracting(currentIds)
        for staleId in staleIds {
            waitingForInputTimestamps.removeValue(forKey: staleId)
        }

        hasWaitingForInput = waitingSessions.contains { session in
            if let enteredAt = waitingForInputTimestamps[session.stableId] {
                return now.timeIntervalSince(enteredAt) < displayDuration
            }
            return false
        }

        if !newIds.isEmpty {
            triggerBounce()
            DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration) { [weak self] in
                guard let self else { return }
                self.hasWaitingForInput = self.waitingForInputTimestamps.values.contains {
                    now.timeIntervalSince($0) < displayDuration
                }
            }
        }

        previousWaitingForInputIds = currentIds
    }
}

struct StatusItemContentView: View {
    @ObservedObject var manager: StatusItemManager

    var body: some View {
        HStack(spacing: 4) {
            ClaudeCrabIcon(
                size: 14,
                animateLegs: manager.isProcessing || manager.hasPendingPermission
            )
            .scaleEffect(manager.isBouncing ? 1.3 : 1.0)
            .animation(.spring(response: 0.15, dampingFraction: 0.5), value: manager.isBouncing)

            if manager.hasPendingPermission {
                PermissionIndicatorIcon(size: 12, color: Color(red: 0.85, green: 0.47, blue: 0.34))
            } else if manager.isProcessing {
                ProcessingSpinner()
            } else if manager.hasWaitingForInput {
                ReadyForInputIndicatorIcon(size: 12, color: TerminalColors.green)
            }
        }
        .padding(.horizontal, 4)
    }
}
