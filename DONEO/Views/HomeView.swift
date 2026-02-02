import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var showingNewProjectSheet = false

    var body: some View {
        List {
            ForEach(viewModel.filteredProjects) { project in
                NavigationLink(value: project) {
                    ProjectCardView(project: project)
                }
            }
            .onDelete(perform: deleteProjects)
        }
        .listStyle(.plain)
        .navigationTitle("Projects")
        .searchable(text: $viewModel.searchText, prompt: "Search projects")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewProjectSheet = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
            }
        }
        .navigationDestination(for: Project.self) { project in
            ProjectChatView(project: project)
        }
        .sheet(isPresented: $showingNewProjectSheet) {
            NewProjectFlowView { projectName, description, selectedContacts, pendingInvites in
                viewModel.createProject(
                    name: projectName,
                    description: description,
                    selectedContacts: selectedContacts,
                    pendingInvites: pendingInvites
                )
            }
        }
        .overlay {
            if viewModel.filteredProjects.isEmpty && !viewModel.searchText.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else if viewModel.projects.isEmpty {
                ContentUnavailableView(
                    "No Projects Yet",
                    systemImage: "folder",
                    description: Text("Tap + to create your first project")
                )
            }
        }
    }

    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            let project = viewModel.filteredProjects[index]
            viewModel.deleteProject(project)
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(MockDataService.shared.currentUser.name)
                            .font(.system(size: 17, weight: .semibold))
                        Text(MockDataService.shared.currentUser.phoneNumber)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Label("Notifications", systemImage: "bell")
                Label("Privacy", systemImage: "lock")
                Label("Storage", systemImage: "internaldrive")
            }

            Section {
                Label("Help", systemImage: "questionmark.circle")
                Label("About", systemImage: "info.circle")
            }
        }
        .navigationTitle("Settings")
    }
}

// MARK: - Contact Model

struct Contact: Identifiable {
    let id = UUID()
    let name: String
    let phoneNumber: String
    let isOnDONEO: Bool

    var initials: String {
        let parts = name.components(separatedBy: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Mock Contacts

struct MockContacts {
    static let all: [Contact] = [
        // On DONEO
        Contact(name: "Maria Garcia", phoneNumber: "+1 555-0101", isOnDONEO: true),
        Contact(name: "James Wilson", phoneNumber: "+1 555-0102", isOnDONEO: true),
        Contact(name: "Sarah Chen", phoneNumber: "+1 555-0103", isOnDONEO: true),
        Contact(name: "Mike Thompson", phoneNumber: "+1 555-0104", isOnDONEO: true),
        // Not on DONEO
        Contact(name: "David Brown", phoneNumber: "+1 555-0201", isOnDONEO: false),
        Contact(name: "Emma Davis", phoneNumber: "+1 555-0202", isOnDONEO: false),
        Contact(name: "Carlos Rodriguez", phoneNumber: "+1 555-0203", isOnDONEO: false),
        Contact(name: "Lisa Wang", phoneNumber: "+1 555-0204", isOnDONEO: false),
        Contact(name: "John Smith", phoneNumber: "+1 555-0205", isOnDONEO: false),
        Contact(name: "Anna Martinez", phoneNumber: "+1 555-0206", isOnDONEO: false),
        Contact(name: "Robert Lee", phoneNumber: "+1 555-0207", isOnDONEO: false),
        Contact(name: "Jennifer Taylor", phoneNumber: "+1 555-0208", isOnDONEO: false),
    ]

    static var onDONEO: [Contact] {
        all.filter { $0.isOnDONEO }
    }

    static var notOnDONEO: [Contact] {
        all.filter { !$0.isOnDONEO }
    }
}

// MARK: - New Project Flow

struct NewProjectFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var step: FlowStep = .selectMembers
    @State private var selectedContacts: Set<UUID> = []
    @State private var pendingInvites: [PendingInvite] = []
    @State private var searchText = ""
    @State private var projectName = ""
    @State private var projectDescription = ""
    @State private var showingQRCode = false
    @State private var showingAddByPhone = false

    let onCreate: (String, String?, [Contact], [PendingInvite]) -> Void

    enum FlowStep {
        case selectMembers
        case projectDetails
    }

    struct PendingInvite: Identifiable {
        let id = UUID()
        let phoneNumber: String
        let name: String?
    }

    var filteredContacts: [Contact] {
        if searchText.isEmpty {
            return MockContacts.all
        }
        return MockContacts.all.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.phoneNumber.contains(searchText)
        }
    }

    var contactsOnDONEO: [Contact] {
        filteredContacts.filter { $0.isOnDONEO }
    }

    var contactsNotOnDONEO: [Contact] {
        filteredContacts.filter { !$0.isOnDONEO }
    }

    var selectedCount: Int {
        selectedContacts.count + pendingInvites.count
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .selectMembers:
                    selectMembersView
                case .projectDetails:
                    projectDetailsView
                }
            }
            .navigationTitle(step == .selectMembers ? "Add Members" : "New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if step == .selectMembers {
                        Button("Next") {
                            withAnimation {
                                step = .projectDetails
                            }
                        }
                        .fontWeight(.semibold)
                    } else {
                        Button("Create") {
                            let selectedContactsList = MockContacts.all.filter { selectedContacts.contains($0.id) }
                            let description = projectDescription.trimmingCharacters(in: .whitespaces).isEmpty ? nil : projectDescription
                            onCreate(projectName, description, selectedContactsList, pendingInvites)
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .disabled(projectName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .sheet(isPresented: $showingQRCode) {
            QRInviteView()
        }
        .sheet(isPresented: $showingAddByPhone) {
            AddByPhoneView { phoneNumber, name in
                pendingInvites.append(PendingInvite(phoneNumber: phoneNumber, name: name))
            }
        }
    }

    // MARK: - Select Members View

    private var selectMembersView: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Text("To:")
                    .foregroundStyle(.secondary)
                TextField("Search name or number", text: $searchText)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemBackground))

