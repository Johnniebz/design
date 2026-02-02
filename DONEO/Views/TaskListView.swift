import SwiftUI

struct TaskListView: View {
    @Bindable var viewModel: ProjectDetailViewModel
    @State private var showingNewTaskSheet = false
    @State private var showCompleted = false

    var body: some View {
        // Access currentUser to trigger re-render when user switches
        let _ = MockDataService.shared.currentUser
        List {
            // Header section with Main Tasks
            Section {
                ForEach(viewModel.pendingTasks) { task in
                    NavigationLink(value: task) {
                        TaskCardView(
                            task: task,
                            unreadCount: viewModel.unreadCount(for: task)
                        )
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        viewModel.deleteTask(viewModel.pendingTasks[index])
                    }
                }
            } header: {
                Text("Main Tasks")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(uiColor: .label))
                    .textCase(nil)
                    .padding(.bottom, 8)
            }

            // Completed section (collapsible)
            if !viewModel.completedTasks.isEmpty {
                Section {
                    if showCompleted {
                        ForEach(viewModel.completedTasks) { task in
                            NavigationLink(value: task) {
                                CompletedTaskCardView(task: task)
                            }
                        }
                    }
                } header: {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCompleted.toggle()
                        }
                    } label: {
                        HStack {
                            Text("Completed")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("\(viewModel.completedTasks.count)")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if viewModel.project.tasks.isEmpty {
                ContentUnavailableView(
                    "No Tasks Yet",
                    systemImage: "checklist",
                    description: Text("Tap + to add your first task")
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewTaskSheet = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingNewTaskSheet) {
            NewTaskSheet(viewModel: viewModel, isPresented: $showingNewTaskSheet)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Completed Task Card (minimal)

struct CompletedTaskCardView: View {
    let task: DONEOTask

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.green.opacity(0.6))

            Text(task.title)
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
                .strikethrough()
                .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - New Task Sheet

struct NewTaskSheet: View {
    @Bindable var viewModel: ProjectDetailViewModel
    @Binding var isPresented: Bool
    @FocusState private var focusedField: Field?
    @State private var showingDueDatePicker = false
    @State private var showingAttachmentOptions = false
    @State private var newSubtaskTitle = ""
    @State private var newSubtaskDescription = ""
    @State private var newSubtaskAssigneeIds: Set<UUID> = []

    enum Field: Hashable {
        case title
        case notes
        case subtask
        case subtaskDescription
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Title field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Task")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        TextField("What needs to be done?", text: $viewModel.newTaskTitle)
                            .font(.system(size: 17))
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .focused($focusedField, equals: .title)
                    }

                    // Assign to section (inline tags)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Assign to")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        // Scrollable member tags
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(viewModel.project.members) { member in
                                    MemberTag(
                                        member: member,
                                        isSelected: viewModel.newTaskAssignees.contains { $0.id == member.id },
                                        onTap: {
                                            viewModel.toggleNewTaskAssignee(member)
                                        }
                                    )
                                }
                            }
                        }
                    }

                    // Due date button
                    HStack {
                        Button {
                            showingDueDatePicker = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 14))
                                    .foregroundColor(.orange)
                                if let dueDate = viewModel.newTaskDueDate {
                                    Text(formatDueDate(dueDate))
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                    // Clear button
                                    Button {
                                        viewModel.newTaskDueDate = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    Text("Set due date")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(Capsule())
                        }
                        Spacer()
                    }

                    // Notes field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        TextField("Add details, instructions, or context...", text: $viewModel.newTaskNotes, axis: .vertical)
                            .font(.system(size: 15))
                            .lineLimit(3...6)
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .focused($focusedField, equals: .notes)
                    }

                    // Subtasks section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Subtasks")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        // Existing subtasks
                        if !viewModel.newTaskSubtasks.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(viewModel.newTaskSubtasks) { subtask in
                                    HStack(spacing: 10) {
                                        Image(systemName: "circle")
                                            .font(.system(size: 18))
                                            .foregroundStyle(.secondary)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(subtask.title)
                                                .font(.system(size: 15))

                                            // Show assignees if any
                                            if !subtask.assignees.isEmpty {
                                                HStack(spacing: 4) {
                                                    // Overlapping avatars
                                                    HStack(spacing: -4) {
                                                        ForEach(subtask.assignees.prefix(3)) { assignee in
                                                            Circle()
                                                                .fill(Theme.primaryLight)
                                                                .frame(width: 14, height: 14)
                                                                .overlay {
                                                                    Text(assignee.avatarInitials)
                                                                        .font(.system(size: 7, weight: .medium))
                                                                        .foregroundStyle(Theme.primary)
                                                                }
                                                                .overlay(
                                                                    Circle()
                                                                        .stroke(Color(uiColor: .secondarySystemBackground), lineWidth: 1)
                                                                )
                                                        }
                                                    }
                                                    // Names
                                                    let names = subtask.assignees.prefix(2).map { $0.displayFirstName }
                                                    let displayText = subtask.assignees.count > 2
                                                        ? "\(names.joined(separator: ", ")) +\(subtask.assignees.count - 2)"
                                                        : names.joined(separator: ", ")
                                                    Text(displayText)
                                                        .font(.system(size: 12))
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                        }

                                        Spacer()

                                        Button {
                                            viewModel.removeNewTaskSubtask(subtask)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 12)

                                    if subtask.id != viewModel.newTaskSubtasks.last?.id {
                                        Divider()
                                            .padding(.leading, 40)
                                    }
                                }
                            }
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Add subtask section
                        VStack(spacing: 0) {
                            // Subtask title input
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Theme.primary)

                                TextField("Add subtask", text: $newSubtaskTitle)
                                    .font(.system(size: 15))
                                    .focused($focusedField, equals: .subtask)
                                    .submitLabel(.next)
                                    .onSubmit {
                                        focusedField = .subtaskDescription
                                    }

                                // Add button (visible when there's text)
                                if !newSubtaskTitle.isEmpty {
                                    Button {
                                        addSubtask()
                                    } label: {
                                        Text("Add")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Theme.primary)
                                    }
                                }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)

                            // Description and assignees (visible when typing subtask)
                            if !newSubtaskTitle.isEmpty {
                                Divider()

                                // Description field
                                TextField("Add instructions (optional)", text: $newSubtaskDescription, axis: .vertical)
                                    .font(.system(size: 14))
                                    .lineLimit(2...4)
                                    .focused($focusedField, equals: .subtaskDescription)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)

                                Divider()

                                // Assignee picker - Multi-select
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Assign to")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                        if !newSubtaskAssigneeIds.isEmpty {
                                            Text("(\(newSubtaskAssigneeIds.count))")
                                                .font(.system(size: 12))
                                                .foregroundStyle(Theme.primary)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.top, 6)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            // Team members (tap to toggle)
                                            ForEach(viewModel.project.members) { member in
                                                let isSelected = newSubtaskAssigneeIds.contains(member.id)
                                                Button {
                                                    if isSelected {
                                                        newSubtaskAssigneeIds.remove(member.id)
                                                    } else {
                                                        newSubtaskAssigneeIds.insert(member.id)
                                                    }
                                                } label: {
                                                    HStack(spacing: 4) {
                                                        Circle()
                                                            .fill(isSelected ? Color.white.opacity(0.3) : Theme.primaryLight)
                                                            .frame(width: 18, height: 18)
                                                            .overlay {
                                                                Text(member.avatarInitials)
                                                                    .font(.system(size: 8, weight: .medium))
                                                                    .foregroundStyle(isSelected ? .white : Theme.primary)
                                                            }
                                                        Text(member.displayFirstName)
                                                            .font(.system(size: 13))

                                                        if isSelected {
                                                            Image(systemName: "checkmark")
                                                                .font(.system(size: 10, weight: .bold))
                                                        }
                                                    }
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(isSelected ? Theme.primary : Color(uiColor: .tertiarySystemBackground))
                                                    .foregroundColor(isSelected ? .white : .primary)
                                                    .clipShape(Capsule())
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                    }
                                }
                            }
                        }
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Attachments section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Attachments")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button {
                                showingAttachmentOptions = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 16))
                                    Text("Add")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundStyle(Theme.primary)
                            }
                        }

                        if viewModel.newTaskAttachments.isEmpty {
                            // Empty state
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 28))
                                        .foregroundStyle(.quaternary)
                                    Text("Photos, documents, and files")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 24)
                                Spacer()
                            }
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            // Attachment grid
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8)
                            ], spacing: 8) {
                                ForEach(viewModel.newTaskAttachments) { attachment in
                                    NewTaskAttachmentThumbnail(
                                        attachment: attachment,
                                        onRemove: {
                                            viewModel.removeNewTaskAttachment(attachment)
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.resetNewTaskFields()
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        viewModel.createTask()
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                focusedField = .title
            }
            .sheet(isPresented: $showingDueDatePicker) {
                DueDatePicker(selectedDate: $viewModel.newTaskDueDate)
            }
            .sheet(isPresented: $showingAttachmentOptions) {
                NewTaskAttachmentSheet(viewModel: viewModel)
                    .presentationDetents([.medium])
            }
        }
    }

    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }

    private func addSubtask() {
        guard !newSubtaskTitle.isEmpty else { return }
        let selectedAssignees = viewModel.project.members.filter { newSubtaskAssigneeIds.contains($0.id) }
        let description = newSubtaskDescription.isEmpty ? nil : newSubtaskDescription
        viewModel.addNewTaskSubtask(title: newSubtaskTitle, description: description, assignees: selectedAssignees)
        newSubtaskTitle = ""
        newSubtaskDescription = ""
        newSubtaskAssigneeIds = []
    }
}

