import SwiftUI

struct TaskDrawerDetailView: View {
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddSubtask = false
    @State private var newSubtaskTitle = ""
    @FocusState private var isSubtaskFieldFocused: Bool

    // Get the current task from viewModel to ensure we have latest data
    private var currentTask: DONEOTask {
        viewModel.project.tasks.first { $0.id == task.id } ?? task
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Task header with checkbox
                taskHeader

                // Subtasks list
                if currentTask.subtasks.isEmpty {
                    emptySubtasksView
                } else {
                    subtasksList
                }

                // Add subtask section
                addSubtaskSection
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back")
                        }
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.quoteTask(currentTask)
                        dismiss()
                    } label: {
                        Label("Quote", systemImage: "quote.bubble")
                    }
                }
            }
        }
    }

    // MARK: - Task Header

    private var taskHeader: some View {
        HStack(spacing: 12) {
            // Task checkbox
            Button {
                viewModel.toggleTaskStatus(currentTask)
            } label: {
                Image(systemName: currentTask.status == .done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28))
                    .foregroundStyle(currentTask.status == .done ? .green : .secondary)
            }
            .buttonStyle(.plain)

            // Task title
            VStack(alignment: .leading, spacing: 4) {
                Text(currentTask.title)
                    .font(.system(size: 18, weight: .semibold))
                    .strikethrough(currentTask.status == .done)
                    .foregroundStyle(currentTask.status == .done ? .secondary : .primary)

                // Subtask progress
                if !currentTask.subtasks.isEmpty {
                    let completed = currentTask.subtasks.filter { $0.isDone }.count
                    let total = currentTask.subtasks.count
                    HStack(spacing: 4) {
                        Image(systemName: "checklist")
                            .font(.system(size: 12))
                        Text("\(completed) of \(total) subtasks completed")
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(completed == total ? .green : .secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
    }

    // MARK: - Empty Subtasks View

    private var emptySubtasksView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "list.bullet")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            Text("No subtasks")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Break this task into smaller steps")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Subtasks List

    private var subtasksList: some View {
        List {
            ForEach(currentTask.subtasks) { subtask in
                DrawerSubtaskRow(
                    subtask: subtask,
                    task: currentTask,
                    viewModel: viewModel,
                    onQuote: {
                        viewModel.quoteSubtask(currentTask, subtask: subtask)
                        dismiss()
                    }
                )
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let subtask = currentTask.subtasks[index]
                    viewModel.deleteSubtask(from: currentTask, subtask: subtask)
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Add Subtask Section

    private var addSubtaskSection: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.primary)

                TextField("Add a subtask...", text: $newSubtaskTitle)
                    .font(.system(size: 16))
                    .focused($isSubtaskFieldFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        addSubtask()
                    }

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
            .padding()
            .background(Color(uiColor: .systemBackground))
        }
    }

    private func addSubtask() {
        guard !newSubtaskTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        viewModel.addSubtask(to: currentTask, title: newSubtaskTitle)
        newSubtaskTitle = ""
    }
}

// MARK: - Drawer Subtask Row

struct DrawerSubtaskRow: View {
    let subtask: Subtask
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel
    let onQuote: () -> Void

    @State private var showingDetail = false

    private var canToggle: Bool {
        viewModel.canToggleSubtask(subtask)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                if canToggle {
                    viewModel.toggleSubtaskStatus(task, subtask)
                }
            } label: {
                Image(systemName: subtask.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(subtask.isDone ? .green : (canToggle ? .secondary : .secondary.opacity(0.3)))
            }
            .buttonStyle(.plain)
            .disabled(!canToggle)

            // Subtask info
            Button {
                showingDetail = true
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subtask.title)
                        .font(.system(size: 15))
                        .strikethrough(subtask.isDone)
                        .foregroundStyle(subtask.isDone ? .secondary : .primary)
                        .lineLimit(2)

                    // Description preview
                    if let description = subtask.description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    // Assignees
                    if !subtask.assignees.isEmpty {
                        HStack(spacing: 4) {
                            HStack(spacing: -4) {
                                ForEach(subtask.assignees.prefix(3)) { assignee in
                                    Circle()
                                        .fill(Theme.primaryLight)
                                        .frame(width: 18, height: 18)
                                        .overlay {
                                            Text(assignee.avatarInitials)
                                                .font(.system(size: 7, weight: .medium))
                                                .foregroundStyle(Theme.primary)
                                        }
                                        .overlay(
                                            Circle()
                                                .stroke(Color(uiColor: .systemBackground), lineWidth: 1)
                                        )
                                }
                            }
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
            }
            .buttonStyle(.plain)

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                viewModel.deleteSubtask(from: task, subtask: subtask)
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
            DrawerSubtaskDetailSheet(
                subtask: subtask,
                task: task,
                viewModel: viewModel
            )
        }
    }
}

// MARK: - Drawer Subtask Detail Sheet

struct DrawerSubtaskDetailSheet: View {
    let subtask: Subtask
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var editedTitle: String = ""
    @State private var editedDescription: String = ""
    @State private var selectedAssigneeIds: Set<UUID> = []

    private var canEdit: Bool {
        viewModel.canEditSubtask(subtask)
    }

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

                    // Description section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Instructions")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        if canEdit {
                            TextField("Add instructions...", text: $editedDescription, axis: .vertical)
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
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(viewModel.project.members) { member in
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
                            saveChanges()
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

    private func saveChanges() {
        // Save title
        if !editedTitle.trimmingCharacters(in: .whitespaces).isEmpty && editedTitle != subtask.title {
            viewModel.updateSubtask(in: task, subtask: subtask, newTitle: editedTitle)
        }

        // Save description
        let desc = editedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let newDesc = desc.isEmpty ? nil : desc
        if newDesc != subtask.description {
            viewModel.updateSubtaskDescription(in: task, subtask: subtask, description: newDesc)
        }

        // Update assignees
        let originalIds = Set(subtask.assignees.map { $0.id })
        for member in viewModel.project.members {
            let wasSelected = originalIds.contains(member.id)
            let isNowSelected = selectedAssigneeIds.contains(member.id)
            if wasSelected != isNowSelected {
                viewModel.toggleSubtaskAssignee(in: task, subtask: subtask, member: member)
            }
        }
    }
}

#Preview {
    TaskDrawerDetailView(
        task: DONEOTask(
            title: "Order materials for kitchen",
            assignees: [MockDataService.allUsers[1]],
            status: .pending,
            subtasks: [
                Subtask(title: "Get quotes from 3 suppliers", isDone: true, assignees: [MockDataService.allUsers[1]]),
                Subtask(title: "Compare prices", isDone: false),
                Subtask(title: "Place order", isDone: false)
            ]
        ),
        viewModel: ProjectChatViewModel(project: Project(
            name: "Test Project",
            members: MockDataService.allUsers
        ))
    )
}
