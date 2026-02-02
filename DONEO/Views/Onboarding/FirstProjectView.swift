import SwiftUI

struct FirstProjectView: View {
    @Binding var projectName: String
    @Binding var projectDescription: String
    let onCreateProject: () -> Void
    let onSkip: () -> Void
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.primary)

                Text("Create your first project")
                    .font(.system(size: 24, weight: .bold))

                Text("Projects help you organize work by job site, client, or team")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Project name input
            VStack(alignment: .leading, spacing: 8) {
                Text("Project name")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("e.g. Kitchen Renovation", text: $projectName)
                    .font(.system(size: 20))
                    .focused($isNameFocused)
                    .submitLabel(.next)
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Project description input
            VStack(alignment: .leading, spacing: 8) {
                Text("Description (Optional)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("What is this project about?", text: $projectDescription, axis: .vertical)
                    .font(.system(size: 17))
                    .lineLimit(2...4)
                    .submitLabel(.done)
                    .onSubmit {
                        if !projectName.trimmingCharacters(in: .whitespaces).isEmpty {
                            onCreateProject()
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Create button
            Button(action: onCreateProject) {
                Text("Create Project")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        projectName.trimmingCharacters(in: .whitespaces).isEmpty
                        ? Theme.primary.opacity(0.5)
                        : Theme.primary
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(projectName.trimmingCharacters(in: .whitespaces).isEmpty)

            // Skip option
            Button(action: onSkip) {
                Text("Skip for now")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, 24)
        .onAppear {
            isNameFocused = true
        }
    }
}

#Preview {
    FirstProjectView(projectName: .constant(""), projectDescription: .constant(""), onCreateProject: {}, onSkip: {})
}
