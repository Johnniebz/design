import Foundation
import Observation

@Observable
final class ProjectChatViewModel {
    var project: Project
    var newMessageText: String = ""
    var referencedTask: TaskReference? = nil
    var referencedSubtask: SubtaskReference? = nil
    var quotedMessage: QuotedMessage? = nil
    var isMuted: Bool = false

    // Task drawer state
    var selectedTask: DONEOTask? = nil
    var newTaskTitle: String = ""
    var newSubtaskTitle: String = ""
    var selectedAssigneeIds: Set<UUID> = []

    init(project: Project) {
        self.project = project
    }

    // MARK: - Current User

    var currentUser: User {
        MockDataService.shared.currentUser
    }

    var isAdmin: Bool {
        // First member is considered admin for simplicity
        project.members.first?.id == currentUser.id
    }

    // MARK: - Messages

    var messages: [Message] {
        project.messages.sorted { $0.timestamp < $1.timestamp }
    }

    func sendMessage() {
        guard !newMessageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let message = Message(
            content: newMessageText,
            sender: currentUser,
            isFromCurrentUser: true,
            referencedTask: referencedTask,
            referencedSubtask: referencedSubtask,
            quotedMessage: quotedMessage
        )
        project.messages.append(message)

        // Update project's last activity
        project.lastActivity = Date()
        project.lastActivityPreview = "\(currentUser.displayFirstName): \(newMessageText)"

        // Update in MockDataService
        MockDataService.shared.updateProject(project)

        newMessageText = ""
        referencedTask = nil
        referencedSubtask = nil
        quotedMessage = nil
    }

    func sendMessage(content: String, referencedTask: TaskReference? = nil, referencedSubtask: SubtaskReference? = nil, quotedMessage: QuotedMessage? = nil) {
        let message = Message(
            content: content,
            sender: currentUser,
            isFromCurrentUser: true,
            referencedTask: referencedTask,
            referencedSubtask: referencedSubtask,
            quotedMessage: quotedMessage
        )
        project.messages.append(message)

        // Update project's last activity
        project.lastActivity = Date()
        project.lastActivityPreview = "\(currentUser.displayFirstName): \(content)"

        MockDataService.shared.updateProject(project)
    }

    // MARK: - Task Management

    var tasks: [DONEOTask] {
        project.tasks
    }

    var pendingTasks: [DONEOTask] {
        project.tasks.filter { $0.status == .pending }
    }

    var completedTasks: [DONEOTask] {
        project.tasks.filter { $0.status == .done }
    }

    // New tasks assigned to current user (not yet acknowledged)
    var newTasksForCurrentUser: [DONEOTask] {
        project.tasks.filter { task in
            task.isNew(for: currentUser.id)
        }
    }

    var newTasksCount: Int {
        newTasksForCurrentUser.count
    }

    // MARK: - Accept/Decline Tasks

    func acceptTask(_ task: DONEOTask, message: String?) {
        guard let taskIndex = project.tasks.firstIndex(where: { $0.id == task.id }) else { return }

        // Mark as acknowledged
        project.tasks[taskIndex].acknowledgedBy.insert(currentUser.id)

        // Send acceptance message
        let userMessage = message?.isEmpty == false ? ": \(message!)" : ""
        let content = "✓ Accepted\(userMessage)"
        let chatMessage = Message(
            content: content,
            sender: currentUser,
            isFromCurrentUser: true,
            referencedTask: TaskReference(task: task)
        )
        project.messages.append(chatMessage)

        // Update project
        project.lastActivity = Date()
        project.lastActivityPreview = "\(currentUser.displayFirstName) accepted \(task.title)"
        MockDataService.shared.updateProject(project)
    }

