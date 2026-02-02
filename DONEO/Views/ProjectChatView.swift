import SwiftUI

struct ProjectChatView: View {
    @State private var viewModel: ProjectChatViewModel
    @State private var showingProjectInfo = false
    @State private var showingTaskDrawer = false
    @State private var showingAttachmentOptions = false
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(project: Project) {
        _viewModel = State(initialValue: ProjectChatViewModel(project: project))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Chat messages area
            chatMessagesArea

            // Referenced task/subtask/quote preview
            if viewModel.referencedTask != nil || viewModel.referencedSubtask != nil || viewModel.quotedMessage != nil {
                referencePreview
            }

            // Input toolbar
            inputToolbar
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                headerView
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showingTaskDrawer) {
            TaskDrawerSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingProjectInfo) {
            ProjectInfoView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingAttachmentOptions) {
            ProjectAttachmentSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header View (Project name + member count)

    private var headerView: some View {
        VStack(spacing: 1) {
            Text(viewModel.project.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text("\(viewModel.project.members.count) members")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Chat Messages Area

    private var chatMessagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if viewModel.messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(viewModel.messages) { message in
                            ProjectMessageBubble(
                                message: message,
                                onTaskTap: { taskRef in
                                    // Open task drawer and navigate to task
                                    if let task = viewModel.project.tasks.first(where: { $0.id == taskRef.taskId }) {
                                        viewModel.selectedTask = task
                                        showingTaskDrawer = true
                                    }
                                },
                                onSubtaskTap: { subtaskRef in
                                    viewModel.referencedSubtask = subtaskRef
                                    isInputFocused = true
                                },
                                onQuote: {
                                    viewModel.quoteMessage(message)
                                    isInputFocused = true
                                }
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding()
            }
            .background(Theme.chatBackground)
            .onChange(of: viewModel.messages.count) { _, _ in
                if let lastMessage = viewModel.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            Text("No messages yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Start chatting with your team")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)

            // Quick task button
            Button {
                showingTaskDrawer = true
            } label: {
                HStack {
                    Image(systemName: "checklist")
                    Text("View Tasks")
                }
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.primaryLight)
                .foregroundStyle(Theme.primary)
                .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Reference Preview

    private var referencePreview: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.primary)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                if let quoted = viewModel.quotedMessage {
                    Text("Replying to \(quoted.senderName)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(quoted.content)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                } else if let subtaskRef = viewModel.referencedSubtask {
                    Text("Referencing subtask")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(subtaskRef.subtaskTitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.primary)
                        .lineLimit(1)
                } else if let taskRef = viewModel.referencedTask {
                    Text("Referencing task")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(taskRef.taskTitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.primary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                viewModel.clearAllReferences()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    // MARK: - Input Toolbar

    private var inputToolbar: some View {
        HStack(spacing: 8) {
            // Attachment button (+)
            Button {
                showingAttachmentOptions = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.primary)
            }

            // Task button (checklist icon)
            Button {
                showingTaskDrawer = true
            } label: {
                Image(systemName: "checklist")
                    .font(.system(size: 22))
                    .foregroundStyle(showingTaskDrawer ? Theme.primary : .secondary)
            }

            // Text field
            TextField("Message", text: $viewModel.newMessageText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .focused($isInputFocused)
                .submitLabel(.send)
                .onSubmit {
                    viewModel.sendMessage()
                }

            // Camera button
            Button {
                // TODO: Open camera
            } label: {
                Image(systemName: "camera.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }

            // Mic button
            Button {
                // TODO: Record audio
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - Project Message Bubble

struct ProjectMessageBubble: View {
    let message: Message
    var onTaskTap: ((TaskReference) -> Void)? = nil
    var onSubtaskTap: ((SubtaskReference) -> Void)? = nil
    var onQuote: (() -> Void)? = nil

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        switch message.messageType {
        case .subtaskCompleted(let subtaskRef):
            subtaskStatusMessage(completed: true, subtaskRef: subtaskRef)
        case .subtaskReopened(let subtaskRef):
            subtaskStatusMessage(completed: false, subtaskRef: subtaskRef)
        case .regular:
            regularMessage
        }
    }

    private func subtaskStatusMessage(completed: Bool, subtaskRef: SubtaskReference) -> some View {
        HStack(spacing: 8) {
            Spacer()

            HStack(spacing: 6) {
                Image(systemName: completed ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(completed ? Theme.success : Theme.warning)

                Text(message.sender.displayFirstName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(completed ? "completed" : "reopened")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                Button {
                    onSubtaskTap?(subtaskRef)
                } label: {
                    Text("\"\(subtaskRef.subtaskTitle)\"")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(Capsule())

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var regularMessage: some View {
        HStack {
            // Reply indicator (appears on swipe)
            if dragOffset > 30 {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.primary)
                    .opacity(min(1.0, Double(dragOffset - 30) / 30.0))
            }

            if message.isFromCurrentUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                if !message.isFromCurrentUser {
                    Text(message.sender.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    // Quoted message
                    if let quoted = message.quotedMessage {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(message.isFromCurrentUser ? Color.white.opacity(0.5) : Theme.primary.opacity(0.5))
                                .frame(width: 3)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(quoted.senderName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.9) : Theme.primary)
                                Text(quoted.content)
                                    .font(.system(size: 12))
                                    .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.7) : .secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(8)
                        .background(
                            message.isFromCurrentUser
                                ? Color.white.opacity(0.15)
                                : Color(uiColor: .systemGray4)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Task reference badge
                    if let taskRef = message.referencedTask {
                        Button {
                            onTaskTap?(taskRef)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 10))
                                Text(taskRef.taskTitle)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.9) : Theme.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                message.isFromCurrentUser
                                    ? Color.white.opacity(0.2)
                                    : Theme.primaryLight
                            )
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    // Subtask reference badge (if different from task)
                    if let subtaskRef = message.referencedSubtask {
                        Button {
                            onSubtaskTap?(subtaskRef)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 10))
                                Text(subtaskRef.subtaskTitle)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.9) : Theme.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                message.isFromCurrentUser
                                    ? Color.white.opacity(0.2)
                                    : Theme.primaryLight
                            )
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    // Message content
                    Text(message.content)
                        .font(.system(size: 15))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    message.isFromCurrentUser
                    ? Theme.primary
                    : Color(uiColor: .systemGray5)
                )
                .foregroundStyle(message.isFromCurrentUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(message.timestamp, style: .time)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .offset(x: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width > 0 {
                            dragOffset = min(80, value.translation.width)
                        }
                    }
                    .onEnded { value in
                        if dragOffset > 50 {
                            onQuote?()
                        }
                        withAnimation(.spring(response: 0.3)) {
                            dragOffset = 0
                        }
                    }
            )

            if !message.isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Project Info View

struct ProjectInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ProjectChatViewModel

    var body: some View {
        NavigationStack {
            List {
                // Project header
                Section {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Theme.primaryLight)
                                .frame(width: 80, height: 80)
                            Text(viewModel.project.initials)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(Theme.primary)
                        }

                        Text(viewModel.project.name)
                            .font(.system(size: 20, weight: .bold))
                            .multilineTextAlignment(.center)

                        if let description = viewModel.project.description {
                            Text(description)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        // Task stats
                        HStack(spacing: 24) {
                            VStack {
                                Text("\(viewModel.pendingTasks.count)")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(Theme.primary)
                                Text("Pending")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }

                            VStack {
                                Text("\(viewModel.completedTasks.count)")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.green)
                                Text("Completed")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                // Notifications section
                Section {
                    Toggle(isOn: $viewModel.isMuted) {
                        Label("Mute Notifications", systemImage: "bell.slash")
                    }
                }

                // Members section
                Section {
                    ForEach(viewModel.project.members) { member in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Theme.primary)
                                    .frame(width: 40, height: 40)
                                Text(member.avatarInitials)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(member.name)
                                        .font(.system(size: 16))
                                    if member.id == viewModel.currentUser.id {
                                        Text("You")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Text(member.phoneNumber)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("\(viewModel.project.members.count) Members")
                }

                // Actions section
                Section {
                    Button {
                        // Export project
                    } label: {
                        Label("Export Project", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        // Copy link
                    } label: {
                        Label("Copy Link", systemImage: "link")
                    }
                }

                // Danger zone
                Section {
                    Button(role: .destructive) {
                        // Leave project
                    } label: {
                        Label("Leave Project", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Project Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Project Attachment Sheet

struct ProjectAttachmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: AttachmentTab = .photos
    @State private var selectedPhotos: Set<Int> = []

    enum AttachmentTab: String, CaseIterable {
        case photos = "Photos"
        case files = "Files"
        case contact = "Contact"

        var icon: String {
            switch self {
            case .photos: return "photo.fill"
            case .files: return "doc.fill"
            case .contact: return "person.crop.square.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Content based on selected tab
            tabContent

            // Tab bar
            tabBar
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                    .padding(8)
                    .background(Theme.primaryLight)
                    .clipShape(Circle())
            }

            Spacer()

            Text(headerTitle)
                .font(.system(size: 16, weight: .semibold))

            Spacer()

            // Send button (only show when photos selected)
            if !selectedPhotos.isEmpty {
                Button {
                    // Send selected photos
                    dismiss()
                } label: {
                    Text("Send (\(selectedPhotos.count))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.primary)
                        .clipShape(Capsule())
                }
            } else {
                Color.clear.frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var headerTitle: String {
        switch selectedTab {
        case .photos: return "Recents"
        case .files: return "Files"
        case .contact: return "Contacts"
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .photos:
            photosContent
        case .files:
            filesContent
        case .contact:
            contactContent
        }
    }

    // MARK: - Photos Content

    private var photosContent: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 2),
                GridItem(.flexible(), spacing: 2),
                GridItem(.flexible(), spacing: 2)
            ], spacing: 2) {
                // Camera button
                Button {
                    // Open camera
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "camera")
                            .font(.system(size: 32))
                            .foregroundStyle(Theme.primary)
                        Text("Camera")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .background(Color(uiColor: .systemBackground))
                }

                // Sample photos (placeholders with colors)
                ForEach(0..<11, id: \.self) { index in
                    photoCell(index: index)
                }
            }
        }
    }

    private func photoCell(index: Int) -> some View {
        let colors: [Color] = [
            Color(red: 0.85, green: 0.65, blue: 0.65),
            Color(red: 0.85, green: 0.78, blue: 0.65),
            Color(red: 0.85, green: 0.85, blue: 0.65),
            Color(red: 0.65, green: 0.85, blue: 0.65),
            Color(red: 0.65, green: 0.85, blue: 0.78),
            Color(red: 0.65, green: 0.78, blue: 0.85),
            Color(red: 0.78, green: 0.65, blue: 0.85)
        ]
        let color = colors[index % colors.count]
        let isSelected = selectedPhotos.contains(index)

        return Button {
            if isSelected {
                selectedPhotos.remove(index)
            } else {
                selectedPhotos.insert(index)
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Rectangle()
                    .fill(color)
                    .frame(height: 120)

                // Selection circle
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(isSelected ? Theme.primary : Color.clear)
                    )
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(8)
            }
        }
    }

    // MARK: - Files Content

    private var filesContent: some View {
        VStack(spacing: 16) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.primary.opacity(0.6))

                Text("Browse Files")
                    .font(.system(size: 18, weight: .semibold))

                Text("Select documents, PDFs, or other files")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    // Open file picker
                } label: {
                    Text("Choose File")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Theme.primary)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Contact Content

    private var contactContent: some View {
        VStack(spacing: 16) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.primary.opacity(0.6))

                Text("Share Contact")
                    .font(.system(size: 18, weight: .semibold))

                Text("Share a contact card with your team")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    // Open contact picker
                } label: {
                    Text("Choose Contact")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Theme.primary)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AttachmentTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 22))
                        Text(tab.rawValue)
                            .font(.system(size: 11))
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selectedTab == tab ? Theme.primary : .secondary)
                }
            }
        }
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

#Preview {
    NavigationStack {
        ProjectChatView(project: Project(
            name: "Downtown Renovation",
            members: MockDataService.allUsers,
            tasks: [
                DONEOTask(title: "Order materials", status: .pending),
                DONEOTask(title: "Schedule inspection", status: .done)
            ]
        ))
    }
}
