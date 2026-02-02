import SwiftUI

struct PhoneEntryView: View {
    @Binding var phoneNumber: String
    let onContinue: () -> Void
    @FocusState private var isPhoneFocused: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo/Title
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.primary)

                Text("DONEO")
                    .font(.system(size: 32, weight: .bold))

                Text("Work gets done here")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Phone input
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter your phone number")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("+1 (555) 000-0000", text: $phoneNumber)
                    .font(.system(size: 20))
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .focused($isPhoneFocused)
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Continue button
            Button(action: onContinue) {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        phoneNumber.filter { $0.isNumber }.count >= 10
                        ? Theme.primary
                        : Theme.primary.opacity(0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(phoneNumber.filter { $0.isNumber }.count < 10)

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, 24)
        .onAppear {
            isPhoneFocused = true
        }
    }
}

#Preview {
    PhoneEntryView(phoneNumber: .constant(""), onContinue: {})
}
