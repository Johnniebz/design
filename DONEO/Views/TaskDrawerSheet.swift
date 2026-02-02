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
    @State private var taskTitle = ""
    @State private var selectedAssigneeIds: Set<UUID> = []
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Title input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Task Title")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextField("What needs to be done?", text: $taskTitle)
                        .font(.system(size: 17))
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .focused($isTitleFocused)
                }

                // Assignee picker
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Assign to")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        if !selectedAssigneeIds.isEmpty {
                            Text("\(selectedAssigneeIds.count) selected")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.primary)
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.project.members) { member in
                                let isSelected = selectedAssigneeIds.contains(member.id)
                                Button {
                                    if isSelected {
                                        selectedAssigneeIds.remove(member.id)
                                    } else {
                                        selectedAssigneeIds.insert(member.id)
                                    }
                                } label: {
                                    VStack(spacing: 4) {
                                        ZStack {
                                            Circle()
                                                .fill(isSelected ? Theme.primary : Color(uiColor: .tertiarySystemBackground))
                                                .frame(width: 48, height: 48)
                                            Text(member.avatarInitials)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundStyle(isSelected ? .white : .primary)

                                            if isSelected {
                                                Circle()
                                                    .fill(Color.green)
                                                    .frame(width: 18, height: 18)
                                                    .overlay {
                                                        Image(systemName: "checkmark")
                                                            .font(.system(size: 10, weight: .bold))
                                                            .foregroundStyle(.white)
                                                    }
                                                    .offset(x: 16, y: 16)
                                            }
                                        }
                                        Text(member.displayFirstName)
                                            .font(.system(size: 12))
                                            .foregroundStyle(isSelected ? Theme.primary : .secondary)
                                    }
                                    .frame(width: 64)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding()
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
                        let assignees = viewModel.project.members.filter { selectedAssigneeIds.contains($0.id) }
                        viewModel.addTask(title: taskTitle, assignees: assignees)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(taskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                isTitleFocused = true
            }
        }
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
