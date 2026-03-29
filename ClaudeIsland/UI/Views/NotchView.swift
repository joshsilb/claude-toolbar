//
//  NotchView.swift
//  ClaudeIsland
//
//  The panel SwiftUI view shown when the status item is clicked
//

import AppKit
import CoreGraphics
import SwiftUI

struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel
    @StateObject private var sessionMonitor = ClaudeSessionMonitor()
    @ObservedObject private var updateManager = UpdateManager.shared
    @State private var previousPendingIds: Set<String> = []
    @State private var previousWaitingForInputIds: Set<String> = []
    private var isAnyProcessing: Bool {
        sessionMonitor.instances.contains { $0.phase == .processing || $0.phase == .compacting }
    }

    private var hasPendingPermission: Bool {
        sessionMonitor.instances.contains { $0.phase.isWaitingForApproval }
    }

    private let openAnimation = Animation.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
                .frame(height: 36)

            contentView
                .frame(width: viewModel.openedSize.width - 24)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .frame(
            width: viewModel.openedSize.width,
            height: viewModel.openedSize.height,
            alignment: .top
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.black)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.7), radius: 6)
        .animation(openAnimation, value: viewModel.openedSize)
        .preferredColorScheme(.dark)
        .onAppear {
            sessionMonitor.startMonitoring()
        }
        .onChange(of: sessionMonitor.pendingInstances) { _, sessions in
            handlePendingSessionsChange(sessions)
        }
        .onChange(of: sessionMonitor.instances) { _, instances in
            handleWaitingForInputChange(instances)
        }
    }

    // MARK: - Header Row

    @ViewBuilder
    private var headerRow: some View {
        HStack(spacing: 12) {
            ClaudeCrabIcon(
                size: 14,
                animateLegs: isAnyProcessing || hasPendingPermission
            )
            .padding(.leading, 8)

            if hasPendingPermission {
                PermissionIndicatorIcon(size: 12, color: Color(red: 0.85, green: 0.47, blue: 0.34))
            }

            if isAnyProcessing || hasPendingPermission {
                ProcessingSpinner()
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.toggleMenu()
                    if viewModel.contentType == .menu {
                        updateManager.markUpdateSeen()
                    }
                }
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: viewModel.contentType == .menu ? "xmark" : "line.3.horizontal")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())

                    if updateManager.hasUnseenUpdate && viewModel.contentType != .menu {
                        Circle()
                            .fill(TerminalColors.green)
                            .frame(width: 6, height: 6)
                            .offset(x: -2, y: 2)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        Group {
            switch viewModel.contentType {
            case .instances:
                ClaudeInstancesView(
                    sessionMonitor: sessionMonitor,
                    viewModel: viewModel
                )
            case .menu:
                NotchMenuView(viewModel: viewModel)
            case .chat(let session):
                ChatView(
                    sessionId: session.sessionId,
                    initialSession: session,
                    sessionMonitor: sessionMonitor,
                    viewModel: viewModel
                )
            }
        }
        .frame(width: viewModel.openedSize.width - 24)
    }

    // MARK: - Event Handlers

    private func handlePendingSessionsChange(_ sessions: [SessionState]) {
        let currentIds = Set(sessions.map { $0.stableId })
        let newPendingIds = currentIds.subtracting(previousPendingIds)

        if !newPendingIds.isEmpty &&
           viewModel.status == .closed &&
           !TerminalVisibilityDetector.isTerminalVisibleOnCurrentSpace() {
            viewModel.notchOpen(reason: .notification)
        }

        previousPendingIds = currentIds
    }

    private func handleWaitingForInputChange(_ instances: [SessionState]) {
        let waitingForInputSessions = instances.filter { $0.phase == .waitingForInput }
        let currentIds = Set(waitingForInputSessions.map { $0.stableId })
        let newWaitingIds = currentIds.subtracting(previousWaitingForInputIds)

        if !newWaitingIds.isEmpty {
            let newlyWaitingSessions = waitingForInputSessions.filter { newWaitingIds.contains($0.stableId) }

            if let soundName = AppSettings.notificationSound.soundName {
                Task {
                    let shouldPlaySound = await shouldPlayNotificationSound(for: newlyWaitingSessions)
                    if shouldPlaySound {
                        await MainActor.run {
                            NSSound(named: soundName)?.play()
                        }
                    }
                }
            }
        }

        previousWaitingForInputIds = currentIds
    }

    private func shouldPlayNotificationSound(for sessions: [SessionState]) async -> Bool {
        for session in sessions {
            guard let pid = session.pid else {
                return true
            }

            let isFocused = await TerminalVisibilityDetector.isSessionFocused(sessionPid: pid)
            if !isFocused {
                return true
            }
        }

        return false
    }
}
