//
//  Models.swift
//  CueApp
//

import SwiftUI

// MARK: - Models

// Model for environment variable pair
struct EnvVariable: Equatable, Identifiable {
    var id = UUID()
    var key: String = ""
    var value: String = ""

    var isValid: Bool {
        !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
