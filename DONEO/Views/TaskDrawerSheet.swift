import SwiftUI

struct TaskDrawerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ProjectChatViewModel
    @State private var showingAddTask = false
    @State private var showingTaskDetail = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Task list
                if viewModel.tasks.isEmpty {
                    emptyStateView
                } else {
                    taskListView
                }

                // Add task button at bottom
                addTaskButton
            }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(Circle())
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskSheet(viewModel: viewModel)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No tasks yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Create your first task to get started")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Task List

    private var taskListView: some View {
        List {
            // Pending tasks
            if !viewModel.pendingTasks.isEmpty {
                Section {
                    ForEach(viewModel.pendingTasks) { task in
                        TaskDrawerRow(
                            task: task,
                            viewModel: viewModel,
                            onQuote: {
                                viewModel.quoteTask(task)
                                dismiss()
                            }
                        )
                    }
                } header: {
                    Text("Pending (\(viewModel.pendingTasks.count))")
                }
            }

            // Completed tasks
            if !viewModel.completedTasks.isEmpty {
                Section {
                    ForEach(viewModel.completedTasks) { task in
                        TaskDrawerRow(
                            task: task,
                            viewModel: viewModel,
                            onQuote: {
                                viewModel.quoteTask(task)
                                dismiss()
                            }
                        )
                    }
                } header: {
                    Text("Completed (\(viewModel.completedTasks.count))")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Add Task Button

    private var addTaskButton: some View {
        Button {
            showingAddTask = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Task")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.primary)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - Task Drawer Row

struct TaskDrawerRow: View {
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel
    let onQuote: () -> Void

    @State private var showingDetail = false

    private var progress: (completed: Int, total: Int) {
        viewModel.subtaskProgress(for: task)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                viewModel.toggleTaskStatus(task)
            } label: {
                Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(task.status == .done ? .green : .secondary)
            }
            .buttonStyle(.plain)

            // Task info
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 16))
                    .strikethrough(task.status == .done)
                    .foregroundStyle(task.status == .done ? .secondary : .primary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    // Assignees
                    if !task.assignees.isEmpty {
                        HStack(spacing: -6) {
                            ForEach(task.assignees.prefix(3)) { assignee in
                                Circle()
                                    .fill(Theme.primaryLight)
                                    .frame(width: 20, height: 20)
                                    .overlay {
                                        Text(assignee.avatarInitials)
                                            .font(.system(size: 8, weight: .medium))
                                            .foregroundStyle(Theme.primary)
                                    }
                                    .overlay(
                                        Circle()
                                            .stroke(Color(uiColor: .systemBackground), lineWidth: 1)
                                    )
                            }
                        }

                        let names = task.assignees.prefix(2).map { $0.displayFirstName }
                        let displayText = task.assignees.count > 2
                            ? "\(names.joined(separator: ", ")) +\(task.assignees.count - 2)"
                            : names.joined(separator: ", ")
                        Text(displayText)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    // Subtask progress
                    if progress.total > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "checklist")
                                .font(.system(size: 10))
                            Text("\(progress.completed)/\(progress.total)")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(progress.completed == progress.total ? .green : .secondary)
                    }

                    // Attachments indicator
                    let attachmentCount = viewModel.project.attachments(for: task.id).count
                    if attachmentCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "paperclip")
                                .font(.system(size: 10))
                            Text("\(attachmentCount)")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(.secondary)
                    }

                    // Due date
                    if let dueDate = task.dueDate {
                        HStack(spacing: 2) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                            Text(formatDueDate(dueDate))
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(task.isOverdue ? .red : .secondary)
                    }
                }
            }

            Spacer()

            // Chevron to drill into subtasks
            if !task.subtasks.isEmpty || true {  // Always show chevron for now
                Button {
                    viewModel.selectedTask = task
                    showingDetail = true
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                viewModel.deleteTask(task)
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                onQuote()
            } label: {
                Label("Quote", systemImage: "quote.bubble")
            }
            .tint(Theme.primary)
        }
        .sheet(isPresented: $showingDetail) {
            TaskDrawerDetailView(task: task, viewModel: viewModel)
        }
    }

    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }
}

// MARK: - Add Task Sheet

