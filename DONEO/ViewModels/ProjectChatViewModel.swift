import Foundation
import Observation

@Observable
final class ProjectChatViewModel {
    var project: Project
    var newMessageText: String = ""
    var referencedTask: TaskReference? = nil
    var referencedSubtask: SubtaskReference? = nil
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
            referencedSubtask: referencedSubtask
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
    }

    func sendMessage(content: String, referencedTask: TaskReference? = nil, referencedSubtask: SubtaskReference? = nil) {
        let message = Message(
            content: content,
            sender: currentUser,
            isFromCurrentUser: true,
            referencedTask: referencedTask,
            referencedSubtask: referencedSubtask
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

    func addTask(title: String, assignees: [User] = [], subtasks: [Subtask] = []) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let task = DONEOTask(
            title: title,
            assignees: assignees,
            status: .pending,
            subtasks: subtasks,
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

    func addSubtask(to task: DONEOTask, title: String, description: String? = nil, assignees: [User] = []) {
        guard let taskIndex = project.tasks.firstIndex(where: { $0.id == task.id }),
              !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }

        let subtask = Subtask(
            title: title,
            description: description,
            assignees: assignees,
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
}