    func declineTask(_ task: DONEOTask, reason: String?) {
        guard let taskIndex = project.tasks.firstIndex(where: { $0.id == task.id }) else { return }

        // Send decline message
        let userMessage = reason?.isEmpty == false ? ": \(reason!)" : ""
        let content = "✗ Declined\(userMessage)"
        let chatMessage = Message(
            content: content,
            sender: currentUser,
            isFromCurrentUser: true,
            referencedTask: TaskReference(task: task)
        )
        project.messages.append(chatMessage)

        // Remove current user from assignees
        project.tasks[taskIndex].assignees.removeAll { $0.id == currentUser.id }

        // Update project
        project.lastActivity = Date()
        project.lastActivityPreview = "\(currentUser.displayFirstName) declined \(task.title)"
        MockDataService.shared.updateProject(project)
    }

    func sendTaskQuestion(_ task: DONEOTask, message: String) {
        let chatMessage = Message(
            content: message,
            sender: currentUser,
            isFromCurrentUser: true,
            referencedTask: TaskReference(task: task)
        )
        project.messages.append(chatMessage)

        // Update project
        project.lastActivity = Date()
        project.lastActivityPreview = "\(currentUser.displayFirstName): \(message)"
        MockDataService.shared.updateProject(project)
    }

    func addTask(title: String, assignees: [User] = [], subtasks: [Subtask] = [], dueDate: Date? = nil, notes: String? = nil) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let task = DONEOTask(
            title: title,
            assignees: assignees,
            status: .pending,
            dueDate: dueDate,
            subtasks: subtasks,
            notes: notes,
            createdBy: currentUser
        )
        project.tasks.append(task)

        // Add system message
        let systemContent = "created task \"\(title)\""
        let message = Message(
            content: systemContent,
            sender: currentUser,
            isFromCurrentUser: true,
            referencedTask: TaskReference(task: task)
        )
        project.messages.append(message)

        // Update project's last activity
        project.lastActivity = Date()
        project.lastActivityPreview = "New task: \(title)"

        MockDataService.shared.updateProject(project)

