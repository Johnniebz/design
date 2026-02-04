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

    // MARK: - New Tasks (need acknowledgment) - Grouped by Project

    struct NewTaskItem: Identifiable {
        let id: UUID
        let title: String
        let projectName: String
        let projectId: UUID
        let taskId: UUID
        let dueDate: Date?
        let assignedBy: String?
        let createdAt: Date
        let isOverdue: Bool
        let isDueToday: Bool
    }

    struct NewTaskGroup: Identifiable {
        let id: UUID
        let projectName: String
        let projectId: UUID
        var tasks: [NewTaskItem]
    }

    var newTasksByProject: [NewTaskGroup] {
        var groups: [NewTaskGroup] = []

        for project in dataService.projects {
            let newTasksInProject = project.tasks.filter { task in
                task.isNew(for: currentUser.id)
            }

            if !newTasksInProject.isEmpty {
                let taskItems = newTasksInProject.map { task in
                    NewTaskItem(
                        id: task.id,
                        title: task.title,
                        projectName: project.name,
                        projectId: project.id,
                        taskId: task.id,
                        dueDate: task.dueDate,
                        assignedBy: task.createdBy?.name,
                        createdAt: task.createdAt,
                        isOverdue: task.isOverdue,
                        isDueToday: task.isDueToday
                    )
                }.sorted { $0.createdAt > $1.createdAt }

                groups.append(NewTaskGroup(
                    id: project.id,
                    projectName: project.name,
                    projectId: project.id,
                    tasks: taskItems
                ))
            }
        }

        return groups
    }

    var newTasks: [NewTaskItem] {
        newTasksByProject.flatMap { $0.tasks }
    }

    // MARK: - My Tasks (acknowledged, grouped by project)

    struct ProjectTaskGroup: Identifiable {
        let id: UUID
        let projectName: String
        let projectId: UUID
        var tasks: [TaskItem]
        var newTasksCount: Int { tasks.filter { $0.isNew }.count }
    }

    struct SubtaskItem: Identifiable {
        let id: UUID
        let title: String
        let isDone: Bool
        let description: String?
        let dueDate: Date?
        let createdBy: User?
        let createdAt: Date
    }

    struct AttachmentItem: Identifiable {
        let id: UUID
        let type: AttachmentType
        let category: AttachmentCategory
        let fileName: String
        let fileSize: Int64
        let uploadedByName: String
        let uploadedAt: Date
        let caption: String?

        var iconName: String {
            switch type {
            case .image: return "photo.fill"
            case .video: return "video.fill"
            case .document: return "doc.fill"
            case .contact: return "person.crop.circle.fill"
            }
        }

        var fileSizeFormatted: String {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return formatter.string(fromByteCount: fileSize)
        }

        var timeAgo: String {
            let minutes = Int(-uploadedAt.timeIntervalSinceNow / 60)
            if minutes < 60 { return "\(minutes)m ago" }
            else if minutes < 1440 { return "\(minutes / 60)h ago" }
            else { return "\(minutes / 1440)d ago" }
        }
    }

    struct TaskItem: Identifiable {
        let id: UUID
        let title: String
        let dueDate: Date?
        let isOverdue: Bool
        let isDueToday: Bool
        let subtaskProgress: (done: Int, total: Int)?
        let subtasks: [SubtaskItem]
        let referenceAttachments: [AttachmentItem]
        let workAttachments: [AttachmentItem]
        let projectId: UUID
        let createdBy: User?
        let createdAt: Date
        let isNew: Bool // Unacknowledged task
        let createdByName: String? // For display in new tasks
    }

    var myTasksByProject: [ProjectTaskGroup] {
        var groups: [ProjectTaskGroup] = []

        for project in dataService.projects {
            // ALL pending tasks assigned to current user (both new and acknowledged)
            let myTasks = project.tasks.filter { task in
                task.status == .pending &&
                task.assignees.contains(where: { $0.id == currentUser.id })
            }

            if !myTasks.isEmpty {
                let taskItems = myTasks.map { task -> TaskItem in
                    let doneSubtasks = task.subtasks.filter { $0.isDone }.count
                    let totalSubtasks = task.subtasks.count
                    let isNew = !task.isAcknowledged(by: currentUser.id)
                    let subtaskItems = task.subtasks.map { SubtaskItem(id: $0.id, title: $0.title, isDone: $0.isDone, description: $0.description, dueDate: $0.dueDate, createdBy: $0.createdBy, createdAt: $0.createdAt) }
                    let refAttachments = task.attachments.filter { $0.category == .reference }.map {
                        AttachmentItem(id: $0.id, type: $0.type, category: $0.category, fileName: $0.fileName, fileSize: $0.fileSize, uploadedByName: $0.uploadedBy.name, uploadedAt: $0.uploadedAt, caption: $0.caption)
                    }
                    let workAttachments = task.attachments.filter { $0.category == .work }.map {
                        AttachmentItem(id: $0.id, type: $0.type, category: $0.category, fileName: $0.fileName, fileSize: $0.fileSize, uploadedByName: $0.uploadedBy.name, uploadedAt: $0.uploadedAt, caption: $0.caption)
                    }
                    return TaskItem(
                        id: task.id,
                        title: task.title,
                        dueDate: task.dueDate,
                        isOverdue: task.isOverdue,
                        isDueToday: task.isDueToday,
                        subtaskProgress: totalSubtasks > 0 ? (doneSubtasks, totalSubtasks) : nil,
                        subtasks: subtaskItems,
                        referenceAttachments: refAttachments,
                        workAttachments: workAttachments,
                        projectId: project.id,
                        createdBy: task.createdBy,
                        createdAt: task.createdAt,
                        isNew: isNew,
                        createdByName: task.createdBy?.displayFirstName
                    )
                }
                // Sort: new tasks first, then by due date
                let sortedTasks = taskItems.sorted { t1, t2 in
                    if t1.isNew != t2.isNew { return t1.isNew }
                    if let d1 = t1.dueDate, let d2 = t2.dueDate { return d1 < d2 }
                    if t1.dueDate != nil { return true }
                    return false
                }

                groups.append(ProjectTaskGroup(
                    id: project.id,
                    projectName: project.name,
                    projectId: project.id,
                    tasks: sortedTasks
                ))
            }
        }

        return groups
    }

    var totalNewTasksCount: Int {
        myTasksByProject.reduce(0) { $0 + $1.newTasksCount }
    }

    // MARK: - Active Tasks (acknowledged only, grouped by project)

    var activeTasksByProject: [ProjectTaskGroup] {
        var groups: [ProjectTaskGroup] = []

        for project in dataService.projects {
            // Only pending tasks assigned to current user that are acknowledged
            let activeTasks = project.tasks.filter { task in
                task.status == .pending &&
                task.assignees.contains(where: { $0.id == currentUser.id }) &&
                task.isAcknowledged(by: currentUser.id) // Only acknowledged tasks
            }

            if !activeTasks.isEmpty {
                let taskItems = activeTasks.map { task -> TaskItem in
                    let doneSubtasks = task.subtasks.filter { $0.isDone }.count
                    let totalSubtasks = task.subtasks.count
                    let subtaskItems = task.subtasks.map { SubtaskItem(id: $0.id, title: $0.title, isDone: $0.isDone, description: $0.description, dueDate: $0.dueDate, createdBy: $0.createdBy, createdAt: $0.createdAt) }
                    let refAttachments = task.attachments.filter { $0.category == .reference }.map {
                        AttachmentItem(id: $0.id, type: $0.type, category: $0.category, fileName: $0.fileName, fileSize: $0.fileSize, uploadedByName: $0.uploadedBy.name, uploadedAt: $0.uploadedAt, caption: $0.caption)
                    }
                    let workAttachments = task.attachments.filter { $0.category == .work }.map {
                        AttachmentItem(id: $0.id, type: $0.type, category: $0.category, fileName: $0.fileName, fileSize: $0.fileSize, uploadedByName: $0.uploadedBy.name, uploadedAt: $0.uploadedAt, caption: $0.caption)
                    }
                    return TaskItem(
                        id: task.id,
                        title: task.title,
                        dueDate: task.dueDate,
                        isOverdue: task.isOverdue,
                        isDueToday: task.isDueToday,
                        subtaskProgress: totalSubtasks > 0 ? (doneSubtasks, totalSubtasks) : nil,
                        subtasks: subtaskItems,
                        referenceAttachments: refAttachments,
                        workAttachments: workAttachments,
                        projectId: project.id,
                        createdBy: task.createdBy,
                        createdAt: task.createdAt,
                        isNew: false, // All are acknowledged
                        createdByName: task.createdBy?.displayFirstName
                    )
                }
                // Sort by due date
                let sortedTasks = taskItems.sorted { t1, t2 in
                    if let d1 = t1.dueDate, let d2 = t2.dueDate { return d1 < d2 }
                    if t1.dueDate != nil { return true }
                    return false
                }

                groups.append(ProjectTaskGroup(
                    id: project.id,
                    projectName: project.name,
                    projectId: project.id,
                    tasks: sortedTasks
                ))
            }
        }

        return groups
    }

    // MARK: - Done Tasks (grouped by project)

    var doneTasksByProject: [ProjectTaskGroup] {
        var groups: [ProjectTaskGroup] = []

        for project in dataService.projects {
            // Tasks assigned to current user that are done
            let doneTasks = project.tasks.filter { task in
                task.status == .done &&
                task.assignees.contains(where: { $0.id == currentUser.id })
            }

            if !doneTasks.isEmpty {
                let taskItems = doneTasks.map { task -> TaskItem in
                    let doneSubtasks = task.subtasks.filter { $0.isDone }.count
                    let totalSubtasks = task.subtasks.count
                    let subtaskItems = task.subtasks.map { SubtaskItem(id: $0.id, title: $0.title, isDone: $0.isDone, description: $0.description, dueDate: $0.dueDate, createdBy: $0.createdBy, createdAt: $0.createdAt) }
                    let refAttachments = task.attachments.filter { $0.category == .reference }.map {
                        AttachmentItem(id: $0.id, type: $0.type, category: $0.category, fileName: $0.fileName, fileSize: $0.fileSize, uploadedByName: $0.uploadedBy.name, uploadedAt: $0.uploadedAt, caption: $0.caption)
                    }
                    let workAttachments = task.attachments.filter { $0.category == .work }.map {
                        AttachmentItem(id: $0.id, type: $0.type, category: $0.category, fileName: $0.fileName, fileSize: $0.fileSize, uploadedByName: $0.uploadedBy.name, uploadedAt: $0.uploadedAt, caption: $0.caption)
                    }
                    return TaskItem(
                        id: task.id,
                        title: task.title,
                        dueDate: task.dueDate,
                        isOverdue: false,
                        isDueToday: false,
                        subtaskProgress: totalSubtasks > 0 ? (doneSubtasks, totalSubtasks) : nil,
                        subtasks: subtaskItems,
                        referenceAttachments: refAttachments,
                        workAttachments: workAttachments,
                        projectId: project.id,
                        createdBy: task.createdBy,
                        createdAt: task.createdAt,
                        isNew: false,
                        createdByName: task.createdBy?.displayFirstName
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

    func toggleSubtask(projectId: UUID, taskId: UUID, subtaskId: UUID) {
        guard let projectIndex = dataService.projects.firstIndex(where: { $0.id == projectId }),
              let taskIndex = dataService.projects[projectIndex].tasks.firstIndex(where: { $0.id == taskId }),
              let subtaskIndex = dataService.projects[projectIndex].tasks[taskIndex].subtasks.firstIndex(where: { $0.id == subtaskId }) else {
            return
        }
        dataService.projects[projectIndex].tasks[taskIndex].subtasks[subtaskIndex].isDone.toggle()
    }

    func sendSubtaskMessage(projectId: UUID, taskId: UUID, subtaskId: UUID, message: String) {
        guard let projectIndex = dataService.projects.firstIndex(where: { $0.id == projectId }),
              let taskIndex = dataService.projects[projectIndex].tasks.firstIndex(where: { $0.id == taskId }),
              let subtask = dataService.projects[projectIndex].tasks[taskIndex].subtasks.first(where: { $0.id == subtaskId }) else {
            return
        }

        let task = dataService.projects[projectIndex].tasks[taskIndex]
        // Create message with reference to both task and subtask
        let chatMessage = Message(
            content: message,
            sender: currentUser,
            referencedTask: TaskReference(taskId: task.id, taskTitle: "\(task.title) → \(subtask.title)")
        )
        dataService.projects[projectIndex].messages.append(chatMessage)
    }

    func addWorkAttachment(projectId: UUID, taskId: UUID, type: AttachmentType, fileName: String, caption: String?) {
        guard let projectIndex = dataService.projects.firstIndex(where: { $0.id == projectId }),
              let taskIndex = dataService.projects[projectIndex].tasks.firstIndex(where: { $0.id == taskId }) else {
            return
        }

        let attachment = Attachment(
            type: type,
            category: .work,
            fileName: fileName,
            fileSize: Int64.random(in: 100_000...5_000_000), // Mock file size
            uploadedBy: currentUser,
            caption: caption
        )
        dataService.projects[projectIndex].tasks[taskIndex].attachments.append(attachment)
    }

    func getProject(id: UUID) -> Project? {
        dataService.projects.first { $0.id == id }
    }
}

// MARK: - Activity Tab

enum ActivityTab: String, CaseIterable {
    case new = "New"
    case active = "Active"
    case done = "Done"
}

// MARK: - Activity View

struct ActivityView: View {
    @State private var viewModel = ActivityViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var selectedTab: ActivityTab = .new
    @State private var selectedNewTask: ActivityViewModel.NewTaskItem?
    @State private var showTaskDetailSheet = false
    @State private var selectedMyTask: (task: ActivityViewModel.TaskItem, group: ActivityViewModel.ProjectTaskGroup)?
    @State private var showMyTaskDetailSheet = false
    @State private var selectedSubtask: (subtask: ActivityViewModel.SubtaskItem, taskTitle: String, projectName: String, projectId: UUID, taskId: UUID)?
    @State private var showSubtaskDetailSheet = false
    @State private var highlightedTaskId: UUID? // For highlighting newly accepted task

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Tab picker
                tabPicker
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                // Tab content
                TabView(selection: $selectedTab) {
                    newTasksTab
                        .tag(ActivityTab.new)

                    activeTasksTab
                        .tag(ActivityTab.active)

                    doneTasksTab
                        .tag(ActivityTab.done)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
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
                                // Switch to Active tab and highlight the task
                                showTaskDetailSheet = false
                                selectedNewTask = nil
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        selectedTab = .active
                                        highlightedTaskId = task.taskId
                                    }
                                    // Remove highlight after 2 seconds
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                        withAnimation(.easeOut(duration: 0.5)) {
                                            highlightedTaskId = nil
                                        }
                                    }
                                }
                                return
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
                        viewModel: viewModel,
                        onAction: { action, message in
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
                        },
                        onAddPhoto: {
                            // In production, this would open camera/photo picker
                            viewModel.addWorkAttachment(
                                projectId: selected.group.projectId,
                                taskId: selected.task.id,
                                type: .image,
                                fileName: "Photo_\(Date().formatted(.dateTime.month().day().hour().minute())).jpg",
                                caption: nil
                            )
                        },
                        onAddFile: {
                            // In production, this would open document picker
                            viewModel.addWorkAttachment(
                                projectId: selected.group.projectId,
                                taskId: selected.task.id,
                                type: .document,
                                fileName: "Document_\(Date().formatted(.dateTime.month().day())).pdf",
                                caption: nil
                            )
                        },
                        onCancel: {
                            showMyTaskDetailSheet = false
                            selectedMyTask = nil
                        }
                    )
                }
            }
            .sheet(isPresented: $showSubtaskDetailSheet) {
                if let selected = selectedSubtask {
                    ActivitySubtaskDetailSheet(
                        subtask: selected.subtask,
                        taskTitle: selected.taskTitle,
                        projectName: selected.projectName,
                        onToggle: {
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.toggleSubtask(projectId: selected.projectId, taskId: selected.taskId, subtaskId: selected.subtask.id)
                            }
                            showSubtaskDetailSheet = false
                            selectedSubtask = nil
                        },
                        onSendMessage: { message in
                            viewModel.sendSubtaskMessage(projectId: selected.projectId, taskId: selected.taskId, subtaskId: selected.subtask.id, message: message)
                        },
                        onCancel: {
                            showSubtaskDetailSheet = false
                            selectedSubtask = nil
                        }
                    )
                }
            }
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(ActivityTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Text(tab.rawValue)
                                .font(.system(size: 15, weight: selectedTab == tab ? .semibold : .medium))

                            // Badge count
                            let count = countForTab(tab)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(selectedTab == tab ? .white : .secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(selectedTab == tab ? colorForTab(tab) : Color(uiColor: .tertiarySystemFill))
                                    .clipShape(Capsule())
                            }
                        }
                        .foregroundStyle(selectedTab == tab ? colorForTab(tab) : .secondary)

                        // Indicator line
                        Rectangle()
                            .fill(selectedTab == tab ? colorForTab(tab) : .clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func countForTab(_ tab: ActivityTab) -> Int {
        switch tab {
        case .new: return viewModel.newTasksCount
        case .active: return viewModel.activeTasksByProject.flatMap { $0.tasks }.count
        case .done: return viewModel.doneTasksByProject.flatMap { $0.tasks }.count
        }
    }

    private func colorForTab(_ tab: ActivityTab) -> Color {
        switch tab {
        case .new: return Theme.primary
        case .active: return .orange
        case .done: return .green
        }
    }

    // MARK: - New Tasks Tab

    private var newTasksTab: some View {
        ScrollView {
            if viewModel.newTasksByProject.isEmpty {
                emptyStateView(
                    icon: "bell.slash",
                    title: "No new tasks",
                    subtitle: "New task assignments will appear here"
                )
            } else {
                VStack(spacing: 16) {
                    ForEach(viewModel.newTasksByProject) { group in
                        NewTaskGroupView(
                            group: group,
                            onTap: { task in
                                selectedNewTask = task
                                showTaskDetailSheet = true
                            },
                            onProjectTap: {
                                navigationPath.append(group.projectId)
                            }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Active Tasks Tab

    private var activeTasksTab: some View {
        ScrollView {
            if viewModel.activeTasksByProject.isEmpty {
                emptyStateView(
                    icon: "checkmark.circle",
                    title: "All caught up!",
                    subtitle: "No active tasks assigned to you"
                )
            } else {
                VStack(spacing: 16) {
                    ForEach(viewModel.activeTasksByProject) { group in
                        ProjectTaskGroupView(
                            group: group,
                            showCheckbox: true,
                            isDoneStyle: false,
                            highlightedTaskId: highlightedTaskId,
                            onToggle: { taskId in
                                withAnimation(.spring(response: 0.3)) {
                                    viewModel.toggleTask(projectId: group.projectId, taskId: taskId)
                                }
                            },
                            onTap: { taskId in
                                if let task = group.tasks.first(where: { $0.id == taskId }) {
                                    selectedMyTask = (task: task, group: group)
                                    showMyTaskDetailSheet = true
                                }
                            },
                            onProjectTap: {
                                navigationPath.append(group.projectId)
                            },
                            onSubtaskToggle: { taskId, subtaskId in
                                withAnimation(.spring(response: 0.3)) {
                                    viewModel.toggleSubtask(projectId: group.projectId, taskId: taskId, subtaskId: subtaskId)
                                }
                            },
                            onSubtaskTap: { taskId, subtaskId in
                                if let task = group.tasks.first(where: { $0.id == taskId }),
                                   let subtask = task.subtasks.first(where: { $0.id == subtaskId }) {
                                    selectedSubtask = (subtask: subtask, taskTitle: task.title, projectName: group.projectName, projectId: group.projectId, taskId: taskId)
                                    showSubtaskDetailSheet = true
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Done Tasks Tab

    private var doneTasksTab: some View {
        ScrollView {
            if viewModel.doneTasksByProject.isEmpty {
                emptyStateView(
                    icon: "tray",
                    title: "No completed tasks",
                    subtitle: "Completed tasks will appear here"
                )
            } else {
                VStack(spacing: 16) {
                    ForEach(viewModel.doneTasksByProject) { group in
                        ProjectTaskGroupView(
                            group: group,
                            showCheckbox: true,
                            isDoneStyle: true,
                            onToggle: { taskId in
                                withAnimation(.spring(response: 0.3)) {
                                    viewModel.toggleTask(projectId: group.projectId, taskId: taskId)
                                }
                            },
                            onTap: { taskId in
                                if let task = group.tasks.first(where: { $0.id == taskId }) {
                                    selectedMyTask = (task: task, group: group)
                                    showMyTaskDetailSheet = true
                                }
                            },
                            onProjectTap: {
                                navigationPath.append(group.projectId)
                            },
                            onSubtaskToggle: { taskId, subtaskId in
                                withAnimation(.spring(response: 0.3)) {
                                    viewModel.toggleSubtask(projectId: group.projectId, taskId: taskId, subtaskId: subtaskId)
                                }
                            },
                            onSubtaskTap: { taskId, subtaskId in
                                if let task = group.tasks.first(where: { $0.id == taskId }),
                                   let subtask = task.subtasks.first(where: { $0.id == subtaskId }) {
                                    selectedSubtask = (subtask: subtask, taskTitle: task.title, projectName: group.projectName, projectId: group.projectId, taskId: taskId)
                                    showSubtaskDetailSheet = true
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Empty State View

    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - New Task Group View (for New tab)

struct NewTaskGroupView: View {
    let group: ActivityViewModel.NewTaskGroup
    let onTap: (ActivityViewModel.NewTaskItem) -> Void
    let onProjectTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Project header
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
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.primary)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
            }
            .buttonStyle(.plain)

            // Tasks
            ForEach(group.tasks) { task in
                Button {
                    onTap(task)
                } label: {
                    NewTaskRow(task: task)
                }
                .buttonStyle(.plain)

                if task.id != group.tasks.last?.id {
                    Divider()
                        .padding(.leading, 32)
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - New Task Row

struct NewTaskRow: View {
    let task: ActivityViewModel.NewTaskItem

    var body: some View {
        HStack(spacing: 12) {
            // Blue indicator dot for new
            Circle()
                .fill(Theme.primary)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(task.title)
                        .font(.system(size: 15))
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
                    if let assignedBy = task.assignedBy {
                        Text("from \(assignedBy.components(separatedBy: " ").first ?? assignedBy)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    if let dueDate = task.dueDate, !task.isOverdue && !task.isDueToday {
                        if task.assignedBy != nil {
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

// MARK: - Project Task Group View

struct ProjectTaskGroupView: View {
    let group: ActivityViewModel.ProjectTaskGroup
    var showCheckbox: Bool = true
    var isDoneStyle: Bool = false
    var highlightedTaskId: UUID? = nil
    let onToggle: (UUID) -> Void
    let onTap: (UUID) -> Void
    let onProjectTap: () -> Void
    let onSubtaskToggle: ((UUID, UUID) -> Void)?
    let onSubtaskTap: ((UUID, UUID) -> Void)?

    @State private var expandedTaskIds: Set<UUID> = []

    init(group: ActivityViewModel.ProjectTaskGroup,
         showCheckbox: Bool = true,
         isDoneStyle: Bool = false,
         highlightedTaskId: UUID? = nil,
         onToggle: @escaping (UUID) -> Void,
         onTap: @escaping (UUID) -> Void,
         onProjectTap: @escaping () -> Void,
         onSubtaskToggle: ((UUID, UUID) -> Void)? = nil,
         onSubtaskTap: ((UUID, UUID) -> Void)? = nil) {
        self.group = group
        self.showCheckbox = showCheckbox
        self.isDoneStyle = isDoneStyle
        self.highlightedTaskId = highlightedTaskId
        self.onToggle = onToggle
        self.onTap = onTap
        self.onProjectTap = onProjectTap
        self.onSubtaskToggle = onSubtaskToggle
        self.onSubtaskTap = onSubtaskTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Project header - tappable to go to project
            Button {
                onProjectTap()
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(isDoneStyle ? Color.green.opacity(0.2) : Theme.primaryLight)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Text(String(group.projectName.prefix(1)).uppercased())
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(isDoneStyle ? .green : Theme.primary)
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
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
            }
            .buttonStyle(.plain)

            // Tasks
            ForEach(group.tasks) { task in
                VStack(spacing: 0) {
                    ProjectTaskRow(
                        task: task,
                        isDoneStyle: isDoneStyle,
                        isExpanded: expandedTaskIds.contains(task.id),
                        isHighlighted: highlightedTaskId == task.id,
                        onToggle: { onToggle(task.id) },
                        onTap: { onTap(task.id) },
                        onExpand: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if expandedTaskIds.contains(task.id) {
                                    expandedTaskIds.remove(task.id)
                                } else {
                                    expandedTaskIds.insert(task.id)
                                }
                            }
                        }
                    )

                    // Subtasks (when expanded)
                    if expandedTaskIds.contains(task.id) && !task.subtasks.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(task.subtasks) { subtask in
                                ActivitySubtaskRow(
                                    subtask: subtask,
                                    isDoneStyle: isDoneStyle,
                                    onToggle: { onSubtaskToggle?(task.id, subtask.id) },
                                    onTap: { onSubtaskTap?(task.id, subtask.id) }
                                )

                                if subtask.id != task.subtasks.last?.id {
                                    Divider()
                                        .padding(.leading, 56)
                                }
                            }
                        }
                        .padding(.leading, 34)
                        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.5))
                    }
                }

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
    var isDoneStyle: Bool = false
    var isExpanded: Bool = false
    var isHighlighted: Bool = false
    let onToggle: () -> Void
    let onTap: () -> Void
    let onExpand: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                onToggle()
            } label: {
                Image(systemName: isDoneStyle ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isDoneStyle ? .green : (isHighlighted ? Theme.primary : .secondary))
            }
            .buttonStyle(.plain)

            // Main content - tappable for details
            Button {
                onTap()
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.system(size: 15))
                        .foregroundStyle(isDoneStyle ? .secondary : .primary)
                        .strikethrough(isDoneStyle)
                        .lineLimit(1)

                    if !isDoneStyle {
                        HStack(spacing: 6) {
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
                                Text(formatDueDate(dueDate))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            // Expand button (only if has subtasks)
            if !task.subtasks.isEmpty {
                Button {
                    onExpand()
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isHighlighted ? Theme.primaryLight : Color.clear)
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

// MARK: - My Tasks Group View (combined new + active)

struct MyTasksGroupView: View {
    let group: ActivityViewModel.ProjectTaskGroup
    let onToggle: (UUID) -> Void
    let onTap: (ActivityViewModel.TaskItem) -> Void
    let onProjectTap: () -> Void
    let onSubtaskToggle: ((UUID, UUID) -> Void)?
    let onSubtaskTap: ((UUID, UUID) -> Void)?

    @State private var expandedTaskIds: Set<UUID> = []

    init(group: ActivityViewModel.ProjectTaskGroup,
         onToggle: @escaping (UUID) -> Void,
         onTap: @escaping (ActivityViewModel.TaskItem) -> Void,
         onProjectTap: @escaping () -> Void,
         onSubtaskToggle: ((UUID, UUID) -> Void)? = nil,
         onSubtaskTap: ((UUID, UUID) -> Void)? = nil) {
        self.group = group
        self.onToggle = onToggle
        self.onTap = onTap
        self.onProjectTap = onProjectTap
        self.onSubtaskToggle = onSubtaskToggle
        self.onSubtaskTap = onSubtaskTap
    }

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

                    // Show new tasks badge if any
                    if group.newTasksCount > 0 {
                        Text("\(group.newTasksCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.primary)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
            }
            .buttonStyle(.plain)

            // Tasks
            ForEach(group.tasks) { task in
                VStack(spacing: 0) {
                    MyTaskRow(
                        task: task,
                        isExpanded: expandedTaskIds.contains(task.id),
                        onToggle: { onToggle(task.id) },
                        onTap: { onTap(task) },
                        onExpand: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if expandedTaskIds.contains(task.id) {
                                    expandedTaskIds.remove(task.id)
                                } else {
                                    expandedTaskIds.insert(task.id)
                                }
                            }
                        }
                    )

                    // Subtasks (when expanded) - only for active tasks
                    if !task.isNew && expandedTaskIds.contains(task.id) && !task.subtasks.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(task.subtasks) { subtask in
                                ActivitySubtaskRow(
                                    subtask: subtask,
                                    isDoneStyle: false,
                                    onToggle: { onSubtaskToggle?(task.id, subtask.id) },
                                    onTap: { onSubtaskTap?(task.id, subtask.id) }
                                )

                                if subtask.id != task.subtasks.last?.id {
                                    Divider()
                                        .padding(.leading, 56)
                                }
                            }
                        }
                        .padding(.leading, 34)
                        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.5))
                    }
                }

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

// MARK: - My Task Row

struct MyTaskRow: View {
    let task: ActivityViewModel.TaskItem
    var isExpanded: Bool = false
    let onToggle: () -> Void
    let onTap: () -> Void
    let onExpand: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox or NEW indicator
            if task.isNew {
                // Red dot for new tasks
                Circle()
                    .fill(Theme.primary)
                    .frame(width: 8, height: 8)
                    .padding(.horizontal, 7)
            } else {
                // Checkbox for active tasks
                Button {
                    onToggle()
                } label: {
                    Image(systemName: "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Main content - tappable for details
            Button {
                onTap()
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(task.title)
                            .font(.system(size: 15))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        // NEW badge for unacknowledged tasks
                        if task.isNew {
                            Text("NEW")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Theme.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }

                    HStack(spacing: 6) {
                        // Show "from [Creator]" for new tasks
                        if task.isNew, let creatorName = task.createdByName {
                            Text("from \(creatorName)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

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

                        if let progress = task.subtaskProgress {
                            HStack(spacing: 3) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 10))
                                Text("\(progress.done)/\(progress.total)")
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(.secondary)
                        }

                        // Attachments indicator
                        let attachmentCount = task.referenceAttachments.count + task.workAttachments.count
                        if attachmentCount > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "paperclip")
                                    .font(.system(size: 10))
                                Text("\(attachmentCount)")
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(.secondary)
                        }

                        if let dueDate = task.dueDate, !task.isOverdue && !task.isDueToday {
                            Text(formatDueDate(dueDate))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            // Expand/chevron button
            if task.isNew {
                // Chevron for new tasks (to view details)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 24, height: 24)
            } else if !task.subtasks.isEmpty {
                // Expand button for active tasks with subtasks
                Button {
                    onExpand()
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
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

// MARK: - Activity Subtask Row

struct ActivitySubtaskRow: View {
    let subtask: ActivityViewModel.SubtaskItem
    var isDoneStyle: Bool = false
    let onToggle: () -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Checkbox
            Button {
                onToggle()
            } label: {
                Image(systemName: subtask.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(subtask.isDone ? Color.green : Color(uiColor: .tertiaryLabel))
            }
            .buttonStyle(.plain)

            // Subtask title - tappable for details
            Button {
                onTap()
            } label: {
                Text(subtask.title)
                    .font(.system(size: 14))
                    .foregroundStyle(subtask.isDone ? Color.secondary : Color.primary)
                    .strikethrough(subtask.isDone)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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

// MARK: - My Task Detail Sheet (matches TaskDrawerDetailView design)

struct MyTaskDetailSheet: View {
    let task: ActivityViewModel.TaskItem
    let projectName: String
    let viewModel: ActivityViewModel
    let onAction: (MyTaskAction, String?) -> Void
    let onAddPhoto: () -> Void
    let onAddFile: () -> Void
    let onCancel: () -> Void

    @State private var showingTaskInfo = false
    @State private var selectedSubtask: ActivityViewModel.SubtaskItem?
    @State private var showSubtaskDetail = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Task header (tappable to see full details)
                taskHeader

                // Subtasks list
                if task.subtasks.isEmpty {
                    emptySubtasksView
                } else {
                    subtasksList
                }

                // Bottom bar with actions
                bottomBar
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        onCancel()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingTaskInfo) {
                MyTaskInfoSheet(
                    task: task,
                    projectName: projectName,
                    viewModel: viewModel,
                    onAddPhoto: onAddPhoto,
                    onAddFile: onAddFile
                )
            }
            .sheet(isPresented: $showSubtaskDetail) {
                if let subtask = selectedSubtask {
                    ActivitySubtaskDetailSheet(
                        subtask: subtask,
                        taskTitle: task.title,
                        projectName: projectName,
                        onToggle: {
                            viewModel.toggleSubtask(projectId: task.projectId, taskId: task.id, subtaskId: subtask.id)
                            showSubtaskDetail = false
                            selectedSubtask = nil
                        },
                        onSendMessage: { message in
                            viewModel.sendSubtaskMessage(projectId: task.projectId, taskId: task.id, subtaskId: subtask.id, message: message)
                        },
                        onCancel: {
                            showSubtaskDetail = false
                            selectedSubtask = nil
                        }
                    )
                }
            }
        }
    }

    // MARK: - Task Header

    private var taskHeader: some View {
        Button {
            showingTaskInfo = true
        } label: {
            HStack(spacing: 12) {
                // Task info
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    // Info row
                    HStack(spacing: 12) {
                        // Subtask progress
                        if let progress = task.subtaskProgress {
                            HStack(spacing: 4) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 11))
                                Text("\(progress.done)/\(progress.total)")
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(progress.done == progress.total ? .green : .secondary)
                        }

                        // Due date
                        if let dueDate = task.dueDate {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 11))
                                Text(formatShortDueDate(dueDate))
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(task.isOverdue ? .red : .secondary)
                        }

                        // Has notes indicator
                        if viewModel.getTaskNotes(projectId: task.projectId, taskId: task.id) != nil {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 11))
                                Text("Notes")
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(.secondary)
                        }

                        // Attachments indicator
                        let attachmentCount = task.referenceAttachments.count + task.workAttachments.count
                        if attachmentCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "paperclip")
                                    .font(.system(size: 11))
                                Text("\(attachmentCount)")
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(.secondary)
                        }
                    }

                    // Assignees
                    let assignees = viewModel.getTaskAssignees(projectId: task.projectId, taskId: task.id)
                    if !assignees.isEmpty {
                        HStack(spacing: 4) {
                            HStack(spacing: -4) {
                                ForEach(assignees.prefix(3)) { assignee in
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
                            let names = assignees.prefix(2).map { $0.displayFirstName }
                            let displayText = assignees.count > 2
                                ? "\(names.joined(separator: ", ")) +\(assignees.count - 2)"
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

            Text("This task has no subtasks")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Subtasks List

    private var subtasksList: some View {
        List {
            ForEach(task.subtasks) { subtask in
                MyTaskSubtaskRow(
                    subtask: subtask,
                    onToggle: {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.toggleSubtask(projectId: task.projectId, taskId: task.id, subtaskId: subtask.id)
                        }
                    },
                    onTap: {
                        selectedSubtask = subtask
                        showSubtaskDetail = true
                    }
                )
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                // Mark Done button
                Button {
                    onAction(.done, nil)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                        Text("Mark Done")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Open Project button
                Button {
                    onAction(.goToProject, nil)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 20))
                        Text("Project")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(Theme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.primaryLight)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding()
            .background(Color(uiColor: .systemBackground))
        }
    }

    private func formatShortDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

// MARK: - My Task Subtask Row

struct MyTaskSubtaskRow: View {
    let subtask: ActivityViewModel.SubtaskItem
    let onToggle: () -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                onToggle()
            } label: {
                Image(systemName: subtask.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(subtask.isDone ? .green : .secondary)
            }
            .buttonStyle(.plain)

            // Subtask info
            Button {
                onTap()
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
    }
}

// MARK: - My Task Info Sheet (Notes, Attachments, etc.)

struct MyTaskInfoSheet: View {
    let task: ActivityViewModel.TaskItem
    let projectName: String
    let viewModel: ActivityViewModel
    let onAddPhoto: () -> Void
    let onAddFile: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Task title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Task")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text(task.title)
                            .font(.system(size: 17))
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Assignees
                    let assignees = viewModel.getTaskAssignees(projectId: task.projectId, taskId: task.id)
                    if !assignees.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Assigned to")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            VStack(spacing: 8) {
                                ForEach(assignees) { assignee in
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

                    // Due date
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Due date")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        if let dueDate = task.dueDate {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 16))
                                    .foregroundStyle(task.isOverdue ? .red : Theme.primary)
                                Text(formatDueDate(dueDate))
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

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes & Instructions")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        if let notes = viewModel.getTaskNotes(projectId: task.projectId, taskId: task.id), !notes.isEmpty {
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

                    // Reference Files
                    if !task.referenceAttachments.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Reference Files")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(task.referenceAttachments.count)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }

                            VStack(spacing: 8) {
                                ForEach(task.referenceAttachments) { attachment in
                                    ReferenceAttachmentRow(attachment: attachment)
                                }
                            }
                        }
                    }

                    // Work Uploads
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Work Uploads")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            if !task.workAttachments.isEmpty {
                                Text("\(task.workAttachments.count)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if task.workAttachments.isEmpty {
                            Text("No uploads yet")
                                .font(.system(size: 14))
                                .foregroundStyle(.tertiary)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            VStack(spacing: 8) {
                                ForEach(task.workAttachments) { attachment in
                                    WorkAttachmentRow(attachment: attachment)
                                }
                            }
                        }

                        // Upload buttons
                        HStack(spacing: 12) {
                            Button {
                                onAddPhoto()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "camera.fill")
                                    Text("Add Photo")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Theme.primaryLight)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }

                            Button {
                                onAddFile()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.fill")
                                    Text("Add File")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Theme.primaryLight)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }

                    // Created by
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
            .navigationTitle("Task Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

// MARK: - Activity Subtask Detail Sheet

struct ActivitySubtaskDetailSheet: View {
    let subtask: ActivityViewModel.SubtaskItem
    let taskTitle: String
    let projectName: String
    let onToggle: () -> Void
    let onSendMessage: (String) -> Void
    let onCancel: () -> Void

    @State private var message = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Subtask")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            Image(systemName: subtask.isDone ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(subtask.isDone ? .green : .secondary)

                            Text(subtask.title)
                                .font(.system(size: 17))
                                .strikethrough(subtask.isDone)
                                .foregroundStyle(subtask.isDone ? .secondary : .primary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Parent task
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Parent Task")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                            Text(taskTitle)
                                .font(.system(size: 15))
                            Spacer()
                        }
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Instructions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Instructions")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        if let description = subtask.description, !description.isEmpty {
                            Text(description)
                                .font(.system(size: 15))
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Text("No instructions")
                                .font(.system(size: 14))
                                .foregroundStyle(.tertiary)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // Due date
                    if let dueDate = subtask.dueDate {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Due date")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Theme.primary)
                                Text(formatDueDate(dueDate))
                                    .font(.system(size: 14))
                                Spacer()
                            }
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // Message to group
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Send message to group")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            TextField("Type a message...", text: $message)
                                .font(.system(size: 15))
                                .padding(14)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            if !message.isEmpty {
                                Button {
                                    onSendMessage(message)
                                    message = ""
                                } label: {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(Theme.primary)
                                }
                            }
                        }
                    }

                    // Created by
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
            .navigationTitle("Subtask Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onToggle()
                    } label: {
                        Text(subtask.isDone ? "Undo" : "Done")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

// MARK: - Reference Attachment Row

struct ReferenceAttachmentRow: View {
    let attachment: ActivityViewModel.AttachmentItem

    var body: some View {
        HStack(spacing: 12) {
            // File icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(uiColor: .tertiarySystemFill))
                    .frame(width: 44, height: 44)

                Image(systemName: attachment.iconName)
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }

            // File info
            VStack(alignment: .leading, spacing: 3) {
                Text(attachment.fileName)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(attachment.fileSizeFormatted)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Text("•")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)

                    Text("by \(attachment.uploadedByName)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Download button
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 22))
                .foregroundStyle(Theme.primary)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Work Attachment Row

struct WorkAttachmentRow: View {
    let attachment: ActivityViewModel.AttachmentItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Thumbnail or icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(attachment.type == .image ? Color.green.opacity(0.15) : Color(uiColor: .tertiarySystemFill))
                        .frame(width: 44, height: 44)

                    Image(systemName: attachment.iconName)
                        .font(.system(size: 18))
                        .foregroundStyle(attachment.type == .image ? .green : .secondary)
                }

                // File info
                VStack(alignment: .leading, spacing: 3) {
                    Text(attachment.fileName)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(attachment.fileSizeFormatted)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        Text("•")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)

                        Text(attachment.timeAgo)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // View button
                Image(systemName: "eye.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(.green)
            }

            // Caption if present
            if let caption = attachment.caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 56)
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    ActivityView()
}
