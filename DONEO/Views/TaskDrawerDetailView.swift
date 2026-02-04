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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.quoteTask(currentTask)
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 14))
                            Text("Comment")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(Theme.primary)
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
            SubtaskInfoSheet(
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

// MARK: - Subtask Info Sheet (View-Only)

struct SubtaskInfoSheet: View {
    let subtask: Subtask
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingEditSheet = false
    @State private var showingInstructionAttachments = false

    private var canEdit: Bool {
        viewModel.canEditSubtask(subtask)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Subtask title with status
                    VStack(alignment: .leading, spacing: 6) {
                        Text(subtask.title)
                            .font(.system(size: 20, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Status badge
                        HStack(spacing: 8) {
                            if subtask.isDone {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                    Text("Completed")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundStyle(.green)
                            } else if subtask.isOverdue {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.system(size: 12))
                                    Text("Overdue")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundStyle(.red)
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "circle")
                                        .font(.system(size: 12))
                                    Text("Pending")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Due date (if set)
                    if let dueDate = subtask.dueDate {
                        HStack(spacing: 10) {
                            Image(systemName: "calendar")
                                .font(.system(size: 16))
                                .foregroundStyle(subtask.isOverdue ? .red : Theme.primary)
                            Text("Due \(formatDueDate(dueDate))")
                                .font(.system(size: 14))
                                .foregroundStyle(subtask.isOverdue ? .red : .primary)
                            Spacer()
                        }
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Assignees
                    if !subtask.assignees.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Assigned to")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            FlowLayout(spacing: 8) {
                                ForEach(subtask.assignees) { assignee in
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Theme.primaryLight)
                                            .frame(width: 24, height: 24)
                                            .overlay {
                                                Text(assignee.avatarInitials)
                                                    .font(.system(size: 9, weight: .medium))
                                                    .foregroundStyle(Theme.primary)
                                            }
                                        Text(assignee.id == viewModel.currentUser.id ? "Me" : assignee.displayFirstName)
                                            .font(.system(size: 13))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(uiColor: .secondarySystemBackground))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    // Notes & Instructions
                    if let description = subtask.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Notes & Instructions")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)

                                // Paperclip for instruction attachments
                                if !subtask.instructionAttachments.isEmpty {
                                    Spacer()
                                    Button {
                                        showingInstructionAttachments = true
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "paperclip")
                                                .font(.system(size: 12))
                                            Text("\(subtask.instructionAttachments.count)")
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                        .foregroundStyle(Theme.primary)
                                    }
                                }
                            }

                            Text(description)
                                .font(.system(size: 15))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            // Show instruction attachments when tapped
                            if showingInstructionAttachments {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                                    ForEach(subtask.instructionAttachments) { attachment in
                                        TaskAttachmentCard(attachment: attachment)
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                    } else if !subtask.instructionAttachments.isEmpty {
                        // Show attachments even if no description
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Support Documents")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Button {
                                    showingInstructionAttachments.toggle()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "paperclip")
                                            .font(.system(size: 12))
                                        Text("\(subtask.instructionAttachments.count)")
                                            .font(.system(size: 12, weight: .medium))
                                        Image(systemName: showingInstructionAttachments ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 10))
                                    }
                                    .foregroundStyle(Theme.primary)
                                }
                            }

                            if showingInstructionAttachments {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                                    ForEach(subtask.instructionAttachments) { attachment in
                                        TaskAttachmentCard(attachment: attachment)
                                    }
                                }
                            }
                        }
                    }

                    // Created by section
                    if let creator = subtask.createdBy {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color.purple.opacity(0.2))
                                .frame(width: 28, height: 28)
                                .overlay {
                                    Text(creator.avatarInitials)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.purple)
                                }
                            Text("Created by \(creator.displayFirstName)")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text(subtask.createdAt.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.system(size: 13))
                                .foregroundStyle(.tertiary)
                            Spacer()
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Subtask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                // Edit button (only for creator/admin)
                if canEdit {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingEditSheet = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                EditSubtaskSheet(subtask: subtask, task: task, viewModel: viewModel)
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

// MARK: - Edit Subtask Sheet (for creator/admin only)

struct EditSubtaskSheet: View {
    let subtask: Subtask
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var editedTitle: String = ""
    @State private var editedDescription: String = ""
    @State private var selectedAssigneeIds: Set<UUID> = []
    @State private var dueDate: Date? = nil
    @State private var showingDatePicker = false

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

                        TextField("Subtask title", text: $editedTitle)
                            .font(.system(size: 17))
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
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
                    }

                    // Due date section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Due date")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

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
                    }

                    // Notes & Instructions section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes & Instructions")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        TextField("Add details, instructions, or context...", text: $editedDescription, axis: .vertical)
                            .font(.system(size: 15))
                            .lineLimit(3...8)
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Edit Subtask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(editedTitle.trimmingCharacters(in: .whitespaces).isEmpty)
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

