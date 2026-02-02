import SwiftUI

struct TaskDetailView: View {
    @State private var viewModel: TaskDetailViewModel
    @State private var showingTaskInfo = false
    @Environment(\.dismiss) private var dismiss

    init(task: DONEOTask, members: [User], allProjectTasks: [DONEOTask] = []) {
        _viewModel = State(initialValue: TaskDetailViewModel(task: task, members: members, allProjectTasks: allProjectTasks))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Members header (like WhatsApp)
            membersHeader

            // Top section: Task info + Subtasks (scrollable)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Task header
                    taskHeader

                    // Subtasks section (only shown if there are subtasks)
                    if !viewModel.task.subtasks.isEmpty {
                        subtasksSummary
                    }
                }
                .padding()
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.30)
            .background(Color(uiColor: .systemBackground))

            // Bottom section: Chat (takes remaining space)
            TaskChatView(viewModel: viewModel)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingTaskInfo) {
            TaskInfoView(viewModel: viewModel)
        }
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Members Header (Tappable to open Task Info)

    private var membersHeader: some View {
        Button {
            showingTaskInfo = true
        } label: {
            HStack(spacing: 10) {
                // Show member avatars
                HStack(spacing: -8) {
                    ForEach(viewModel.members.prefix(4)) { member in
                        ZStack {
                            Circle()
                                .fill(Theme.primaryLight)
                                .frame(width: 36, height: 36)
                            Text(member.avatarInitials)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.primary)
                        }
                        .overlay(
                            Circle()
                                .stroke(Color(uiColor: .systemBackground), lineWidth: 2)
                        )
                    }
                }

                // Members text - show all member names
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.members.map { $0.displayFirstName }.joined(separator: ", "))
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("Tap for task info")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemBackground))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Task Header

    private var taskHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                viewModel.toggleTaskStatus()
            } label: {
                Image(systemName: viewModel.task.status == .done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28))
                    .foregroundStyle(viewModel.task.status == .done ? .green : .secondary)
            }
            .buttonStyle(.plain)

            Text(viewModel.task.title)
                .font(.system(size: 18, weight: .semibold))
                .strikethrough(viewModel.task.status == .done)
                .foregroundStyle(viewModel.task.status == .done ? .secondary : .primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Subtasks Summary (managed via + menu, swipe to delete)

    private var subtasksSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with progress
            HStack {
                Image(systemName: "checklist")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Text("Subtasks")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(viewModel.task.subtasks.filter { $0.isDone }.count)/\(viewModel.task.subtasks.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.primary)
            }

            // Subtask list with swipe to delete
            VStack(spacing: 2) {
                ForEach(viewModel.task.subtasks) { subtask in
                    SubtaskItemRow(
                        subtask: subtask,
                        canEdit: viewModel.canEditSubtask(subtask),
                        members: viewModel.members,
                        onToggle: { viewModel.toggleSubtask(subtask) },
                        onDelete: { viewModel.deleteSubtask(subtask) },
                        onUpdateTitle: { newTitle in viewModel.updateSubtask(subtask, newTitle: newTitle) },
                        onUpdateDescription: { desc in viewModel.updateSubtaskDescription(subtask, description: desc) },
                        onToggleAssignee: { member in viewModel.toggleSubtaskAssignee(subtask, member: member) }
                    )
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

}

// MARK: - Subtask Item Row (tap to open detail, swipe to delete)

struct SubtaskItemRow: View {
    let subtask: Subtask
    let canEdit: Bool
    let members: [User]
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onUpdateTitle: (String) -> Void
    let onUpdateDescription: (String?) -> Void
    let onToggleAssignee: (User) -> Void

    @State private var offset: CGFloat = 0
    @State private var showingDelete = false
    @State private var showingDetail = false

    // Permission check: only assigned user can toggle, or anyone if unassigned
    private var canToggle: Bool {
        if subtask.assignees.isEmpty {
            // No assignees - anyone can toggle
            return true
        }
        // Only assigned people can toggle
        return subtask.assignees.contains { $0.id == MockDataService.shared.currentUser.id }
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button background
            if showingDelete {
                Button {
                    withAnimation {
                        onDelete()
                    }
                } label: {
                    Image(systemName: "trash.fill")
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 44)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // Subtask content - tappable area
            HStack(spacing: 10) {
                // Checkbox (separate tap target)
                Button {
                    if canToggle {
                        onToggle()
                    }
                } label: {
                    Image(systemName: subtask.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(subtask.isDone ? .green : (canToggle ? .gray : .gray.opacity(0.3)))
                }
                .buttonStyle(.plain)
                .disabled(!canToggle)

                // Main content - tap to open detail
                Button {
                    if !showingDelete {
                        showingDetail = true
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(subtask.title)
                                .font(.system(size: 14))
                                .strikethrough(subtask.isDone)
                                .foregroundStyle(subtask.isDone ? .secondary : .primary)
                                .lineLimit(1)

                            // Show description preview if exists
                            if let description = subtask.description, !description.isEmpty {
                                Text(description)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            // Always show assignees if any
                            if !subtask.assignees.isEmpty {
                                HStack(spacing: 4) {
                                    // Overlapping avatars
                                    HStack(spacing: -6) {
                                        ForEach(subtask.assignees.prefix(3)) { assignee in
                                            Circle()
                                                .fill(Theme.primaryLight)
                                                .frame(width: 16, height: 16)
                                                .overlay {
                                                    Text(assignee.avatarInitials)
                                                        .font(.system(size: 8, weight: .medium))
                                                        .foregroundStyle(Theme.primary)
                                                }
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color(uiColor: .secondarySystemBackground), lineWidth: 1)
                                                )
                                        }
                                    }
                                    // Names (show "Me" for current user)
                                    let names = subtask.assignees.prefix(2).map { $0.displayFirstName }
                                    let displayText = subtask.assignees.count > 2
                                        ? "\(names.joined(separator: ", ")) +\(subtask.assignees.count - 2)"
                                        : names.joined(separator: ", ")
                                    Text(displayText)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Spacer()

                        // Chevron indicator
                        if !showingDelete {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .buttonStyle(.plain)

                // Close delete mode button
                if showingDelete {
                    Button {
                        withAnimation {
                            showingDelete = false
                            offset = 0
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(Color(uiColor: .secondarySystemBackground))
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width < 0 {
                            offset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        withAnimation {
                            if value.translation.width < -50 {
                                showingDelete = true
                                offset = -70
                            } else {
                                offset = 0
                                showingDelete = false
                            }
                        }
                    }
            )
        }
        .sheet(isPresented: $showingDetail) {
            SubtaskDetailSheet(
                subtask: subtask,
                canEdit: canEdit,
                members: members,
                onUpdateTitle: onUpdateTitle,
                onUpdateDescription: onUpdateDescription,
                onToggleAssignee: onToggleAssignee
            )
        }
    }
}

// MARK: - Subtask Detail Sheet (View/Edit based on permissions)

struct SubtaskDetailSheet: View {
    let subtask: Subtask
    let canEdit: Bool
    let members: [User]
    let onUpdateTitle: (String) -> Void
    let onUpdateDescription: (String?) -> Void
    let onToggleAssignee: (User) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var editedTitle: String = ""
    @State private var editedDescription: String = ""
    @State private var selectedAssigneeIds: Set<UUID> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Title section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        if canEdit {
                            TextField("Subtask title", text: $editedTitle)
                                .font(.system(size: 17))
                                .padding(14)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Text(subtask.title)
                                .font(.system(size: 17))
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // Description/Instructions section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Instructions")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        if canEdit {
                            TextField("Add instructions or details...", text: $editedDescription, axis: .vertical)
                                .font(.system(size: 15))
                                .lineLimit(3...8)
                                .padding(14)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            if let description = subtask.description, !description.isEmpty {
                                Text(description)
                                    .font(.system(size: 15))
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(uiColor: .secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                Text("No instructions")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.tertiary)
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(uiColor: .secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }

                    // Assignees section
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Assigned to")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            Spacer()

                            if !selectedAssigneeIds.isEmpty {
                                Text("\(selectedAssigneeIds.count) people")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.primary)
                            }
                        }

                        if canEdit {
                            // Editable multi-select
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(members) { member in
                                        let isSelected = selectedAssigneeIds.contains(member.id)
                                        Button {
                                            if isSelected {
                                                selectedAssigneeIds.remove(member.id)
                                            } else {
                                                selectedAssigneeIds.insert(member.id)
                                            }
                                        } label: {
                                            HStack(spacing: 4) {
                                                Circle()
                                                    .fill(isSelected ? Color.white.opacity(0.3) : Theme.primaryLight)
                                                    .frame(width: 24, height: 24)
                                                    .overlay {
                                                        Text(member.avatarInitials)
                                                            .font(.system(size: 9, weight: .medium))
                                                            .foregroundStyle(isSelected ? .white : Theme.primary)
                                                    }
                                                Text(member.displayFirstName)
                                                    .font(.system(size: 13))

                                                if isSelected {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 10, weight: .bold))
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(isSelected ? Theme.primary : Color(uiColor: .secondarySystemBackground))
                                            .foregroundColor(isSelected ? .white : .primary)
                                            .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        } else {
                            // Read-only display
                            if subtask.assignees.isEmpty {
                                Text("No one assigned")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.tertiary)
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(uiColor: .secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(subtask.assignees) { assignee in
                                        HStack(spacing: 10) {
                                            Circle()
                                                .fill(Theme.primaryLight)
                                                .frame(width: 32, height: 32)
                                                .overlay {
                                                    Text(assignee.avatarInitials)
                                                        .font(.system(size: 11, weight: .medium))
                                                        .foregroundStyle(Theme.primary)
                                                }
                                            Text(assignee.displayName)
                                                .font(.system(size: 15))
                                            Spacer()
                                        }
                                        .padding(10)
                                        .background(Color(uiColor: .secondarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                            }
                        }
                    }

                    // Created by section
                    if let creator = subtask.createdBy {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Created by")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color.purple.opacity(0.2))
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        Text(creator.avatarInitials)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(.purple)
                                    }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(creator.displayName)
                                        .font(.system(size: 15))
                                    Text(subtask.createdAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle(canEdit ? "Edit Subtask" : "Subtask Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(canEdit ? "Cancel" : "Done") {
                        dismiss()
                    }
                }
                if canEdit {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            // Save title
                            if !editedTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                                onUpdateTitle(editedTitle)
                            }
                            // Save description
                            let desc = editedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                            onUpdateDescription(desc.isEmpty ? nil : desc)
                            // Update assignees - toggle any that changed
                            let originalIds = Set(subtask.assignees.map { $0.id })
                            for member in members {
                                let wasSelected = originalIds.contains(member.id)
                                let isNowSelected = selectedAssigneeIds.contains(member.id)
                                if wasSelected != isNowSelected {
                                    onToggleAssignee(member)
                                }
                            }
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .disabled(editedTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .onAppear {
                editedTitle = subtask.title
                editedDescription = subtask.description ?? ""
                selectedAssigneeIds = Set(subtask.assignees.map { $0.id })
            }
        }
    }
}

// MARK: - Assign Task Sheet (Multiple Selection)

struct AssignTaskSheet: View {
    @Bindable var viewModel: TaskDetailViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                // Clear all option
                if !viewModel.task.assignees.isEmpty {
                    Button {
                        viewModel.clearAllAssignees()
                    } label: {
                        HStack {
                            Image(systemName: "person.slash")
                                .frame(width: 32)
                            Text("Clear All")
                            Spacer()
                        }
                    }
                    .foregroundStyle(.red)
                }

                // Members (toggle selection)
                ForEach(viewModel.members) { member in
                    Button {
                        viewModel.toggleAssignee(member)
                    } label: {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Theme.primaryLight)
                                    .frame(width: 32, height: 32)
                                Text(member.avatarInitials)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Theme.primary)
                            }
                            Text(member.name)
                            Spacer()
                            if viewModel.task.assignees.contains(where: { $0.id == member.id }) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.primary)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Assign To")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Attachment Row View

struct AttachmentRowView: View {
    let attachment: Attachment
    let subtasks: [Subtask]

    var linkedSubtaskName: String? {
        guard let subtaskId = attachment.linkedSubtaskId else { return nil }
        return subtasks.first { $0.id == subtaskId }?.title
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconBackgroundColor)
                    .frame(width: 40, height: 40)
                Image(systemName: attachment.iconName)
                    .font(.system(size: 16))
                    .foregroundStyle(iconColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.fileName)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(attachment.fileSizeFormatted)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    if let subtaskName = linkedSubtaskName {
                        Text("·")
                            .foregroundStyle(.secondary)
                        HStack(spacing: 2) {
                            Image(systemName: "checklist")
                                .font(.system(size: 10))
                            Text(subtaskName)
                                .lineLimit(1)
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.primary)
                    }
                }
            }

            Spacer()
        }
        .padding(8)
        .background(Color(uiColor: .tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var iconBackgroundColor: Color {
        switch attachment.type {
        case .image: return .blue.opacity(0.15)
        case .video: return .purple.opacity(0.15)
        case .document: return .orange.opacity(0.15)
        }
    }

    private var iconColor: Color {
        switch attachment.type {
        case .image: return .blue
        case .video: return .purple
        case .document: return .orange
        }
    }
}

// MARK: - Task Attachments View (Full List)

struct TaskAttachmentsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: TaskDetailViewModel
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("", selection: $selectedTab) {
                    Text("Media").tag(0)
                    Text("Docs").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                TabView(selection: $selectedTab) {
                    // Media tab
                    attachmentList(viewModel.mediaAttachments, emptyTitle: "No Media", emptyIcon: "photo.on.rectangle", emptyDescription: "Photos and videos will appear here")
                        .tag(0)

                    // Docs tab
                    attachmentList(viewModel.docAttachments, emptyTitle: "No Documents", emptyIcon: "doc", emptyDescription: "Documents will appear here")
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Attachments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    @ViewBuilder
    private func attachmentList(_ attachments: [Attachment], emptyTitle: String, emptyIcon: String, emptyDescription: String) -> some View {
        if attachments.isEmpty {
            ContentUnavailableView(
                emptyTitle,
                systemImage: emptyIcon,
                description: Text(emptyDescription)
            )
        } else {
            List {
                // Group by subtask
                let unlinkedAttachments = attachments.filter { $0.linkedSubtaskId == nil }
                let linkedGroups = Dictionary(grouping: attachments.filter { $0.linkedSubtaskId != nil }) { $0.linkedSubtaskId! }

                if !unlinkedAttachments.isEmpty {
                    Section("General") {
                        ForEach(unlinkedAttachments) { attachment in
                            AttachmentRowView(attachment: attachment, subtasks: viewModel.task.subtasks)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                viewModel.removeAttachment(unlinkedAttachments[index])
                            }
                        }
                    }
                }

                ForEach(Array(linkedGroups.keys), id: \.self) { subtaskId in
                    if let subtaskName = viewModel.subtaskName(for: subtaskId),
                       let groupAttachments = linkedGroups[subtaskId] {
                        Section(subtaskName) {
                            ForEach(groupAttachments) { attachment in
                                AttachmentRowView(attachment: attachment, subtasks: viewModel.task.subtasks)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    viewModel.removeAttachment(groupAttachments[index])
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

// MARK: - Task Info View (Settings & Member Management)

struct TaskInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: TaskDetailViewModel
    @State private var showingAddMembers = false

    var body: some View {
        NavigationStack {
            List {
                // Task header section
                Section {
                    VStack(spacing: 12) {
                        // Task icon
                        ZStack {
                            Circle()
                                .fill(Theme.primaryLight)
                                .frame(width: 80, height: 80)
                            Image(systemName: "checklist")
                                .font(.system(size: 32))
                                .foregroundStyle(Theme.primary)
                        }

                        // Task title
                        Text(viewModel.task.title)
                            .font(.system(size: 20, weight: .bold))
                            .multilineTextAlignment(.center)

                        // Status and info
                        HStack(spacing: 16) {
                            Label(
                                viewModel.task.status == .done ? "Completed" : "Pending",
                                systemImage: viewModel.task.status == .done ? "checkmark.circle.fill" : "circle"
                            )
                            .font(.system(size: 13))
                            .foregroundStyle(viewModel.task.status == .done ? .green : .orange)

                            if let dueDate = viewModel.task.dueDate {
                                Label(formatDate(dueDate), systemImage: "calendar")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                // Notes/Instructions section (if task has notes)
                if let notes = viewModel.task.notes, !notes.isEmpty {
                    Section {
                        Text(notes)
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                    } header: {
                        Label("Instructions", systemImage: "doc.text")
                    }
                }

                // Notifications section
                Section {
                    Toggle(isOn: $viewModel.isMuted) {
                        Label("Mute Notifications", systemImage: "bell.slash")
                    }

                    NavigationLink {
                        Text("Notification Settings")
                    } label: {
                        Label("Notification Sound", systemImage: "speaker.wave.2")
                    }
                }

                // Members section
                Section {
                    // Member list
                    ForEach(viewModel.members) { member in
                        MemberRow(
                            member: member,
                            isAdmin: isUserAdmin(member),
                            isCurrentUser: member.id == viewModel.currentUser.id,
                            canRemove: viewModel.isAdmin && member.id != viewModel.currentUser.id,
                            onRemove: {
                                viewModel.removeMember(member)
                            }
                        )
                    }

                    // Add members button (admin only)
                    if viewModel.isAdmin {
                        Button {
                            showingAddMembers = true
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Theme.primaryLight)
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "person.badge.plus")
                                        .foregroundStyle(Theme.primary)
                                }
                                Text("Add Members")
                                    .foregroundStyle(Theme.primary)
                            }
                        }
                    }
                } header: {
                    Text("\(viewModel.members.count) Members")
                }

                // Media & files section
                Section {
                    NavigationLink {
                        TaskAttachmentsView(viewModel: viewModel)
                    } label: {
                        Label {
                            HStack {
                                Text("Media & Files")
                                Spacer()
                                if !viewModel.task.attachments.isEmpty {
                                    Text("\(viewModel.task.attachments.count)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: "photo.on.rectangle")
                        }
                    }
                }

                // Actions section
                Section {
                    Button {
                        // Export task
                    } label: {
                        Label("Export Task", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        // Copy task link
                    } label: {
                        Label("Copy Link", systemImage: "link")
                    }
                }

                // Danger zone
                Section {
                    if viewModel.isAdmin {
                        Button(role: .destructive) {
                            // Delete task
                        } label: {
                            Label("Delete Task", systemImage: "trash")
                        }
                    } else {
                        Button(role: .destructive) {
                            // Leave task
                        } label: {
                            Label("Leave Task", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Task Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingAddMembers) {
                AddTaskMembersView(viewModel: viewModel)
            }
        }
    }

    private func isUserAdmin(_ user: User) -> Bool {
        if let creator = viewModel.task.createdBy {
            return creator.id == user.id
        }
        return viewModel.task.assignees.first?.id == user.id
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }
}

// MARK: - Member Row

struct MemberRow: View {
    let member: User
    let isAdmin: Bool
    let isCurrentUser: Bool
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(avatarColor(for: member.name))
                    .frame(width: 40, height: 40)
                Text(member.avatarInitials)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }

            // Name and role
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.name)
                        .font(.system(size: 16))

                    if isCurrentUser {
                        Text("You")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                if isAdmin {
                    Text("Admin")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.primary)
                } else {
                    Text(member.phoneNumber)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Remove button (admin only, not for self)
            if canRemove {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func avatarColor(for name: String) -> Color {
        Theme.primary
    }
}

// MARK: - Add Task Members View

struct AddTaskMembersView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: TaskDetailViewModel
    @State private var searchText = ""

    var filteredMembers: [User] {
        let available = viewModel.availableMembersToAdd
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
                    TextField("Search members", text: $searchText)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemBackground))

                if filteredMembers.isEmpty {
                    ContentUnavailableView(
                        "No Members to Add",
                        systemImage: "person.crop.circle.badge.checkmark",
                        description: Text("All project members are already in this task")
                    )
                } else {
                    List {
                        ForEach(filteredMembers) { member in
                            Button {
                                viewModel.addMember(member)
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(avatarColor(for: member.name))
                                            .frame(width: 44, height: 44)
                                        Text(member.avatarInitials)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(.white)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(member.name)
                                            .font(.system(size: 16))
                                            .foregroundStyle(.primary)
                                        Text(member.phoneNumber)
                                            .font(.system(size: 14))
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(Theme.primary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Add Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func avatarColor(for name: String) -> Color {
        Theme.primary
    }
}

#Preview {
    NavigationStack {
        TaskDetailView(
            task: DONEOTask(
                title: "Order materials for kitchen renovation",
                assignees: [User(name: "Maria Garcia", phoneNumber: "+1 555-0101")],
                status: .pending,
                dueDate: Date(),
                subtasks: [
                    Subtask(title: "Get quotes from 3 suppliers", isDone: true),
                    Subtask(title: "Compare prices", isDone: false),
                    Subtask(title: "Place order", isDone: false)
                ]
            ),
            members: [
                User(name: "Maria Garcia", phoneNumber: "+1 555-0101"),
                User(name: "James Wilson", phoneNumber: "+1 555-0102")
            ]
        )
    }
}
