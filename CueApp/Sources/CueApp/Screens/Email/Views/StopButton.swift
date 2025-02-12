import SwiftUI

struct StopButton: View {
    let action: () -> Void

    var body: some View {
        CircularButton(
            systemImage: "stop.fill",
            backgroundColor: AppTheme.Colors.primaryText,
            action: action
        )
    }
}
