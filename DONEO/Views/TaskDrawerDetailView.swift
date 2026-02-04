import SwiftUI
import PhotosUI

struct TaskDrawerDetailView: View {
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddSubtask = false
    @State private var showingTaskDetails = false

    // Get the current task from viewModel to ensure we have latest data
    private var currentTask: DONEOTask {
        viewModel.project.tasks.first { $0.id == task.id } ?? task
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Task header (tappable to see details)
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
            }
            .sheet(isPresented: $showingTaskDetails) {
                TaskInfoSheet(task: currentTask, viewModel: viewModel)
            }
        }
    }

    // MARK: - Task Header

    private var taskHeader: some View {
        Button {
            showingTaskDetails = true
        } label: {
            HStack(spacing: 12) {
                // Task info
                VStack(alignment: .leading, spacing: 6) {
                    Text(currentTask.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    // Info row
                    HStack(spacing: 12) {
                        // Subtask progress
                        if !currentTask.subtasks.isEmpty {
                            let completed = currentTask.subtasks.filter { $0.isDone }.count
                            let total = currentTask.subtasks.count
                            HStack(spacing: 4) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 11))
                                Text("\(completed)/\(total)")
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(completed == total ? .green : .secondary)
                        }

                        // Due date
                        if let dueDate = currentTask.dueDate {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 11))
                                Text(formatDueDate(dueDate))
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(currentTask.isOverdue ? .red : .secondary)
                        }

                        // Has notes indicator
                        if currentTask.notes != nil {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 11))
                                Text("Notes")
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(.secondary)
                        }
                    }

                    // Assignees
                    if !currentTask.assignees.isEmpty {
                        HStack(spacing: 4) {
                            HStack(spacing: -4) {
                                ForEach(currentTask.assignees.prefix(3)) { assignee in
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
                                                .stroke(Color(uiColor: .secondarySystemBackground), lineWidth: 1)
                                        )
                                }
                            }
                            let names = currentTask.assignees.prefix(2).map { $0.displayFirstName }
                            let displayText = currentTask.assignees.count > 2
                                ? "\(names.joined(separator: ", ")) +\(currentTask.assignees.count - 2)"
                                : names.joined(separator: ", ")
                            Text(displayText)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Chevron to indicate tappable
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
        }
        .buttonStyle(.plain)
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

    // MARK: - Subtasks List (split into Pending/Completed like Tasks screen)

    private var pendingSubtasks: [Subtask] {
        currentTask.subtasks.filter { !$0.isDone }
    }

    private var completedSubtasks: [Subtask] {
        currentTask.subtasks.filter { $0.isDone }
    }

    private var subtasksList: some View {
        List {
            // Pending section
            if !pendingSubtasks.isEmpty {
                Section {
                    ForEach(pendingSubtasks) { subtask in
                        DrawerSubtaskRow(
                            subtask: subtask,
                            task: currentTask,
                            viewModel: viewModel,
                            onQuote: {
                                viewModel.quoteSubtask(currentTask, subtask: subtask)
                                dismiss()
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                viewModel.deleteSubtask(from: currentTask, subtask: subtask)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                viewModel.quoteSubtask(currentTask, subtask: subtask)
                                dismiss()
                            } label: {
                                Label("Quote", systemImage: "quote.bubble")
                            }
                            .tint(Theme.primary)
                        }
                    }
                } header: {
                    Text("Pending (\(pendingSubtasks.count))")
                }
            }

            // Completed section
            if !completedSubtasks.isEmpty {
                Section {
                    ForEach(completedSubtasks) { subtask in
                        DrawerSubtaskRow(
                            subtask: subtask,
                            task: currentTask,
                            viewModel: viewModel,
                            onQuote: {
                                viewModel.quoteSubtask(currentTask, subtask: subtask)
                                dismiss()
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                viewModel.deleteSubtask(from: currentTask, subtask: subtask)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                viewModel.quoteSubtask(currentTask, subtask: subtask)
                                dismiss()
                            } label: {
                                Label("Quote", systemImage: "quote.bubble")
                            }
                            .tint(Theme.primary)
                        }
                    }
                } header: {
                    Text("Completed (\(completedSubtasks.count))")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Add Subtask Button (red button like Add Task)

    private var addSubtaskSection: some View {
        VStack(spacing: 0) {
            Button {
                showingAddSubtask = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text("Add Subtask")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .sheet(isPresented: $showingAddSubtask) {
            AddSubtaskSheet(task: currentTask, viewModel: viewModel)
        }
    }
}

// MARK: - Drawer Subtask Row (matches Task row style - no chevron)

struct DrawerSubtaskRow: View {
    let subtask: Subtask
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel
    let onQuote: () -> Void

    @State private var showingDetail = false

    private var canToggle: Bool {
        viewModel.canToggleSubtask(subtask)
    }

    // Get attachments linked to this subtask
    private var subtaskAttachments: [Attachment] {
        task.attachments.filter { $0.linkedSubtaskId == subtask.id }
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
                    .font(.system(size: 24))
                    .foregroundStyle(subtask.isDone ? .green : (canToggle ? .secondary : .secondary.opacity(0.3)))
            }
            .buttonStyle(.plain)
            .disabled(!canToggle)

            // Subtask info - tappable for details
            Button {
                showingDetail = true
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(subtask.title)
                        .font(.system(size: 16))
                        .strikethrough(subtask.isDone)
                        .foregroundStyle(subtask.isDone ? .secondary : .primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Info row: assignees, due date, attachments
                    HStack(spacing: 8) {
                        // Assignees
                        if !subtask.assignees.isEmpty {
                            HStack(spacing: 4) {
                                HStack(spacing: -4) {
                                    ForEach(subtask.assignees.prefix(2)) { assignee in
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
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Due date
                        if let dueDate = subtask.dueDate {
                            HStack(spacing: 3) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 10))
                                Text(formatDueDate(dueDate))
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(subtask.isOverdue ? .red : .secondary)
                        }

                        // Attachments count
                        if !subtaskAttachments.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "paperclip")
                                    .font(.system(size: 10))
                                Text("\(subtaskAttachments.count)")
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            // NO chevron - subtasks don't have sub-items
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .sheet(isPresented: $showingDetail) {
            DrawerSubtaskDetailSheet(
                subtask: subtask,
                task: task,
                viewModel: viewModel
            )
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
    @State private var dueDate: Date? = nil
    @State private var showingDatePicker = false

    private var canEdit: Bool {
        viewModel.canEditSubtask(subtask)
    }

    // Assignees limited to task assignees (or all members if no one assigned to task)
    private var availableAssignees: [User] {
        if task.assignees.isEmpty {
            return viewModel.project.members
        }
        return task.assignees
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

                    // Notes & Instructions section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes & Instructions")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        if canEdit {
                            TextField("Add details, instructions, or context...", text: $editedDescription, axis: .vertical)
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
                                Text("No notes")
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
                            if availableAssignees.isEmpty {
                                Text("No one assigned to parent task")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.tertiary)
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(uiColor: .secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(availableAssignees) { member in
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
                                                    Text(member.id == viewModel.currentUser.id ? "Me" : member.displayFirstName)
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

                    // Due date section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Due date")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        if canEdit {
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

                                        Spacer()

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
                                        Spacer()
                                    }
                                }
                                .padding(14)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
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
                        } else {
                            if let date = subtask.dueDate {
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 16))
                                        .foregroundStyle(subtask.isOverdue ? .red : Theme.primary)
                                    Text(formatDueDate(date))
                                        .font(.system(size: 14))
                                        .foregroundStyle(subtask.isOverdue ? .red : .primary)
                                    Spacer()
                                }
                                .padding(14)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                Text("No due date")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.tertiary)
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(uiColor: .secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }

                    // Attachments section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Attachments")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            Spacer()

                            if canEdit {
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
                        }

                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(uiColor: .secondarySystemBackground))
                            .frame(height: 80)
                            .overlay {
                                VStack(spacing: 6) {
                                    Image(systemName: "doc.badge.plus")
                                        .font(.system(size: 24))
                                        .foregroundStyle(.tertiary)
                                    Text("Photos, documents, and files")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.tertiary)
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
                dueDate = subtask.dueDate
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

        // Save due date
        if dueDate != subtask.dueDate {
            viewModel.updateSubtaskDueDate(in: task, subtask: subtask, dueDate: dueDate)
        }

        // Update assignees (only from available assignees, which are task assignees or all members if none)
        let originalIds = Set(subtask.assignees.map { $0.id })
        for member in availableAssignees {
            let wasSelected = originalIds.contains(member.id)
            let isNowSelected = selectedAssigneeIds.contains(member.id)
            if wasSelected != isNowSelected {
                viewModel.toggleSubtaskAssignee(in: task, subtask: subtask, member: member)
            }
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

// MARK: - Add Subtask Sheet

struct AddSubtaskSheet: View {
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var subtaskTitle = ""
    @State private var description = ""
    @State private var selectedAssigneeIds: Set<UUID> = []
    @State private var dueDate: Date? = nil
    @State private var showingDatePicker = false
    @FocusState private var focusedField: Field?

    // Attachment fields
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var attachments: [SubtaskAttachment] = []

    enum Field: Hashable {
        case title, description
    }

    struct SubtaskAttachment: Identifiable {
        let id = UUID()
        var type: AttachmentType
        var fileName: String
    }

    // Assignees are limited to people assigned to the parent task
    // If no one is assigned to the task, show all project members
    private var availableAssignees: [User] {
        if task.assignees.isEmpty {
            return viewModel.project.members
        }
        return task.assignees
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Subtask title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Subtask")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        TextField("What needs to be done?", text: $subtaskTitle)
                            .font(.system(size: 17))
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .focused($focusedField, equals: .title)
                    }

                    // Assignees (limited to task assignees)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Assign to")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            if task.assignees.isEmpty {
                                Text("(any team member)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            } else {
                                Text("(from task assignees)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        FlowLayout(spacing: 8) {
                            ForEach(availableAssignees) { member in
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

                    // Notes/Instructions with attachment icon
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Notes")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            Spacer()

                            // Attachment menu in notes header
                            Menu {
                                PhotosPicker(
                                    selection: $selectedPhotos,
                                    maxSelectionCount: 10,
                                    matching: .images
                                ) {
                                    Label("Photos", systemImage: "photo")
                                }

                                Button {
                                    let fileName = "Document_\(attachments.count + 1).pdf"
                                    attachments.append(SubtaskAttachment(type: .document, fileName: fileName))
                                } label: {
                                    Label("Files", systemImage: "doc")
                                }

                                Button {
                                    let contactName = "Contact_\(attachments.count + 1).vcf"
                                    attachments.append(SubtaskAttachment(type: .contact, fileName: contactName))
                                } label: {
                                    Label("Contacts", systemImage: "person.crop.circle")
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "paperclip")
                                        .font(.system(size: 14))
                                    if !attachments.isEmpty {
                                        Text("\(attachments.count)")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                }
                                .foregroundStyle(attachments.isEmpty ? .secondary : Theme.primary)
                            }
                        }

                        TextField("Add details, instructions, or context...", text: $description, axis: .vertical)
                            .font(.system(size: 15))
                            .lineLimit(4...8)
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .focused($focusedField, equals: .description)

                        // Show attachments inline only when added
                        if !attachments.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(attachments) { attachment in
                                        SubtaskAttachmentChip(
                                            attachment: attachment,
                                            onRemove: {
                                                attachments.removeAll { $0.id == attachment.id }
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("New Subtask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createSubtask()
                    }
                    .fontWeight(.semibold)
                    .disabled(subtaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                focusedField = .title
            }
            .onChange(of: selectedPhotos) { _, newItems in
                Task {
                    for item in newItems {
                        if let _ = try? await item.loadTransferable(type: Data.self) {
                            let fileName = "Photo_\(attachments.count + 1).jpg"
                            attachments.append(SubtaskAttachment(type: .image, fileName: fileName))
                        }
                    }
                    selectedPhotos = []
                }
            }
        }
    }

    private func createSubtask() {
        let assignees = availableAssignees.filter { selectedAssigneeIds.contains($0.id) }
        let desc = description.trimmingCharacters(in: .whitespacesAndNewlines)

        viewModel.addSubtask(
            to: task,
            title: subtaskTitle,
            description: desc.isEmpty ? nil : desc,
            assignees: assignees,
            dueDate: dueDate
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

// MARK: - Task Info Sheet

struct TaskInfoSheet: View {
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var editedTitle: String = ""
    @State private var editedNotes: String = ""
    @State private var selectedAssigneeIds: Set<UUID> = []
    @State private var dueDate: Date? = nil
    @State private var showingDatePicker = false

    private var canEdit: Bool {
        viewModel.canEditTask(task)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Title section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Task")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        if canEdit {
                            TextField("Task title", text: $editedTitle)
                                .font(.system(size: 17))
                                .padding(14)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Text(task.title)
                                .font(.system(size: 17))
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
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
                        } else {
                            if task.assignees.isEmpty {
                                Text("No one assigned")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.tertiary)
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(uiColor: .secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(task.assignees) { assignee in
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

                    // Due date section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Due date")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        if canEdit {
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

                                        Spacer()

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
                                        Spacer()
                                    }
                                }
                                .padding(14)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
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
                        } else {
                            if let date = task.dueDate {
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 16))
                                        .foregroundStyle(task.isOverdue ? .red : Theme.primary)
                                    Text(formatDueDate(date))
                                        .font(.system(size: 14))
                                        .foregroundStyle(task.isOverdue ? .red : .primary)
                                    Spacer()
                                }
                                .padding(14)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                Text("No due date")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.tertiary)
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(uiColor: .secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }

                    // Notes section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes & Instructions")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        if canEdit {
                            TextField("Add details, instructions, or context...", text: $editedNotes, axis: .vertical)
                                .font(.system(size: 15))
                                .lineLimit(4...10)
                                .padding(14)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            if let notes = task.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.system(size: 15))
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(uiColor: .secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                Text("No notes")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.tertiary)
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(uiColor: .secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }

                    // Attachments section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Attachments")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            if !task.attachments.isEmpty {
                                Text("(\(task.attachments.count))")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer()

                            if canEdit {
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
                        }

                        if task.attachments.isEmpty {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(uiColor: .secondarySystemBackground))
                                .frame(height: 80)
                                .overlay {
                                    VStack(spacing: 6) {
                                        Image(systemName: "doc.badge.plus")
                                            .font(.system(size: 24))
                                            .foregroundStyle(.tertiary)
                                        Text("No attachments")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                        } else {
                            // Display attachments in a grid
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                                ForEach(task.attachments) { attachment in
                                    TaskAttachmentCard(attachment: attachment)
                                }
                            }
                        }
                    }

                    // Created by section
                    if let creator = task.createdBy {
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
                                    Text(task.createdAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
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
            .navigationTitle(canEdit ? "Edit Task" : "Task Info")
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
                editedTitle = task.title
                editedNotes = task.notes ?? ""
                selectedAssigneeIds = Set(task.assignees.map { $0.id })
                dueDate = task.dueDate
            }
        }
    }

    private func saveChanges() {
        // Update task via viewModel
        viewModel.updateTask(
            task,
            title: editedTitle,
            assigneeIds: selectedAssigneeIds,
            dueDate: dueDate,
            notes: editedNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editedNotes
        )
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

// MARK: - Task Attachment Card

struct TaskAttachmentCard: View {
    let attachment: Attachment

    var body: some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(uiColor: .secondarySystemBackground))
                .frame(height: 80)
                .overlay {
                    VStack(spacing: 4) {
                        Image(systemName: iconForType)
                            .font(.system(size: 28))
                            .foregroundStyle(colorForType)

                        Text(attachment.type.rawValue.capitalized)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

            VStack(spacing: 2) {
                Text(attachment.fileName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(attachment.fileSizeFormatted)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var iconForType: String {
        switch attachment.type {
        case .image: return "photo.fill"
        case .document: return "doc.fill"
        case .video: return "video.fill"
        case .contact: return "person.crop.circle.fill"
        }
    }

    private var colorForType: Color {
        switch attachment.type {
        case .image: return .blue
        case .document: return .orange
        case .video: return .purple
        case .contact: return .green
        }
    }
}

// MARK: - Subtask Attachment Chip (compact inline display)

struct SubtaskAttachmentChip: View {
    let attachment: AddSubtaskSheet.SubtaskAttachment
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconForType)
                .font(.system(size: 12))
                .foregroundStyle(colorForType)

            Text(attachment.fileName)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(uiColor: .tertiarySystemBackground))
        .clipShape(Capsule())
    }

    private var iconForType: String {
        switch attachment.type {
        case .image: return "photo.fill"
        case .document: return "doc.fill"
        case .video: return "video.fill"
        case .contact: return "person.crop.circle.fill"
        }
    }

    private var colorForType: Color {
        switch attachment.type {
        case .image: return .blue
        case .document: return .orange
        case .video: return .purple
        case .contact: return .green
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
