import SwiftUI

extension View {
    func numberInputAlert(
        title: String,
        message: String,
        isPresented: Binding<Bool>,
        inputValue: Binding<String>,
        onSave: ((Int) -> Void)? = nil
    ) -> some View {
        return alert(title, isPresented: isPresented) {
            TextField("Enter number", text: inputValue)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .onChange(of: inputValue.wrappedValue) { _, newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered != newValue {
                        inputValue.wrappedValue = filtered
                    }
                }

            Button("Save") {
                if let intValue = Int(inputValue.wrappedValue) {
                    onSave?(intValue)
                }
                isPresented.wrappedValue = false
            }

            Button("Cancel", role: .cancel) {
                isPresented.wrappedValue = false
            }
        } message: {
            Text(message)
        }
    }
}
