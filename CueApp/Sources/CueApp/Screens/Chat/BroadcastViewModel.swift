//
//  BroadcastViewModel.swift
//  CueApp
//
//  Created by z on 12/18/24.
//
import SwiftUI
import BroadcastShared
@preconcurrency import Combine

@MainActor
class BroadcastViewModel: ObservableObject {
    @Published var frameData: [String: Any]?
    private let dataManager = SharedDataManager.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        print("🚀 BroadcastViewModel: Initializing")
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                print("⏰ BroadcastViewModel: Timer tick")
                self?.checkForUpdates()
            }
            .store(in: &cancellables)
    }

    private func checkForUpdates() {
        if let newData = dataManager.getLastFrameData() {
            print("📥 BroadcastViewModel: Received new data: \(newData)")
            self.frameData = newData
        } else {
            print("⚠️ BroadcastViewModel: No data available")
        }
    }

    deinit {
        print("🔽 BroadcastViewModel: Deinitializing")
        cancellables.forEach { $0.cancel() }
    }
}