// MARK: - Task Info Sheet (View-Only)

struct TaskInfoSheet: View {
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingInstructionAttachments = false
    @State private var showingEditSheet = false

    // Deliverables attachment states
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showingDocumentPicker = false
    @State private var showingContactPicker = false
    @State private var showingUploadSheet = false
    @State private var pendingUploadType: AttachmentType = .image
    @State private var pendingUploadCount: Int = 0

    private var canEdit: Bool {
        viewModel.canEditTask(task)
    }

    // Instruction attachments (from creator)
    private var instructionAttachments: [Attachment] {
        task.attachments.filter { $0.isInstruction }
    }

    // Deliverable attachments (from team)
    private var deliverableAttachments: [Attachment] {
        task.attachments.filter { !$0.isInstruction }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Task title (view-only)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(task.title)
                            .font(.system(size: 20, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Status badge
                        HStack(spacing: 8) {
                            if task.status == .done {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                    Text("Completed")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundStyle(.green)
                            } else if task.isOverdue {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.system(size: 12))
                                    Text("Overdue")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundStyle(.red)
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 12))
                                    Text("In Progress")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundStyle(.orange)
                            }

                            if let dueDate = task.dueDate {
                                Text("·")
                                    .foregroundStyle(.tertiary)
                                Text("Due \(formatDueDate(dueDate))")
                                    .font(.system(size: 12))
                                    .foregroundStyle(task.isOverdue ? .red : .secondary)
                            }
                        }
                    }

                    Divider()

                    // Assignees section (view-only)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Assigned to")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        if task.assignees.isEmpty {
                            Text("No one assigned")
                                .font(.system(size: 14))
                                .foregroundStyle(.tertiary)
                        } else {
                            HStack(spacing: -8) {
                                ForEach(task.assignees.prefix(5)) { assignee in
                                    Circle()
                                        .fill(Theme.primaryLight)
                                        .frame(width: 36, height: 36)
                                        .overlay {
                                            Text(assignee.avatarInitials)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(Theme.primary)
                                        }
                                        .overlay(
                                            Circle()
                                                .stroke(Color(uiColor: .systemBackground), lineWidth: 2)
                                        )
                                }
                                if task.assignees.count > 5 {
                                    Circle()
                                        .fill(Color(uiColor: .secondarySystemBackground))
                                        .frame(width: 36, height: 36)
                                        .overlay {
                                            Text("+\(task.assignees.count - 5)")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(.secondary)
                                        }
                                        .overlay(
                                            Circle()
                                                .stroke(Color(uiColor: .systemBackground), lineWidth: 2)
                                        )
                                }
                            }
                        }
                    }

                    // Notes & Instructions section (view-only)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Notes & Instructions")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            Spacer()

                            // Paperclip for instruction/reference attachments
                            if !instructionAttachments.isEmpty {
                                Button {
                                    showingInstructionAttachments.toggle()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "paperclip")
                                            .font(.system(size: 14))
                                        Text("\(instructionAttachments.count)")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundStyle(Theme.primary)
                                }
                            }
                        }

                        if let notes = task.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.system(size: 15))
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Text("No instructions provided")
                                .font(.system(size: 14))
                                .foregroundStyle(.tertiary)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Show instruction attachments when expanded
                        if showingInstructionAttachments && !instructionAttachments.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Reference files")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)

                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                                    ForEach(instructionAttachments) { attachment in
                                        TaskAttachmentCard(attachment: attachment)
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
                    }

                    // Deliverables section (everyone can add)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Deliverables")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            if !deliverableAttachments.isEmpty {
                                Text("(\(deliverableAttachments.count))")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer()

                            // Everyone can add deliverables - Menu with options
                            Menu {
                                PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 10, matching: .images) {
                                    Label("Photos", systemImage: "photo")
                                }

                                Button {
                                    // Show upload sheet for document
                                    pendingUploadType = .document
                                    pendingUploadCount = 1
                                    showingUploadSheet = true
                                } label: {
                                    Label("Documents", systemImage: "doc")
                                }

                                Button {
                                    // Show upload sheet for contact
                                    pendingUploadType = .contact
                                    pendingUploadCount = 1
                                    showingUploadSheet = true
                                } label: {
                                    Label("Contacts", systemImage: "person.crop.circle")
                                }
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

                        // Grouped deliverables by type
                        if deliverableAttachments.isEmpty {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(uiColor: .secondarySystemBackground))
                                .frame(height: 70)
                                .overlay {
                                    VStack(spacing: 4) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 20))
                                            .foregroundStyle(.tertiary)
                                        Text("Upload your work here")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                // Photos
                                let photos = deliverableAttachments.filter { $0.type == .image }
                                if !photos.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "photo")
                                                .font(.system(size: 11))
                                            Text("Photos (\(photos.count))")
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                        .foregroundStyle(.secondary)

                                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 8)], spacing: 8) {
                                            ForEach(photos) { attachment in
                                                TaskAttachmentCard(attachment: attachment, compact: true)
                                            }
                                        }
                                    }
                                }

                                // Documents
                                let documents = deliverableAttachments.filter { $0.type == .document }
                                if !documents.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "doc")
                                                .font(.system(size: 11))
                                            Text("Documents (\(documents.count))")
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                        .foregroundStyle(.secondary)

                                        VStack(spacing: 6) {
                                            ForEach(documents) { attachment in
                                                DocumentRowView(attachment: attachment)
                                            }
                                        }
                                    }
                                }

                                // Contacts
                                let contacts = deliverableAttachments.filter { $0.type == .contact }
                                if !contacts.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "person.crop.circle")
                                                .font(.system(size: 11))
                                            Text("Contacts (\(contacts.count))")
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                        .foregroundStyle(.secondary)

                                        VStack(spacing: 6) {
                                            ForEach(contacts) { attachment in
                                                ContactRowView(attachment: attachment)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: selectedPhotos) { _, newPhotos in
                        guard !newPhotos.isEmpty else { return }
                        // Show upload sheet with comment option
                        pendingUploadType = .image
                        pendingUploadCount = newPhotos.count
                        selectedPhotos = []
                        showingUploadSheet = true
                    }

                    // Created by section
                    if let creator = task.createdBy {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color.purple.opacity(0.2))
                                .frame(width: 28, height: 28)
                                .overlay {
                                    Text(creator.avatarInitials)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.purple)
                                }
                            Text("Created by \(creator.displayFirstName)")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text(task.createdAt.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.system(size: 13))
                                .foregroundStyle(.tertiary)
                            Spacer()
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                // Edit button (only for creator/admin)
                if canEdit {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingEditSheet = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                EditTaskSheet(task: task, viewModel: viewModel)
            }
            .sheet(isPresented: $showingUploadSheet) {
                DeliverableUploadSheet(
                    task: task,
                    attachmentType: pendingUploadType,
                    itemCount: pendingUploadCount,
                    viewModel: viewModel,
                    onDismiss: {
                        showingUploadSheet = false
                        pendingUploadCount = 0
                    }
                )
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
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }
}

