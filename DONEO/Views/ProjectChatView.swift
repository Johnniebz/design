import SwiftUI
import PhotosUI

struct ProjectChatView: View {
    @State private var viewModel: ProjectChatViewModel
    @State private var showingProjectInfo = false
    @State private var showingTaskDrawer = false
    @State private var showingAttachmentOptions = false
    @State private var showingNewTasksInbox = false
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
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.newTasksCount > 0 {
                    Button {
                        showingNewTasksInbox = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "tray.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Theme.primary)

                            // Badge
                            Text("\(viewModel.newTasksCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Theme.primary)
                                .clipShape(Capsule())
                                .offset(x: 8, y: -6)
                        }
                    }
                }
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
            ProjectAttachmentSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingNewTasksInbox) {
            ProjectNewTasksInboxSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header View (Project name + member count)

    private var headerView: some View {
        Button {
            showingProjectInfo = true
        } label: {
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
        .buttonStyle(.plain)
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

                    // Attachment preview
                    if let attachment = message.attachment {
                        attachmentPreview(attachment)
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

    @ViewBuilder
    private func attachmentPreview(_ attachment: MessageAttachment) -> some View {
        switch attachment.type {
        case .image:
            // Photo attachment
            HStack(spacing: 8) {
                Image(systemName: "photo.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.8) : Theme.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Photo")
                        .font(.system(size: 13, weight: .medium))
                    Text(attachment.fileName)
                        .font(.system(size: 11))
                        .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.7) : .secondary)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .background(
                message.isFromCurrentUser
                    ? Color.white.opacity(0.15)
                    : Color(uiColor: .systemGray4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))

        case .document:
            // Document attachment
            HStack(spacing: 8) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.8) : Theme.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.fileName)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    if attachment.fileSize > 0 {
                        Text(ByteCountFormatter.string(fromByteCount: attachment.fileSize, countStyle: .file))
                            .font(.system(size: 11))
                            .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.7) : .secondary)
                    }
                }

                Spacer()

                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.8) : Theme.primary)
            }
            .padding(10)
            .background(
                message.isFromCurrentUser
                    ? Color.white.opacity(0.15)
                    : Color(uiColor: .systemGray4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))

        case .video:
            // Video attachment
            HStack(spacing: 8) {
                Image(systemName: "video.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.8) : Theme.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Video")
                        .font(.system(size: 13, weight: .medium))
                    Text(attachment.fileName)
                        .font(.system(size: 11))
                        .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.7) : .secondary)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .background(
                message.isFromCurrentUser
                    ? Color.white.opacity(0.15)
                    : Color(uiColor: .systemGray4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))

        case .contact:
            // Contact attachment
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.8) : .green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Contact")
                        .font(.system(size: 13, weight: .medium))
                    Text(attachment.fileName)
                        .font(.system(size: 11))
                        .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.7) : .secondary)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .background(
                message.isFromCurrentUser
                    ? Color.white.opacity(0.15)
                    : Color(uiColor: .systemGray4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
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

                // Media & Documents section
                if !viewModel.project.attachments.isEmpty {
                    Section {
                        // Photos
                        let photos = viewModel.project.attachments.filter { $0.type == .image }
                        if !photos.isEmpty {
                            NavigationLink {
                                mediaListView(title: "Photos", attachments: photos)
                            } label: {
                                HStack {
                                    Label("Photos", systemImage: "photo.fill")
                                    Spacer()
                                    Text("\(photos.count)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // Documents
                        let documents = viewModel.project.attachments.filter { $0.type == .document }
                        if !documents.isEmpty {
                            NavigationLink {
                                mediaListView(title: "Documents", attachments: documents)
                            } label: {
                                HStack {
                                    Label("Documents", systemImage: "doc.fill")
                                    Spacer()
                                    Text("\(documents.count)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // Videos
                        let videos = viewModel.project.attachments.filter { $0.type == .video }
                        if !videos.isEmpty {
                            NavigationLink {
                                mediaListView(title: "Videos", attachments: videos)
                            } label: {
                                HStack {
                                    Label("Videos", systemImage: "video.fill")
                                    Spacer()
                                    Text("\(videos.count)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text("Media & Documents")
                    }
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

    // MARK: - Media List View

    private func mediaListView(title: String, attachments: [ProjectAttachment]) -> some View {
        List {
            // Group by task
            let grouped = Dictionary(grouping: attachments) { $0.linkedTaskId }

            ForEach(Array(grouped.keys), id: \.self) { taskId in
                Section {
                    ForEach(grouped[taskId] ?? []) { attachment in
                        mediaRow(attachment)
                    }
                } header: {
                    if let taskId = taskId,
                       let task = viewModel.project.tasks.first(where: { $0.id == taskId }) {
                        Label(task.title, systemImage: "checklist")
                    } else {
                        Text("General")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func mediaRow(_ attachment: ProjectAttachment) -> some View {
        HStack(spacing: 12) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.primaryLight)
                    .frame(width: 50, height: 50)

                Image(systemName: attachment.iconName)
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.primary)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(attachment.fileName)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(attachment.uploadedBy.displayFirstName)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Text(attachment.uploadedAt, style: .date)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    if attachment.fileSize > 0 {
                        Text(attachment.fileSizeFormatted)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Project Attachment Sheet

struct ProjectAttachmentSheet: View {
    @Bindable var viewModel: ProjectChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: AttachmentTab = .photos
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var loadedImages: [UIImage] = []
    @State private var selectedFiles: [(url: URL, name: String, size: Int64)] = []
    @State private var showingUploadDetails = false
    @State private var showingFilePicker = false

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
        .sheet(isPresented: $showingUploadDetails) {
            AttachmentUploadSheet(
                viewModel: viewModel,
                selectedImages: loadedImages,
                selectedFiles: selectedFiles
            ) {
                selectedPhotoItems = []
                loadedImages = []
                selectedFiles = []
                dismiss()
            }
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

            // Next/Send button (only show when photos selected)
            if !selectedPhotoItems.isEmpty {
                Button {
                    showingUploadDetails = true
                } label: {
                    Text("Next (\(selectedPhotoItems.count))")
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
        VStack(spacing: 0) {
            // Selected photos preview
            if !loadedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(loadedImages.indices, id: \.self) { index in
                            Image(uiImage: loadedImages[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        loadedImages.remove(at: index)
                                        if index < selectedPhotoItems.count {
                                            selectedPhotoItems.remove(at: index)
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(.white)
                                            .shadow(radius: 2)
                                    }
                                    .padding(4)
                                }
                        }
                    }
                    .padding()
                }
                .background(Color(uiColor: .secondarySystemBackground))
            }

            // PhotosPicker
            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: 10,
                matching: .images,
                photoLibrary: .shared()
            ) {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.primary.opacity(0.6))

                    Text("Select Photos")
                        .font(.system(size: 18, weight: .semibold))

                    Text("Choose photos from your library")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 16))
                        Text(selectedPhotoItems.isEmpty ? "Tap to select" : "\(selectedPhotoItems.count) selected")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.primary)
                    .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                loadImages(from: newItems)
            }
        }
    }

    private func loadImages(from items: [PhotosPickerItem]) {
        loadedImages = []
        for item in items {
            item.loadTransferable(type: Data.self) { result in
                switch result {
                case .success(let data):
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            if !loadedImages.contains(where: { $0.pngData() == image.pngData() }) {
                                loadedImages.append(image)
                            }
                        }
                    }
                case .failure:
                    break
                }
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
                    showingFilePicker = true
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
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.pdf, .text, .data, .spreadsheet, .presentation],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                // Store selected files and show upload sheet for tagging
                selectedFiles = urls.compactMap { url in
                    let accessing = url.startAccessingSecurityScopedResource()
                    let fileName = url.lastPathComponent
                    let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                    return (url: url, name: fileName, size: fileSize)
                }
                // Show upload sheet for tagging
                if !selectedFiles.isEmpty {
                    showingUploadDetails = true
                }
            case .failure:
                break
            }
        }
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

// MARK: - Attachment Upload Sheet (Link to Task)

struct AttachmentUploadSheet: View {
    @Bindable var viewModel: ProjectChatViewModel
    let selectedImages: [UIImage]
    let selectedFiles: [(url: URL, name: String, size: Int64)]
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTaskId: UUID? = nil
    @State private var selectedSubtaskId: UUID? = nil
    @State private var caption: String = ""

    var selectedCount: Int { selectedImages.count + selectedFiles.count }
    var hasImages: Bool { !selectedImages.isEmpty }
    var hasFiles: Bool { !selectedFiles.isEmpty }

    private var selectedTask: DONEOTask? {
        viewModel.project.tasks.first { $0.id == selectedTaskId }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Selected")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                // Show images
                                ForEach(selectedImages.indices.prefix(4), id: \.self) { index in
                                    Image(uiImage: selectedImages[index])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }

                                // Show files
                                ForEach(selectedFiles.indices.prefix(4), id: \.self) { index in
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Theme.primaryLight)
                                        .frame(width: 60, height: 60)
                                        .overlay {
                                            VStack(spacing: 2) {
                                                Image(systemName: "doc.fill")
                                                    .font(.system(size: 20))
                                                    .foregroundStyle(Theme.primary)
                                                Text(selectedFiles[index].name)
                                                    .font(.system(size: 8))
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                            .padding(4)
                                        }
                                }

                                if selectedCount > 4 {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(uiColor: .secondarySystemBackground))
                                        .frame(width: 60, height: 60)
                                        .overlay {
                                            Text("+\(selectedCount - 4)")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(.secondary)
                                        }
                                }
                            }
                        }
                    }

                    // Link to task (optional)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Link to task")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("(optional)")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }

                        // Task picker
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                // No link option
                                Button {
                                    selectedTaskId = nil
                                    selectedSubtaskId = nil
                                } label: {
                                    Text("None")
                                        .font(.system(size: 14, weight: .medium))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(selectedTaskId == nil ? Theme.primary : Color(uiColor: .secondarySystemBackground))
                                        .foregroundStyle(selectedTaskId == nil ? .white : .primary)
                                        .clipShape(Capsule())
                                }

                                ForEach(viewModel.project.tasks) { task in
                                    Button {
                                        selectedTaskId = task.id
                                        selectedSubtaskId = nil
                                    } label: {
                                        Text(task.title)
                                            .font(.system(size: 14, weight: .medium))
                                            .lineLimit(1)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(selectedTaskId == task.id ? Theme.primary : Color(uiColor: .secondarySystemBackground))
                                            .foregroundStyle(selectedTaskId == task.id ? .white : .primary)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }

                    // Link to subtask (if task selected)
                    if let task = selectedTask, !task.subtasks.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Link to subtask")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text("(optional)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    Button {
                                        selectedSubtaskId = nil
                                    } label: {
                                        Text("None")
                                            .font(.system(size: 14, weight: .medium))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(selectedSubtaskId == nil ? Theme.primary : Color(uiColor: .secondarySystemBackground))
                                            .foregroundStyle(selectedSubtaskId == nil ? .white : .primary)
                                            .clipShape(Capsule())
                                    }

                                    ForEach(task.subtasks) { subtask in
                                        Button {
                                            selectedSubtaskId = subtask.id
                                        } label: {
                                            Text(subtask.title)
                                                .font(.system(size: 14, weight: .medium))
                                                .lineLimit(1)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(selectedSubtaskId == subtask.id ? Theme.primary : Color(uiColor: .secondarySystemBackground))
                                                .foregroundStyle(selectedSubtaskId == subtask.id ? .white : .primary)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Caption
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Caption")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("(optional)")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }

                        TextField("Add a description...", text: $caption, axis: .vertical)
                            .font(.system(size: 15))
                            .lineLimit(2...4)
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle("Add Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        // Create attachment items from images
                        var items: [(type: AttachmentType, fileName: String, fileSize: Int64, fileURL: URL?)] = selectedImages.enumerated().map { index, _ in
                            (type: .image, fileName: "Photo_\(Date().timeIntervalSince1970)_\(index).jpg", fileSize: 0, fileURL: nil)
                        }

                        // Add file items
                        items += selectedFiles.map { file in
                            (type: .document, fileName: file.name, fileSize: file.size, fileURL: file.url)
                        }

                        viewModel.addAttachments(
                            items: items,
                            linkedTaskId: selectedTaskId,
                            linkedSubtaskId: selectedSubtaskId,
                            caption: caption.isEmpty ? nil : caption
                        )

                        dismiss()
                        onComplete()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedCount == 0)
                }
            }
        }
    }
}

// MARK: - New Tasks Inbox Sheet

struct ProjectNewTasksInboxSheet: View {
    @Bindable var viewModel: ProjectChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTask: DONEOTask?
    @State private var showTaskDetail = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.newTasksForCurrentUser.isEmpty {
                    ContentUnavailableView(
                        "All Caught Up",
                        systemImage: "tray",
                        description: Text("No new task assignments")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(viewModel.newTasksForCurrentUser) { task in
                                NewTaskInboxRow(task: task) {
                                    selectedTask = task
                                    showTaskDetail = true
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("New Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showTaskDetail) {
                if let task = selectedTask {
                    NewTaskInboxDetailSheet(
                        task: task,
                        projectName: viewModel.project.name,
                        viewModel: viewModel,
                        onAction: { action, message in
                            switch action {
                            case .accept:
                                viewModel.acceptTask(task, message: message)
                            case .decline:
                                viewModel.declineTask(task, reason: message ?? "I can't take this on")
                            case .ask:
                                if let msg = message, !msg.isEmpty {
                                    viewModel.sendTaskQuestion(task, message: msg)
                                }
                            }
                            showTaskDetail = false
                            selectedTask = nil
                        },
                        onCancel: {
                            showTaskDetail = false
                            selectedTask = nil
                        }
                    )
                }
            }
        }
    }
}

// MARK: - New Task Inbox Row

struct NewTaskInboxRow: View {
    let task: DONEOTask
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Blue indicator dot
                Circle()
                    .fill(Theme.primary)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(task.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if task.isOverdue {
                            Text("OVERDUE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.red)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        } else if task.isDueToday {
                            Text("TODAY")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }

                    HStack(spacing: 6) {
                        if let createdBy = task.createdBy {
                            Text("from \(createdBy.displayFirstName)")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        if let dueDate = task.dueDate, !task.isOverdue && !task.isDueToday {
                            if task.createdBy != nil {
                                Text("•")
                                    .foregroundStyle(.tertiary)
                            }
                            Text(formatDueDate(dueDate))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        if !task.subtasks.isEmpty {
                            if task.createdBy != nil || task.dueDate != nil {
                                Text("•")
                                    .foregroundStyle(.tertiary)
                            }
                            HStack(spacing: 3) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 10))
                                Text("\(task.subtasks.count)")
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(uiColor: .systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func formatDueDate(_ date: Date) -> String {
        if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }
}

// MARK: - New Task Inbox Detail Sheet

struct NewTaskInboxDetailSheet: View {
    let task: DONEOTask
    let projectName: String
    @Bindable var viewModel: ProjectChatViewModel
    let onAction: (NewTaskAction, String?) -> Void
    let onCancel: () -> Void

    @State private var messageText = ""
    @State private var selectedAction: NewTaskAction = .accept

    enum NewTaskAction {
        case accept, decline, ask
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Task header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(task.title)
                            .font(.system(size: 20, weight: .semibold))

                        HStack(spacing: 8) {
                            if let createdBy = task.createdBy {
                                Label("from \(createdBy.displayFirstName)", systemImage: "person")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }

                            if let dueDate = task.dueDate {
                                Label(dueDate.formatted(.dateTime.month(.abbreviated).day()), systemImage: "calendar")
                                    .font(.system(size: 13))
                                    .foregroundStyle(task.isOverdue ? .red : (task.isDueToday ? .orange : .secondary))
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Notes section
                    if let notes = task.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Notes", systemImage: "doc.text")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)

                            Text(notes)
                                .font(.system(size: 15))
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Subtasks section
                    if !task.subtasks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("\(task.subtasks.count) Subtasks", systemImage: "checklist")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)

                            ForEach(task.subtasks) { subtask in
                                HStack(spacing: 8) {
                                    Image(systemName: "circle")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.tertiary)
                                    Text(subtask.title)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Response section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Response")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)

                        // Action picker
                        Picker("Action", selection: $selectedAction) {
                            Text("Accept").tag(NewTaskAction.accept)
                            Text("Decline").tag(NewTaskAction.decline)
                            Text("Ask").tag(NewTaskAction.ask)
                        }
                        .pickerStyle(.segmented)

                        // Message field
                        TextField(placeholderText, text: $messageText, axis: .vertical)
                            .lineLimit(3...6)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(projectName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(actionButtonText) {
                        onAction(selectedAction, messageText.isEmpty ? nil : messageText)
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(actionButtonColor)
                    .disabled(selectedAction == .ask && messageText.isEmpty)
                }
            }
        }
    }

    private var placeholderText: String {
        switch selectedAction {
        case .accept: return "Add a message (optional)"
        case .decline: return "Reason for declining (optional)"
        case .ask: return "What would you like to ask?"
        }
    }

    private var actionButtonText: String {
        switch selectedAction {
        case .accept: return "Accept"
        case .decline: return "Decline"
        case .ask: return "Send"
        }
    }

    private var actionButtonColor: Color {
        switch selectedAction {
        case .accept: return .green
        case .decline: return .red
        case .ask: return Theme.primary
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