struct AddTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ProjectChatViewModel

    // Task fields
    @State private var taskTitle = ""
    @State private var selectedAssigneeIds: Set<UUID> = []
    @State private var dueDate: Date? = nil
    @State private var showingDatePicker = false
    @State private var notes = ""
    @State private var subtasks: [NewSubtask] = []
    @State private var newSubtaskTitle = ""
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case title, notes, subtask
    }

    // Helper struct for subtasks being created
    struct NewSubtask: Identifiable {
        let id = UUID()
        var title: String
        var description: String = ""
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Task title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Task")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        TextField("What needs to be done?", text: $taskTitle)
                            .font(.system(size: 17))
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .focused($focusedField, equals: .title)
                    }

                    // Assignees as chips
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Assign to")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        FlowLayout(spacing: 8) {
                            ForEach(viewModel.project.members) { member in
                                let isSelected = selectedAssigneeIds.contains(member.id)
                                Button {
                                    if isSelected {
                                        selectedAssigneeIds.remove(member.id)
                                    } else {
                                        selectedAssigneeIds.insert(member.id)
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(isSelected ? Color.white.opacity(0.3) : Theme.primaryLight)
                                            .frame(width: 28, height: 28)
                                            .overlay {
                                                Text(member.avatarInitials)
                                                    .font(.system(size: 10, weight: .medium))
                                                    .foregroundStyle(isSelected ? .white : Theme.primary)
                                            }
                                        Text(member.id == viewModel.currentUser.id ? "Me" : member.displayFirstName)
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(isSelected ? Theme.primary : Color(uiColor: .secondarySystemBackground))
                                    .foregroundStyle(isSelected ? .white : .primary)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Due date
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            showingDatePicker.toggle()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Theme.primary)

                                if let date = dueDate {
                                    Text(formatDueDate(date))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.primary)

                                    Button {
                                        dueDate = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    Text("Set due date")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        if showingDatePicker {
                            DatePicker(
                                "Due date",
                                selection: Binding(
                                    get: { dueDate ?? Date() },
                                    set: { dueDate = $0 }
                                ),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .tint(Theme.primary)
                        }
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        TextField("Add details, instructions, or context...", text: $notes, axis: .vertical)
                            .font(.system(size: 15))
                            .lineLimit(4...8)
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .focused($focusedField, equals: .notes)
                    }

                    // Subtasks
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Subtasks")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        // Existing subtasks
                        ForEach(subtasks) { subtask in
                            HStack(spacing: 10) {
                                Image(systemName: "circle")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.secondary)

                                Text(subtask.title)
                                    .font(.system(size: 15))

                                Spacer()

                                Button {
                                    subtasks.removeAll { $0.id == subtask.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(12)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Add subtask input
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 18))
                                .foregroundStyle(Theme.primary)

                            TextField("Add subtask", text: $newSubtaskTitle)
                                .font(.system(size: 15))
                                .focused($focusedField, equals: .subtask)
                                .submitLabel(.done)
                                .onSubmit {
                                    addSubtask()
                                }
                        }
                        .padding(12)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Attachments placeholder
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Attachments")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button {
                                // TODO: Add attachment
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 14))
                                    Text("Add")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundStyle(Theme.primary)
                            }
                        }

                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(uiColor: .secondarySystemBackground))
                            .frame(height: 100)
                            .overlay {
                                VStack(spacing: 8) {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 28))
                                        .foregroundStyle(.tertiary)
                                    Text("Photos, documents, and files")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.tertiary)
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
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createTask()
                    }
                    .fontWeight(.semibold)
                    .disabled(taskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                focusedField = .title
            }
        }
    }

    private func addSubtask() {
        let title = newSubtaskTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        subtasks.append(NewSubtask(title: title))
        newSubtaskTitle = ""
    }

    private func createTask() {
        let assignees = viewModel.project.members.filter { selectedAssigneeIds.contains($0.id) }
        let subtaskList = subtasks.map { Subtask(title: $0.title, description: $0.description.isEmpty ? nil : $0.description, createdBy: viewModel.currentUser) }
        let notesText = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        viewModel.addTask(
            title: taskTitle,
            assignees: assignees,
            subtasks: subtaskList,
            dueDate: dueDate,
            notes: notesText.isEmpty ? nil : notesText
        )
        dismiss()
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
}

// MARK: - Flow Layout for chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .init(frame.size))
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), frames)
    }
}

#Preview {
    TaskDrawerSheet(viewModel: ProjectChatViewModel(project: Project(
        name: "Test Project",
        members: MockDataService.allUsers,
        tasks: [
            DONEOTask(
                title: "Order materials for kitchen",
                assignees: [MockDataService.allUsers[1]],
                status: .pending,
                subtasks: [
                    Subtask(title: "Get quotes", isDone: true),
                    Subtask(title: "Compare prices", isDone: false)
                ]
            ),
            DONEOTask(title: "Schedule inspection", status: .done)
        ]
    )))
}