// MARK: - Edit Task Sheet (for creator/admin only)

struct EditTaskSheet: View {
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var editedTitle: String = ""
    @State private var editedNotes: String = ""
    @State private var selectedAssigneeIds: Set<UUID> = []
    @State private var dueDate: Date? = nil
    @State private var showingDatePicker = false

    // Instruction attachment states
    @State private var selectedPhotos: [PhotosPickerItem] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Title section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Task Title")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        TextField("Task title", text: $editedTitle)
                            .font(.system(size: 17))
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Assignees section
                    VStack(alignment: .leading, spacing: 8) {
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

                    // Due date section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Due date")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

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
                    }

                    // Notes & Instructions section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Notes & Instructions")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            Spacer()

                            // Add instruction attachment
                            Menu {
                                PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 10, matching: .images) {
                                    Label("Photos", systemImage: "photo")
                                }
                                Button {
                                    // Add document
                                } label: {
                                    Label("Document", systemImage: "doc")
                                }
                            } label: {
                                Image(systemName: "paperclip")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        TextField("Add details, instructions, or context...", text: $editedNotes, axis: .vertical)
                            .font(.system(size: 15))
                            .lineLimit(4...10)
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Existing instruction attachments
                        let instructionAttachments = task.attachments.filter { $0.isInstruction }
                        if !instructionAttachments.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Reference files (\(instructionAttachments.count))")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)

                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                                    ForEach(instructionAttachments) { attachment in
                                        TaskAttachmentCard(attachment: attachment, compact: true)
                                    }
                                }
                            }
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(editedTitle.trimmingCharacters(in: .whitespaces).isEmpty)
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
        } else {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }
}