            // Selected contacts chips
            if !selectedContacts.isEmpty || !pendingInvites.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MockContacts.all.filter { selectedContacts.contains($0.id) }) { contact in
                            selectedChip(name: contact.name) {
                                selectedContacts.remove(contact.id)
                            }
                        }
                        ForEach(pendingInvites) { invite in
                            selectedChip(name: invite.name ?? invite.phoneNumber, isPending: true) {
                                pendingInvites.removeAll { $0.id == invite.id }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(uiColor: .secondarySystemBackground))
            }

            List {
                // Invite options section
                Section {
                    Button {
                        showingQRCode = true
                    } label: {
                        Label("Invite via QR Code", systemImage: "qrcode")
                    }

                    Button {
                        shareInviteLink()
                    } label: {
                        Label("Share Invite Link", systemImage: "link")
                    }

                    Button {
                        showingAddByPhone = true
                    } label: {
                        Label("Add by Phone Number", systemImage: "phone.badge.plus")
                    }
                }

                // Contacts on DONEO
                if !contactsOnDONEO.isEmpty {
                    Section {
                        ForEach(contactsOnDONEO) { contact in
                            contactRow(contact: contact)
                        }
                    } header: {
                        Text("On DONEO")
                    }
                }

                // Contacts not on DONEO (will be invited)
                if !contactsNotOnDONEO.isEmpty {
                    Section {
                        ForEach(contactsNotOnDONEO) { contact in
                            contactRow(contact: contact, showInviteBadge: true)
                        }
                    } header: {
                        Text("Invite to DONEO")
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private func contactRow(contact: Contact, showInviteBadge: Bool = false) -> some View {
        Button {
            if selectedContacts.contains(contact.id) {
                selectedContacts.remove(contact.id)
            } else {
                selectedContacts.insert(contact.id)
            }
        } label: {
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(Theme.primary)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(contact.initials)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(contact.name)
                            .font(.system(size: 16))
                            .foregroundStyle(.primary)

                        if showInviteBadge {
                            Text("Invite")
                                .font(.system(size: 11))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }
                    }
                    Text(contact.phoneNumber)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Selection indicator
                Circle()
                    .strokeBorder(selectedContacts.contains(contact.id) ? Color.clear : Color.gray.opacity(0.3), lineWidth: 2)
                    .background(
                        Circle()
                            .fill(selectedContacts.contains(contact.id) ? Color.green : Color.clear)
                    )
                    .frame(width: 24, height: 24)
                    .overlay {
                        if selectedContacts.contains(contact.id) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
            }
            .padding(.vertical, 4)
        }
    }

    private func selectedChip(name: String, isPending: Bool = false, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(name.components(separatedBy: " ").first ?? name)
                .font(.system(size: 14))
            if isPending {
                Image(systemName: "clock")
                    .font(.system(size: 10))
            }
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isPending ? Color.orange.opacity(0.2) : Theme.primaryLight)
        .clipShape(Capsule())
    }

    private func shareInviteLink() {
        let inviteLink = "https://doneo.app/invite/abc123"
        let activityVC = UIActivityViewController(activityItems: [inviteLink], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    // MARK: - Project Details View

    private var projectDetailsView: some View {
        VStack(spacing: 20) {
            // Selected members summary
            if selectedCount > 0 {
                HStack {
                    Text("\(selectedCount) member\(selectedCount == 1 ? "" : "s") selected")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Edit") {
                        withAnimation {
                            step = .selectMembers
                        }
                    }
                    .font(.system(size: 14))
                }
                .padding(.horizontal)
            }

            // Project name field
            VStack(alignment: .leading, spacing: 8) {
                Text("Project Name")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("Enter project name", text: $projectName)
                    .font(.system(size: 17))
                    .padding(12)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal)

            // Project description field
            VStack(alignment: .leading, spacing: 8) {
                Text("Description (Optional)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("What is this project about?", text: $projectDescription, axis: .vertical)
                    .font(.system(size: 17))
                    .lineLimit(3...6)
                    .padding(12)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top)
    }
}

// MARK: - QR Invite View

struct QRInviteView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Scan to Join Project")
                    .font(.system(size: 20, weight: .semibold))

                // QR Code placeholder
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemBackground))
                    .frame(width: 200, height: 200)
                    .overlay {
                        Image(systemName: "qrcode")
                            .font(.system(size: 100))
                            .foregroundStyle(.secondary)
                    }

                Text("Others can scan this QR code to join the project")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Divider()
                    .padding(.vertical)

                Button {
                    // Open camera to scan QR
                } label: {
                    Label("Scan QR Code", systemImage: "camera")
                        .font(.system(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.primary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 40)

                Spacer()
            }
            .padding(.top, 40)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Add By Phone View

struct AddByPhoneView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var phoneNumber = ""
    @State private var name = ""
    @FocusState private var isPhoneFocused: Bool

    let onAdd: (String, String?) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Phone Number")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextField("+1 555-0000", text: $phoneNumber)
                        .font(.system(size: 17))
                        .keyboardType(.phonePad)
                        .padding(12)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .focused($isPhoneFocused)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Name (Optional)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextField("Contact name", text: $name)
                        .font(.system(size: 17))
                        .padding(12)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Text("An SMS invite will be sent to this number when the project is created.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                Spacer()
            }
            .padding()
            .navigationTitle("Add by Phone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(phoneNumber, name.isEmpty ? nil : name)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                isPhoneFocused = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
