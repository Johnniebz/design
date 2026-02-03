import SwiftUI
import Observation

// MARK: - Activity View Model

@Observable
final class ActivityViewModel {
    private var dataService = MockDataService.shared

    var currentUser: User {
        dataService.currentUser
    }

    // MARK: - Stats

    var newTasksCount: Int {
        newTasks.count
    }

    var doneThisWeekCount: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return dataService.projects.flatMap { $0.tasks }
            .filter { $0.status == .done && $0.lastActivity > weekAgo }
            .count
    }

    // MARK: - New Tasks (need acknowledgment)

    struct NewTaskItem: Identifiable {
        let id: UUID
        let title: String
        let projectName: String
        let projectId: UUID
        let taskId: UUID
        let dueDate: Date?
        let assignedBy: String?
        let createdAt: Date
    }

    var newTasks: [NewTaskItem] {
        var items: [NewTaskItem] = []

        for project in dataService.projects {
            for task in project.tasks {
                // Task is new if assigned to current user but not acknowledged
                if task.isNew(for: currentUser.id) {
                    items.append(NewTaskItem(
                        id: task.id,
                        title: task.title,
                        projectName: project.name,
                        projectId: project.id,
                        taskId: task.id,
                        dueDate: task.dueDate,
                        assignedBy: task.createdBy?.name,
                        createdAt: task.createdAt
                    ))
                }
            }
        }

        // Sort by most recent first
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - My Tasks (acknowledged, grouped by project)

    struct ProjectTaskGroup: Identifiable {
        let id: UUID
        let projectName: String
        let projectId: UUID
        var tasks: [TaskItem]
    }

    struct TaskItem: Identifiable {
        let id: UUID
        let title: String
        let dueDate: Date?
        let isOverdue: Bool
        let isDueToday: Bool
        let subtaskProgress: (done: Int, total: Int)?
        let projectId: UUID
    }

    var myTasksByProject: [ProjectTaskGroup] {
        var groups: [ProjectTaskGroup] = []

        for project in dataService.projects {
            // Tasks assigned to current user that are acknowledged and pending
            let myTasks = project.tasks.filter { task in
                task.status == .pending &&
                task.assignees.contains(where: { $0.id == currentUser.id }) &&
                task.isAcknowledged(by: currentUser.id)
            }

            if !myTasks.isEmpty {
                let taskItems = myTasks.map { task -> TaskItem in
                    let doneSubtasks = task.subtasks.filter { $0.isDone }.count
                    let totalSubtasks = task.subtasks.count
                    return TaskItem(
                        id: task.id,
                        title: task.title,
                        dueDate: task.dueDate,
                        isOverdue: task.isOverdue,
                        isDueToday: task.isDueToday,
                        subtaskProgress: totalSubtasks > 0 ? (doneSubtasks, totalSubtasks) : nil,
                        projectId: project.id
                    )
                }

                groups.append(ProjectTaskGroup(
                    id: project.id,
                    projectName: project.name,
                    projectId: project.id,
                    tasks: taskItems
                ))
            }
        }

        return groups
    }

    // MARK: - Actions

    func acceptTask(projectId: UUID, taskId: UUID, message: String?) {
        guard let projectIndex = dataService.projects.firstIndex(where: { $0.id == projectId }),
              let taskIndex = dataService.projects[projectIndex].tasks.firstIndex(where: { $0.id == taskId }) else {
            return
        }
        dataService.projects[projectIndex].tasks[taskIndex].acknowledgedBy.insert(currentUser.id)

        // Send acceptance message to project chat
        let task = dataService.projects[projectIndex].tasks[taskIndex]
        let userMessage = message?.isEmpty == false ? ": \(message!)" : ""
        let content = "✓ Accepted\(userMessage)"
        let chatMessage = Message(
            content: content,
            sender: currentUser,
            referencedTask: TaskReference(taskId: task.id, taskTitle: task.title)
        )
        dataService.projects[projectIndex].messages.append(chatMessage)
    }

    func declineTask(projectId: UUID, taskId: UUID, reason: String?) {
        guard let projectIndex = dataService.projects.firstIndex(where: { $0.id == projectId }),
              let taskIndex = dataService.projects[projectIndex].tasks.firstIndex(where: { $0.id == taskId }) else {
            return
        }

        let task = dataService.projects[projectIndex].tasks[taskIndex]

        // Send decline message to project chat
        let userMessage = reason?.isEmpty == false ? ": \(reason!)" : ""
        let content = "✗ Declined\(userMessage)"
        let chatMessage = Message(
            content: content,
            sender: currentUser,
            referencedTask: TaskReference(taskId: task.id, taskTitle: task.title)
        )
        dataService.projects[projectIndex].messages.append(chatMessage)

        // Remove current user from assignees
        dataService.projects[projectIndex].tasks[taskIndex].assignees.removeAll { $0.id == currentUser.id }
    }

    func sendTaskMessage(projectId: UUID, taskId: UUID, message: String) {
        guard let projectIndex = dataService.projects.firstIndex(where: { $0.id == projectId }),
              let taskIndex = dataService.projects[projectIndex].tasks.firstIndex(where: { $0.id == taskId }) else {
            return
        }

        let task = dataService.projects[projectIndex].tasks[taskIndex]
        let chatMessage = Message(
            content: message,
            sender: currentUser,
            referencedTask: TaskReference(taskId: task.id, taskTitle: task.title)
        )
        dataService.projects[projectIndex].messages.append(chatMessage)
    }

    func getTaskNotes(projectId: UUID, taskId: UUID) -> String? {
        guard let project = dataService.projects.first(where: { $0.id == projectId }),
              let task = project.tasks.first(where: { $0.id == taskId }) else {
            return nil
        }
        return task.notes
    }

    func getTaskAssignees(projectId: UUID, taskId: UUID) -> [User] {
        guard let project = dataService.projects.first(where: { $0.id == projectId }),
              let task = project.tasks.first(where: { $0.id == taskId }) else {
            return []
        }
        return task.assignees
    }

    func toggleTask(projectId: UUID, taskId: UUID) {
        guard let projectIndex = dataService.projects.firstIndex(where: { $0.id == projectId }),
              let taskIndex = dataService.projects[projectIndex].tasks.firstIndex(where: { $0.id == taskId }) else {
            return
        }
        let currentStatus = dataService.projects[projectIndex].tasks[taskIndex].status
        dataService.projects[projectIndex].tasks[taskIndex].status = currentStatus == .pending ? .done : .pending
    }

    func getProject(id: UUID) -> Project? {
        dataService.projects.first { $0.id == id }
    }
}