// MARK: - Task Attachment Card

struct TaskAttachmentCard: View {
    let attachment: Attachment
    var compact: Bool = false

    var body: some View {
        VStack(spacing: compact ? 4 : 6) {
            RoundedRectangle(cornerRadius: compact ? 8 : 10)
                .fill(Color(uiColor: .secondarySystemBackground))
                .frame(height: compact ? 60 : 80)
                .overlay {
                    VStack(spacing: 4) {
                        Image(systemName: iconForType)
                            .font(.system(size: compact ? 22 : 28))
                            .foregroundStyle(colorForType)

                        if !compact {
                            Text(attachment.type.rawValue.capitalized)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

            if !compact {
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

// MARK: - Document Row View

struct DocumentRowView: View {
    let attachment: Attachment

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.orange.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.orange)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.fileName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(attachment.fileSizeFormatted)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Contact Row View

struct ContactRowView: View {
    let attachment: Attachment

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.green.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.fileName.replacingOccurrences(of: ".vcf", with: ""))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("Contact")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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

// MARK: - Deliverable Upload Sheet

struct DeliverableUploadSheet: View {
    let task: DONEOTask
    let attachmentType: AttachmentType
    let itemCount: Int
    @Bindable var viewModel: ProjectChatViewModel
    let onDismiss: () -> Void

    @State private var comment = ""
    @FocusState private var isCommentFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Preview of what's being uploaded
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(colorForType.opacity(0.15))
                            .frame(width: 60, height: 60)

                        Image(systemName: iconForType)
                            .font(.system(size: 26))
                            .foregroundStyle(colorForType)
                    }

                    Text(uploadLabel)
                        .font(.system(size: 17, weight: .medium))

                    Text("for task: \(task.title)")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(.top, 20)

                // Comment input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add a comment (optional)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextField("E.g., Here are the photos from today's inspection...", text: $comment, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .focused($isCommentFocused)
                }
                .padding(.horizontal)

                Spacer()

                // Upload button
                Button {
                    uploadDeliverable()
                } label: {
                    Text("Upload to Chat")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.primary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle("Upload Deliverable")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
    }

    private var uploadLabel: String {
        switch attachmentType {
        case .image:
            return itemCount == 1 ? "1 Photo" : "\(itemCount) Photos"
        case .document:
            return itemCount == 1 ? "1 Document" : "\(itemCount) Documents"
        case .video:
            return itemCount == 1 ? "1 Video" : "\(itemCount) Videos"
        case .contact:
            return itemCount == 1 ? "1 Contact" : "\(itemCount) Contacts"
        }
    }

    private var iconForType: String {
        switch attachmentType {
        case .image: return "photo.fill"
        case .document: return "doc.fill"
        case .video: return "video.fill"
        case .contact: return "person.crop.circle.fill"
        }
    }

    private var colorForType: Color {
        switch attachmentType {
        case .image: return .blue
        case .document: return .orange
        case .video: return .purple
        case .contact: return .green
        }
    }

    private func uploadDeliverable() {
        // Create placeholder items for now (in production, these would be real file URLs)
        let items: [(type: AttachmentType, fileName: String, fileSize: Int64, thumbnailURL: URL?, fileURL: URL?)] = (0..<itemCount).map { index in
            let fileName: String
            switch attachmentType {
            case .image: fileName = "Photo_\(Date().formatted(.dateTime.month().day().hour().minute()))_\(index + 1).jpg"
            case .document: fileName = "Document_\(index + 1).pdf"
            case .video: fileName = "Video_\(index + 1).mp4"
            case .contact: fileName = "Contact_\(index + 1).vcf"
            }
            return (type: attachmentType, fileName: fileName, fileSize: Int64.random(in: 100_000...5_000_000), thumbnailURL: nil, fileURL: nil)
        }

        let trimmedComment = comment.trimmingCharacters(in: .whitespaces)
        viewModel.addDeliverablesToTask(
            task,
            items: items,
            comment: trimmedComment.isEmpty ? nil : trimmedComment
        )

        onDismiss()
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