        newTaskTitle = ""
        selectedAssigneeIds = []
    }

    func addTaskWithAttachments(title: String, assignees: [User] = [], subtasks: [Subtask] = [], dueDate: Date? = nil, notes: String? = nil, attachments: [Attachment] = []) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let task = DONEOTask(
            title: title,
            assignees: assignees,
            status: .pending,
            dueDate: dueDate,
            subtasks: subtasks,
            attachments: attachments,
            notes: notes,
            createdBy: currentUser
        )
        project.tasks.append(task)

        // Add system message
        var systemContent = "created task \"\(title)\""
        if !attachments.isEmpty {
            systemContent += " with \(attachments.count) attachment\(attachments.count == 1 ? "" : "s")"
        }
        let message = Message(
            content: systemContent,
            sender: currentUser,
            isFromCurrentUser: true,
            referencedTask: TaskReference(task: task)
        )
        project.messages.append(message)

        // Update project's last activity
        project.lastActivity = Date()
        project.lastActivityPreview = "New task: \(title)"

        MockDataService.shared.updateProject(project)

        newTaskTitle = ""
        selectedAssigneeIds = []
    }

    func toggleTaskStatus(_ task: DONEOTask) {
        guard let index = project.tasks.firstIndex(where: { $0.id == task.id }) else { return }
        project.tasks[index].status = project.tasks[index].status == .pending ? .done : .pending

        let isNowDone = project.tasks[index].status == .done
        let statusText = isNowDone ? "completed" : "reopened"

        // Add system message
        let message = Message(
            content: "\(statusText) task \"\(task.title)\"",
            sender: currentUser,
            isFromCurrentUser: true,
            referencedTask: TaskReference(task: task)
        )
        project.messages.append(message)

        // Update project's last activity
        project.lastActivity = Date()
        project.lastActivityPreview = "\(isNowDone ? "Completed" : "Reopened"): \(task.title)"

        MockDataService.shared.updateProject(project)
    }

    func deleteTask(_ task: DONEOTask) {
        project.tasks.removeAll { $0.id == task.id }
        if selectedTask?.id == task.id {
            selectedTask = nil
        }
        MockDataService.shared.updateProject(project)
    }

    func updateTask(_ task: DONEOTask, title: String, assigneeIds: Set<UUID>, dueDate: Date?, notes: String?) {
        guard let taskIndex = project.tasks.firstIndex(where: { $0.id == task.id }) else { return }

        project.tasks[taskIndex].title = title
        project.tasks[taskIndex].assignees = project.members.filter { assigneeIds.contains($0.id) }
        project.tasks[taskIndex].dueDate = dueDate
        project.tasks[taskIndex].notes = notes

        // Update selectedTask if viewing this task
        if selectedTask?.id == task.id {
            selectedTask = project.tasks[taskIndex]
        }

        MockDataService.shared.updateProject(project)
    }

    // MARK: - Subtask Management

    func toggleSubtaskStatus(_ task: DONEOTask, _ subtask: Subtask) {
        guard let taskIndex = project.tasks.firstIndex(where: { $0.id == task.id }),
              let subtaskIndex = project.tasks[taskIndex].subtasks.firstIndex(where: { $0.id == subtask.id }) else {
            return
        }

        project.tasks[taskIndex].subtasks[subtaskIndex].isDone.toggle()
        let isNowDone = project.tasks[taskIndex].subtasks[subtaskIndex].isDone

        // Add system message
        let subtaskRef = SubtaskReference(subtask: subtask)
        let messageType: MessageType = isNowDone ? .subtaskCompleted(subtaskRef) : .subtaskReopened(subtaskRef)
        let content = isNowDone
            ? "completed \"\(subtask.title)\""
            : "reopened \"\(subtask.title)\""

        let message = Message(
            content: content,
            sender: currentUser,
            isFromCurrentUser: true,
            referencedTask: TaskReference(task: task),
            referencedSubtask: subtaskRef,
            messageType: messageType
        )
        project.messages.append(message)

        // Update project's last activity
        project.lastActivity = Date()
        project.lastActivityPreview = "\(isNowDone ? "Completed" : "Reopened"): \(subtask.title)"

        // Update selectedTask if viewing this task
        if selectedTask?.id == task.id {
            selectedTask = project.tasks[taskIndex]
        }

        MockDataService.shared.updateProject(project)
    }

    func addSubtask(to task: DONEOTask, title: String, description: String? = nil, assignees: [User] = [], dueDate: Date? = nil) {
        guard let taskIndex = project.tasks.firstIndex(where: { $0.id == task.id }),
              !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }

        let subtask = Subtask(
            title: title,
            description: description,
            assignees: assignees,
            dueDate: dueDate,
            createdBy: currentUser
        )
        project.tasks[taskIndex].subtasks.append(subtask)

        // Update selectedTask if viewing this task
        if selectedTask?.id == task.id {
            selectedTask = project.tasks[taskIndex]
        }

        MockDataService.shared.updateProject(project)
        newSubtaskTitle = ""
    }

    func deleteSubtask(from task: DONEOTask, subtask: Subtask) {
        guard let taskIndex = project.tasks.firstIndex(where: { $0.id == task.id }) else { return }
        project.tasks[taskIndex].subtasks.removeAll { $0.id == subtask.id }

        // Update selectedTask if viewing this task
        if selectedTask?.id == task.id {
            selectedTask = project.tasks[taskIndex]
        }

        MockDataService.shared.updateProject(project)
    }

    func updateSubtask(in task: DONEOTask, subtask: Subtask, newTitle: String) {
        guard let taskIndex = project.tasks.firstIndex(where: { $0.id == task.id }),
              let subtaskIndex = project.tasks[taskIndex].subtasks.firstIndex(where: { $0.id == subtask.id }) else {
            return
        }
        project.tasks[taskIndex].subtasks[subtaskIndex].title = newTitle

        if selectedTask?.id == task.id {
            selectedTask = project.tasks[taskIndex]
        }

        MockDataService.shared.updateProject(project)
    }

    func updateSubtaskDescription(in task: DONEOTask, subtask: Subtask, description: String?) {
        guard let taskIndex = project.tasks.firstIndex(where: { $0.id == task.id }),
              let subtaskIndex = project.tasks[taskIndex].subtasks.firstIndex(where: { $0.id == subtask.id }) else {
            return
        }
        project.tasks[taskIndex].subtasks[subtaskIndex].description = description

        if selectedTask?.id == task.id {
            selectedTask = project.tasks[taskIndex]
        }

        MockDataService.shared.updateProject(project)
    }

    func updateSubtaskDueDate(in task: DONEOTask, subtask: Subtask, dueDate: Date?) {
        guard let taskIndex = project.tasks.firstIndex(where: { $0.id == task.id }),
              let subtaskIndex = project.tasks[taskIndex].subtasks.firstIndex(where: { $0.id == subtask.id }) else {
            return
        }
        project.tasks[taskIndex].subtasks[subtaskIndex].dueDate = dueDate

        if selectedTask?.id == task.id {
            selectedTask = project.tasks[taskIndex]
        }

        MockDataService.shared.updateProject(project)
    }

    func toggleSubtaskAssignee(in task: DONEOTask, subtask: Subtask, member: User) {
        guard let taskIndex = project.tasks.firstIndex(where: { $0.id == task.id }),
              let subtaskIndex = project.tasks[taskIndex].subtasks.firstIndex(where: { $0.id == subtask.id }) else {
            return
        }

        if let memberIndex = project.tasks[taskIndex].subtasks[subtaskIndex].assignees.firstIndex(where: { $0.id == member.id }) {
            project.tasks[taskIndex].subtasks[subtaskIndex].assignees.remove(at: memberIndex)
        } else {
            project.tasks[taskIndex].subtasks[subtaskIndex].assignees.append(member)
        }

        if selectedTask?.id == task.id {
            selectedTask = project.tasks[taskIndex]
        }

        MockDataService.shared.updateProject(project)
    }

    // MARK: - Task References for Chat

    func quoteTask(_ task: DONEOTask) {
        referencedTask = TaskReference(task: task)
        referencedSubtask = nil
    }

    func quoteSubtask(_ task: DONEOTask, subtask: Subtask) {
        referencedTask = TaskReference(task: task)
        referencedSubtask = SubtaskReference(subtask: subtask)
    }

    func clearReferences() {
        referencedTask = nil
        referencedSubtask = nil
    }

    // MARK: - Message Quoting

    func quoteMessage(_ message: Message) {
        quotedMessage = QuotedMessage(message: message)
    }

    func clearQuote() {
        quotedMessage = nil
    }

    func clearAllReferences() {
        referencedTask = nil
        referencedSubtask = nil
        quotedMessage = nil
    }

    // MARK: - Permissions

    func canEditTask(_ task: DONEOTask) -> Bool {
        if let creator = task.createdBy {
            return creator.id == currentUser.id || isAdmin
        }
        return true
    }

    func canEditSubtask(_ subtask: Subtask) -> Bool {
        if let creator = subtask.createdBy {
            return creator.id == currentUser.id || isAdmin
        }
        return true
    }

    func canToggleSubtask(_ subtask: Subtask) -> Bool {
        if subtask.assignees.isEmpty {
            return true
        }
        return subtask.assignees.contains { $0.id == currentUser.id }
    }

    // MARK: - Task Progress

    func subtaskProgress(for task: DONEOTask) -> (completed: Int, total: Int) {
        let completed = task.subtasks.filter { $0.isDone }.count
        return (completed, task.subtasks.count)
    }

    // MARK: - Refresh from data service

    func refreshProject() {
        if let updatedProject = MockDataService.shared.project(withId: project.id) {
            project = updatedProject
            if let selectedId = selectedTask?.id,
               let updatedTask = project.tasks.first(where: { $0.id == selectedId }) {
                selectedTask = updatedTask
            }
        }
    }

    // MARK: - Attachment Management

    func addAttachment(
        type: AttachmentType,
        fileName: String,
        fileSize: Int64 = 0,
        thumbnailURL: URL? = nil,
        fileURL: URL? = nil,
        linkedTaskId: UUID? = nil,
        linkedSubtaskId: UUID? = nil,
        caption: String? = nil
    ) {
        let attachment = ProjectAttachment(
            type: type,
            fileName: fileName,
            fileSize: fileSize,
            uploadedBy: currentUser,
            thumbnailURL: thumbnailURL,
            fileURL: fileURL,
            linkedTaskId: linkedTaskId,
            linkedSubtaskId: linkedSubtaskId,
            caption: caption
        )
        project.attachments.append(attachment)

        // Send a message about the attachment
        var messageContent = "shared \(type == .image ? "a photo" : "a file")"
        if let caption = caption, !caption.isEmpty {
            messageContent += ": \(caption)"
        }

        var taskRef: TaskReference? = nil
        var subtaskRef: SubtaskReference? = nil

        if let taskId = linkedTaskId, let task = project.tasks.first(where: { $0.id == taskId }) {
            taskRef = TaskReference(task: task)
            if let subtaskId = linkedSubtaskId, let subtask = task.subtasks.first(where: { $0.id == subtaskId }) {
                subtaskRef = SubtaskReference(subtask: subtask)
            }
        }

        let messageAttachment = MessageAttachment(
            type: type,
            fileName: fileName,
            fileSize: fileSize,
            thumbnailURL: thumbnailURL,
            fileURL: fileURL
        )

        let message = Message(
            content: messageContent,
            sender: currentUser,
            isFromCurrentUser: true,
            referencedTask: taskRef,
            referencedSubtask: subtaskRef,
            attachment: messageAttachment
        )
        project.messages.append(message)

        // Update project's last activity
        project.lastActivity = Date()
        project.lastActivityPreview = "\(currentUser.displayFirstName) shared \(type == .image ? "a photo" : "a file")"

        MockDataService.shared.updateProject(project)
    }

    func addAttachments(
        items: [(type: AttachmentType, fileName: String, fileSize: Int64, fileURL: URL?)],
        linkedTaskId: UUID? = nil,
        linkedSubtaskId: UUID? = nil,
        caption: String? = nil
    ) {
        var attachments: [ProjectAttachment] = []

        for item in items {
            let attachment = ProjectAttachment(
                type: item.type,
                fileName: item.fileName,
                fileSize: item.fileSize,
                uploadedBy: currentUser,
                fileURL: item.fileURL,
                linkedTaskId: linkedTaskId,
                linkedSubtaskId: linkedSubtaskId,
                caption: caption
            )
            project.attachments.append(attachment)
            attachments.append(attachment)
        }

        // Send a message about the attachments
        let count = items.count
        var messageContent = count == 1
            ? "shared a \(items[0].type == .image ? "photo" : "file")"
            : "shared \(count) \(items.allSatisfy { $0.type == .image } ? "photos" : "files")"
        if let caption = caption, !caption.isEmpty {
            messageContent += ": \(caption)"
        }

        var taskRef: TaskReference? = nil
        var subtaskRef: SubtaskReference? = nil

        if let taskId = linkedTaskId, let task = project.tasks.first(where: { $0.id == taskId }) {
            taskRef = TaskReference(task: task)
            if let subtaskId = linkedSubtaskId, let subtask = task.subtasks.first(where: { $0.id == subtaskId }) {
                subtaskRef = SubtaskReference(subtask: subtask)
            }
        }

        // For multiple attachments, create a MessageAttachment for the first one
        let messageAttachment: MessageAttachment? = items.first.map { item in
            MessageAttachment(
                type: item.type,
                fileName: item.fileName,
                fileSize: item.fileSize,
                fileURL: item.fileURL
            )
        }

        let message = Message(
            content: messageContent,
            sender: currentUser,
            isFromCurrentUser: true,
            referencedTask: taskRef,
            referencedSubtask: subtaskRef,
            attachment: messageAttachment
        )
        project.messages.append(message)

        // Update project's last activity
        project.lastActivity = Date()
        project.lastActivityPreview = "\(currentUser.displayFirstName) \(messageContent)"

        MockDataService.shared.updateProject(project)
    }
}