// MARK: - Member Tag (for inline assignment)

struct MemberTag: View {
    let member: User
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isSelected ? Theme.primary : Theme.primaryLight)
                    .frame(width: 24, height: 24)
                    .overlay {
                        Text(member.avatarInitials)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(isSelected ? .white : Theme.primary)
                    }

                Text(member.displayFirstName)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .white : .primary)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Theme.primary : Color(uiColor: .secondarySystemBackground))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - New Task Attachment Thumbnail

struct NewTaskAttachmentThumbnail: View {
    let attachment: Attachment
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(thumbnailColor)
                    .aspectRatio(1, contentMode: .fit)

                VStack(spacing: 4) {
                    Image(systemName: attachment.iconName)
                        .font(.system(size: 24))
                        .foregroundStyle(iconColor)

                    Text(attachment.fileName)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                }
            }

            // Remove button
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white, .red)
                    .shadow(radius: 2)
            }
            .offset(x: 6, y: -6)
        }
    }

    private var thumbnailColor: Color {
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

// MARK: - New Task Attachment Sheet

struct NewTaskAttachmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ProjectDetailViewModel
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .fontWeight(.semibold)
                }

                Spacer()

                Text("Add Attachment")
                    .font(.system(size: 16, weight: .semibold))

                Spacer()

                // Placeholder for symmetry
                Text("Done")
                    .fontWeight(.semibold)
                    .opacity(0)
            }
            .padding()

            // Tab picker
            Picker("", selection: $selectedTab) {
                Text("Photos").tag(0)
                Text("Files").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Content
            TabView(selection: $selectedTab) {
                // Photos tab
                photoGridView
                    .tag(0)

                // Files tab
                filePickerView
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }

    // MARK: - Photo Grid
    private var photoGridView: some View {
        let columns = [
            GridItem(.flexible(), spacing: 2),
            GridItem(.flexible(), spacing: 2),
            GridItem(.flexible(), spacing: 2)
        ]

        return ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                // Camera button
                Button {
                    addMockAttachment(type: .image, fileName: "Camera_\(Date().timeIntervalSince1970).jpg")
                } label: {
                    ZStack {
                        Rectangle()
                            .fill(Color(uiColor: .tertiarySystemBackground))
                            .aspectRatio(1, contentMode: .fill)
                        VStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 28))
                            Text("Camera")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                // Mock photo placeholders
                ForEach(0..<11, id: \.self) { index in
                    Button {
                        addMockAttachment(type: .image, fileName: "Photo_\(index).jpg")
                    } label: {
                        ZStack {
                            Rectangle()
                                .fill(Color(hue: Double(index) / 12.0, saturation: 0.3, brightness: 0.9))
                                .aspectRatio(1, contentMode: .fill)

                            // Selection circle
                            VStack {
                                HStack {
                                    Spacer()
                                    Circle()
                                        .strokeBorder(Color.white, lineWidth: 2)
                                        .frame(width: 24, height: 24)
                                        .padding(6)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
            .padding(.top, 16)
        }
    }

    // MARK: - File Picker
    private var filePickerView: some View {
        VStack(spacing: 20) {
            Spacer()

            Button {
                addMockAttachment(type: .document, fileName: "Document_\(Date().timeIntervalSince1970).pdf")
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    Text("Choose File")
                        .font(.system(size: 16, weight: .medium))
                    Text("PDF, Word, Excel, and more")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private func addMockAttachment(type: AttachmentType, fileName: String) {
        let attachment = Attachment(
            type: type,
            fileName: fileName,
            fileSize: Int64.random(in: 50000...2000000),
            uploadedBy: MockDataService.shared.currentUser
        )
        viewModel.addNewTaskAttachment(attachment)
    }
}