// MARK: - Activity View

struct ActivityView: View {
    @State private var viewModel = ActivityViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var selectedNewTask: ActivityViewModel.NewTaskItem?
    @State private var showTaskDetailSheet = false
    @State private var selectedMyTask: (task: ActivityViewModel.TaskItem, group: ActivityViewModel.ProjectTaskGroup)?
    @State private var showMyTaskDetailSheet = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 24) {
                    // Stats bar
                    statsBar
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // New Tasks section (need acknowledgment)
                    if !viewModel.newTasks.isEmpty {
                        newTasksSection
                    }

                    // My Tasks section (acknowledged, grouped by project)
                    myTasksSection
                        .padding(.bottom, 16)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Activity")
            .navigationDestination(for: UUID.self) { projectId in
                if let project = viewModel.getProject(id: projectId) {
                    ProjectChatView(project: project)
                }
            }
            .sheet(isPresented: $showTaskDetailSheet) {
                if let task = selectedNewTask {
                    NewTaskDetailSheet(
                        task: task,
                        viewModel: viewModel
                    ) { action, message in
                        withAnimation(.spring(response: 0.3)) {
                            switch action {
                            case .accept:
                                viewModel.acceptTask(projectId: task.projectId, taskId: task.taskId, message: message)
                            case .decline:
                                viewModel.declineTask(projectId: task.projectId, taskId: task.taskId, reason: message ?? "I can't take this on")
                            case .ask:
                                if let msg = message, !msg.isEmpty {
                                    viewModel.sendTaskMessage(projectId: task.projectId, taskId: task.taskId, message: msg)
                                }
                            }
                        }
                        showTaskDetailSheet = false
                        selectedNewTask = nil
                    } onCancel: {
                        showTaskDetailSheet = false
                        selectedNewTask = nil
                    }
                }
            }
            .sheet(isPresented: $showMyTaskDetailSheet) {
                if let selected = selectedMyTask {
                    MyTaskDetailSheet(
                        task: selected.task,
                        projectName: selected.group.projectName,
                        viewModel: viewModel
                    ) { action, message in
                        switch action {
                        case .done:
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.toggleTask(projectId: selected.group.projectId, taskId: selected.task.id)
                            }
                        case .message:
                            if let msg = message, !msg.isEmpty {
                                viewModel.sendTaskMessage(projectId: selected.group.projectId, taskId: selected.task.id, message: msg)
                            }
                        case .goToProject:
                            showMyTaskDetailSheet = false
                            selectedMyTask = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                navigationPath.append(selected.group.projectId)
                            }
                            return
                        }
                        showMyTaskDetailSheet = false
                        selectedMyTask = nil
                    } onCancel: {
                        showMyTaskDetailSheet = false
                        selectedMyTask = nil
                    }
                }
            }
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 12) {
            StatCard(
                value: viewModel.newTasksCount,
                label: "New",
                color: viewModel.newTasksCount > 0 ? Theme.primary : .secondary
            )

            StatCard(
                value: viewModel.myTasksByProject.flatMap { $0.tasks }.count,
                label: "Active",
                color: .orange
            )

            StatCard(
                value: viewModel.doneThisWeekCount,
                label: "Done",
                color: .green
            )
        }
    }

    // MARK: - New Tasks Section

    private var newTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "bell.badge.fill")
                    .foregroundStyle(Theme.primary)
                Text("NEW TASKS")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(viewModel.newTasks.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.primary)
                    .clipShape(Capsule())
            }
            .padding(.horizontal)

            VStack(spacing: 12) {
                ForEach(viewModel.newTasks) { task in
                    NewTaskCard(task: task) {
                        selectedNewTask = task
                        showTaskDetailSheet = true
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - My Tasks Section

    private var myTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "checklist")
                    .foregroundStyle(.secondary)
                Text("MY TASKS")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            if viewModel.myTasksByProject.isEmpty {
                emptyStateCard(message: "No active tasks")
            } else {
                VStack(spacing: 16) {
                    ForEach(viewModel.myTasksByProject) { group in
                        ProjectTaskGroupView(group: group, onToggle: { taskId in
                            viewModel.toggleTask(projectId: group.projectId, taskId: taskId)
                        }, onTap: { taskId in
                            if let task = group.tasks.first(where: { $0.id == taskId }) {
                                selectedMyTask = (task: task, group: group)
                                showMyTaskDetailSheet = true
                            }
                        }, onProjectTap: {
                            navigationPath.append(group.projectId)
                        })
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Helper Views

    private func emptyStateCard(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(color)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - New Task Card (Simplified - tap to open detail)

struct NewTaskCard: View {
    let task: ActivityViewModel.NewTaskItem
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                // Left accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.primary)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 6) {
                    // Project + assignee
                    HStack {
                        Text(task.projectName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.primary)

                        if let assignedBy = task.assignedBy {
                            Text("• from \(assignedBy.components(separatedBy: " ").first ?? assignedBy)")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Time ago
                        Text(timeAgo(task.createdAt))
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }

                    // Task title
                    Text(task.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Due date if exists
                    if let dueDate = task.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11))
                            Text(formatDueDate(dueDate))
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(dueDateColor(dueDate))
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(uiColor: .systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func timeAgo(_ date: Date) -> String {
        let minutes = Int(-date.timeIntervalSinceNow / 60)
        if minutes < 60 {
            return "\(minutes)m"
        } else if minutes < 1440 {
            return "\(minutes / 60)h"
        } else {
            return "\(minutes / 1440)d"
        }
    }

    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Due today"
        } else if calendar.isDateInTomorrow(date) {
            return "Due tomorrow"
        } else if date < Date() {
            let days = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
            return "\(days)d overdue"
        } else {
            return "Due \(date.formatted(.dateTime.month(.abbreviated).day()))"
        }
    }

    private func dueDateColor(_ date: Date) -> Color {
        if date < Calendar.current.startOfDay(for: Date()) {
            return .red
        } else if Calendar.current.isDateInToday(date) {
            return .orange
        } else {
            return .secondary
        }
    }
}

// MARK: - Project Task Group View

struct ProjectTaskGroupView: View {
    let group: ActivityViewModel.ProjectTaskGroup
    let onToggle: (UUID) -> Void
    let onTap: (UUID) -> Void
    let onProjectTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Project header - tappable to go to project
            Button {
                onProjectTap()
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Theme.primaryLight)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Text(String(group.projectName.prefix(1)).uppercased())
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.primary)
                        }

                    Text(group.projectName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("\(group.tasks.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .clipShape(Capsule())

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
            }
            .buttonStyle(.plain)

            // Tasks - tap to see details
            ForEach(group.tasks) { task in
                Button {
                    onTap(task.id)
                } label: {
                    ProjectTaskRow(task: task) {
                        onToggle(task.id)
                    }
                }
                .buttonStyle(.plain)

                if task.id != group.tasks.last?.id {
                    Divider()
                        .padding(.leading, 48)
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Project Task Row

struct ProjectTaskRow: View {
    let task: ActivityViewModel.TaskItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onToggle()
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(task.title)
                        .font(.system(size: 15))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    // Overdue/Today indicator
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
                    if let progress = task.subtaskProgress {
                        HStack(spacing: 3) {
                            Image(systemName: "checklist")
                                .font(.system(size: 10))
                            Text("\(progress.done)/\(progress.total)")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.secondary)
                    }

                    if let dueDate = task.dueDate, !task.isOverdue && !task.isDueToday {
                        if task.subtaskProgress != nil {
                            Text("•")
                                .foregroundStyle(.tertiary)
                        }
                        Text(formatDueDate(dueDate))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func formatDueDate(_ date: Date) -> String {
        if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }
}

// MARK: - Task Action Type

enum TaskAction {
    case accept
    case ask
    case decline
}

// MARK: - New Task Detail Sheet

struct NewTaskDetailSheet: View {
    let task: ActivityViewModel.NewTaskItem
    let viewModel: ActivityViewModel
    let onAction: (TaskAction, String?) -> Void
    let onCancel: () -> Void

    @State private var message = ""
    @FocusState private var isMessageFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    taskContent
                }
                bottomActionBar
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onCancel() }
                }
            }
        }
    }

    private var taskContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            taskHeader
            dueDateSection
            assigneesSection
            notesSection
        }
        .padding(.top, 16)
        .padding(.bottom, 100)
    }

    private var taskHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Theme.primaryLight)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Text(String(task.projectName.prefix(1)).uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                    }
                Text(task.projectName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.primary)
                Spacer()
                if let assignedBy = task.assignedBy {
                    Text("from \(assignedBy)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            Text(task.title)
                .font(.system(size: 20, weight: .bold))
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var dueDateSection: some View {
        if let dueDate = task.dueDate {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                Text(formatDueDate(dueDate))
                    .font(.system(size: 15))
            }
            .foregroundStyle(dueDateColor(dueDate))
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var assigneesSection: some View {
        let assignees = viewModel.getTaskAssignees(projectId: task.projectId, taskId: task.taskId)
        if !assignees.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Assigned to")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(assignees) { user in
                        AssigneeChip(user: user)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        if let notes = viewModel.getTaskNotes(projectId: task.projectId, taskId: task.taskId), !notes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes & Instructions")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text(notes)
                    .font(.system(size: 15))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal)
        }
    }

    private var bottomActionBar: some View {
        VStack(spacing: 12) {
            TextField("Add a message (optional)...", text: $message)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .focused($isMessageFocused)

            HStack(spacing: 10) {
                acceptButton
                askButton
                declineButton
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
    }

    private var acceptButton: some View {
        Button {
            onAction(.accept, message.isEmpty ? nil : message)
        } label: {
            Text("Accept")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var askButton: some View {
        Button {
            onAction(.ask, message.isEmpty ? nil : message)
        } label: {
            Text("Ask")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.primaryLight)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(message.trimmingCharacters(in: .whitespaces).isEmpty)
        .opacity(message.isEmpty ? 0.5 : 1)
    }

    private var declineButton: some View {
        Button {
            onAction(.decline, message.isEmpty ? nil : message)
        } label: {
            Text("Decline")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Due today" }
        if calendar.isDateInTomorrow(date) { return "Due tomorrow" }
        if date < Date() {
            let days = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
            return "\(days) day\(days == 1 ? "" : "s") overdue"
        }
        return "Due \(date.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private func dueDateColor(_ date: Date) -> Color {
        if date < Calendar.current.startOfDay(for: Date()) { return .red }
        if Calendar.current.isDateInToday(date) { return .orange }
        return .primary
    }
}

// MARK: - Assignee Chip

struct AssigneeChip: View {
    let user: User

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(uiColor: .tertiarySystemFill))
                .frame(width: 24, height: 24)
                .overlay {
                    Text(user.avatarInitials)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            Text(user.displayFirstName)
                .font(.system(size: 13))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(Capsule())
    }
}

// MARK: - My Task Action Type

enum MyTaskAction {
    case done
    case message
    case goToProject
}

// MARK: - My Task Detail Sheet

struct MyTaskDetailSheet: View {
    let task: ActivityViewModel.TaskItem
    let projectName: String
    let viewModel: ActivityViewModel
    let onAction: (MyTaskAction, String?) -> Void
    let onCancel: () -> Void

    @State private var message = ""
    @FocusState private var isMessageFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    taskContent
                }
                bottomActionBar
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onCancel() }
                }
            }
        }
    }

    private var taskContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Task header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(Theme.primaryLight)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Text(String(projectName.prefix(1)).uppercased())
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.primary)
                        }
                    Text(projectName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.primary)
                    Spacer()
                }

                HStack(spacing: 8) {
                    Text(task.title)
                        .font(.system(size: 20, weight: .bold))

                    if task.isOverdue {
                        Text("OVERDUE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else if task.isDueToday {
                        Text("TODAY")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            .padding(.horizontal)

            // Due date
            if let dueDate = task.dueDate {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                    Text(formatDueDate(dueDate))
                        .font(.system(size: 15))
                }
                .foregroundStyle(dueDateColor(dueDate))
                .padding(.horizontal)
            }

            // Subtask progress
            if let progress = task.subtaskProgress {
                HStack(spacing: 8) {
                    Image(systemName: "checklist")
                    Text("\(progress.done) of \(progress.total) subtasks completed")
                        .font(.system(size: 15))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            }

            // Assignees
            let assignees = viewModel.getTaskAssignees(projectId: task.projectId, taskId: task.id)
            if !assignees.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Assigned to")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(assignees) { user in
                            AssigneeChip(user: user)
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Notes
            if let notes = viewModel.getTaskNotes(projectId: task.projectId, taskId: task.id), !notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes & Instructions")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text(notes)
                        .font(.system(size: 15))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 100)
    }

    private var bottomActionBar: some View {
        VStack(spacing: 12) {
            // Message input
            HStack(spacing: 8) {
                TextField("Send a message to the group...", text: $message)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .focused($isMessageFocused)

                if !message.isEmpty {
                    Button {
                        onAction(.message, message)
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.primary)
                    }
                }
            }

            // Action buttons
            HStack(spacing: 10) {
                Button {
                    onAction(.done, nil)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Mark Done")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    onAction(.goToProject, nil)
                } label: {
                    HStack(spacing: 6) {
                        Text("Open Project")
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Theme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.primaryLight)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
    }

    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Due today" }
        if calendar.isDateInTomorrow(date) { return "Due tomorrow" }
        if date < Date() {
            let days = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
            return "\(days) day\(days == 1 ? "" : "s") overdue"
        }
        return "Due \(date.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private func dueDateColor(_ date: Date) -> Color {
        if date < Calendar.current.startOfDay(for: Date()) { return .red }
        if Calendar.current.isDateInToday(date) { return .orange }
        return .primary
    }
}

#Preview {
    ActivityView()
}
