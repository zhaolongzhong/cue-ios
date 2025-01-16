import SwiftUI

struct AXAppSelectionMenu: View {
    @State private var selectedApp: AccessibleApplication = .textEdit
    let onStartAXApp: ((AccessibleApplication) -> Void)?

    var body: some View {
        Menu {
            ForEach(AccessibleApplication.allCases, id: \.self) { app in
                Button(action: {
                    selectedApp = app
                    onStartAXApp?(selectedApp)
                }) {
                    Text(app.name)
                        .frame(minWidth: 200, alignment: .leading)
                }
            }
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right.square")
                .foregroundColor(Color.secondary)
                .frame(width: 36, height: 36)
                .background(Color.clear)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(maxWidth: 200)
        .fixedSize()
    }
}
