import SwiftUI

struct ProjectDetailView: View {
    @State private var viewModel: ProjectDetailViewModel
    @State private var showingProjectInfo = false

    init(project: Project) {
        _viewModel = State(initialValue: ProjectDetailViewModel(project: project))
    }

    var body: some View {
        TaskListView(viewModel: viewModel)
            .navigationDestination(for: DONEOTask.self) { task in
                TaskDetailView(
                    task: task,
                    members: viewModel.project.members,
                    allProjectTasks: viewModel.project.tasks
                )
                .onAppear {
                    viewModel.markTaskAsRead(task)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button {
                        showingProjectInfo = true
                    } label: {
                        VStack(spacing: 0) {
                            Text(viewModel.project.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text("\(viewModel.project.members.count) members")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingProjectInfo) {
                ProjectInfoView(project: $viewModel.project)
            }
    }
}

// MARK: - Project Info View

struct ProjectInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var project: Project
    @State private var showingAddMembers = false

    var body: some View {
        NavigationStack {
            List {
                // Header section
                Section {
                    VStack(spacing: 12) {
                        // Project avatar
                        Circle()
                            .fill(Theme.primaryLight)
                            .frame(width: 80, height: 80)
                            .overlay {
                                Text(project.initials)
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(Theme.primary)
                            }

                        // Project name
                        Text(project.name)
                            .font(.system(size: 22, weight: .bold))

                        // Description (if exists)
                        if let description = project.description, !description.isEmpty {
                            Text(description)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        // Member count
                        Text("Project · \(project.members.count) members")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                // Description section
                Section {
                    if let description = project.description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 15))
                            .foregroundStyle(.primary)
                    } else {
                        Button {
                            // Add description
                        } label: {
                            Text("Add project description")
                                .foregroundStyle(Theme.primary)
                        }
                    }
                }

                // Media, links and docs
                Section {
                    NavigationLink {
                        MediaLinksDocsView()
                    } label: {
                        Label("Media, links and docs", systemImage: "photo.on.rectangle")
                    }
                }

                // Settings section
                Section {
                    HStack {
                        Label("Mute", systemImage: "bell.slash")
                        Spacer()
                        Text("No")
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Notifications", systemImage: "message")
                        Spacer()
                        Text("All")
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                // Members section
                Section {
                    ForEach(project.members) { member in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(avatarColor(for: member.name))
                                .frame(width: 40, height: 40)
                                .overlay {
                                    Text(memberInitials(member.name))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white)
                                }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.name)
                                    .font(.system(size: 16))
                                Text(member.phoneNumber)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }

                    Button {
                        showingAddMembers = true
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Theme.primaryLight)
                                .frame(width: 40, height: 40)
                                .overlay {
                                    Image(systemName: "person.badge.plus")
                                        .foregroundStyle(Theme.primary)
                                }

                            Text("Add Members")
                                .foregroundStyle(Theme.primary)
                        }
                    }
                } header: {
                    Text("\(project.members.count) Members")
                }

                // Actions section
                Section {
                    Button {
                        // Add to favorites
                    } label: {
                        Text("Add to Favorites")
                            .foregroundStyle(.primary)
                    }

                    Button {
                        // Export project
                    } label: {
                        Text("Export Project")
                            .foregroundStyle(Theme.primary)
                    }
                }

                // Danger zone
                Section {
                    Button(role: .destructive) {
                        // Exit project
                    } label: {
                        Text("Exit Project")
                    }

                    Button(role: .destructive) {
                        // Report project
                    } label: {
                        Text("Report Project")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.primary)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") {
                        // Edit project
                    }
                }
            }
            .sheet(isPresented: $showingAddMembers) {
                AddMembersView(project: $project)
            }
        }
    }

    private func avatarColor(for name: String) -> Color {
        Theme.primary
    }

    private func memberInitials(_ name: String) -> String {
        let parts = name.components(separatedBy: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Add Members View

struct AddMembersView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var project: Project
    @State private var searchText = ""
    @State private var selectedContacts: Set<UUID> = []

    var filteredContacts: [Contact] {
        let existingPhones = Set(project.members.map { $0.phoneNumber })
        let available = MockContacts.all.filter { !existingPhones.contains($0.phoneNumber) }

        if searchText.isEmpty {
            return available
        }
        return available.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.phoneNumber.contains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search contacts", text: $searchText)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemBackground))

                List {
                    ForEach(filteredContacts) { contact in
                        Button {
                            if selectedContacts.contains(contact.id) {
                                selectedContacts.remove(contact.id)
                            } else {
                                selectedContacts.insert(contact.id)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(avatarColor(for: contact.name))
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

                                        if !contact.isOnDONEO {
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
                }
                .listStyle(.plain)
            }
            .navigationTitle("Add Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addSelectedMembers()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedContacts.isEmpty)
                }
            }
        }
    }

    private func addSelectedMembers() {
        for contact in MockContacts.all where selectedContacts.contains(contact.id) {
            if contact.isOnDONEO {
                if let user = MockDataService.allUsers.first(where: { $0.phoneNumber == contact.phoneNumber }) {
                    if !project.members.contains(where: { $0.id == user.id }) {
                        project.members.append(user)
                    }
                }
            }
        }
        MockDataService.shared.updateProject(project)
    }

    private func avatarColor(for name: String) -> Color {
        Theme.primary
    }
}

// MARK: - Media, Links and Docs View

struct MediaLinksDocsView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("", selection: $selectedTab) {
                Text("Media").tag(0)
                Text("Links").tag(1)
                Text("Docs").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            // Content
            TabView(selection: $selectedTab) {
                // Media tab
                ContentUnavailableView(
                    "No Media",
                    systemImage: "photo.on.rectangle",
                    description: Text("Photos and videos shared in this project will appear here")
                )
                .tag(0)

                // Links tab
                ContentUnavailableView(
                    "No Links",
                    systemImage: "link",
                    description: Text("Links shared in this project will appear here")
                )
                .tag(1)

                // Docs tab
                ContentUnavailableView(
                    "No Documents",
                    systemImage: "doc",
                    description: Text("Documents shared in this project will appear here")
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle("Media, links and docs")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ProjectDetailView(project: Project(
            name: "Downtown Renovation",
            tasks: [
                DONEOTask(title: "Order materials", status: .pending),
                DONEOTask(title: "Schedule inspection", status: .done)
            ]
        ))
    }
}
