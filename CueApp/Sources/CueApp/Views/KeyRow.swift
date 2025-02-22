import SwiftUI

struct SecretView: View {
    var secret: String

    var body: some View {
        Text(maskKey(secret))
            .font(.system(.footnote, design: .monospaced))
            .foregroundColor(.secondary)
    }

    private func maskKey(_ key: String) -> String {
        if key.count > 8 {
            let prefix = String(key.prefix(4))
            let suffix = String(key.suffix(4))
            return "\(prefix)...\(suffix)"
        }
        return key
    }
}
