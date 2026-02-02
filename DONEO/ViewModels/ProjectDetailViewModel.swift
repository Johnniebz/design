import Foundation
import Observation

@Observable
final class ProjectDetailViewModel {
    var project: Project
    var newTaskTitle: String = ""
    var newTaskAssignees: [User] = []
    var newTaskDueDate: Date? = nil
    var newTaskNotes: String = ""
    var newTaskAttachments: [Attachment] = []
    var newTaskSubtasks: [Subtask] = []
    var isCreatingTask: Bool = false

    init(project: Project) {
        self.project = project
    }

    private func syncProject() {
        MockDataService.shared.updateProject(project)
    }

    // Pending tasks sorted by activity (most recent first)
    var pendingTasks: [DONEOTask] {
        project.tasks.filter { $0.status == .pending }.sorted { $0.lastActivity > $1.lastActivity }
    }

    // Completed tasks sorted by activity (most recent first)
    var completedTasks: [DONEOTask] {
        project.tasks.filter { $0.status == .done }.sorted { $0.lastActivity > $1.lastActivity }
    }

    // All tasks: pending first (sorted by activity), then completed at bottom
    var allTasksSortedByActivity: [DONEOTask] {
        pendingTasks + completedTasks
    }

    // Get unread count for a task (for now, 1 if unread, 0 if read)
    // In a real app, this would count unread messages/updates
    func unreadCount(for task: DONEOTask) -> Int {
        let currentUserId = MockDataService.shared.currentUser.id
        let isUnread = project.unreadTaskIds[currentUserId]?.contains(task.id) ?? false
        // For now return 1 if unread, could be enhanced to track actual message count
        return isUnread ? 1 : 0
    }

    func isTaskAssignedToCurrentUser(_ task: DONEOTask) -> Bool {
        let currentUserId = MockDataService.shared.currentUser.id
        return task.assignees.contains { $0.id == currentUserId }
    }

    func createTask() {
        guard !newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let currentUser = MockDataService.shared.currentUser
        let currentUserId = currentUser.id

        // Prepare notes (trimmed, nil if empty)
        let notes = newTaskNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalNotes: String? = notes.isEmpty ? nil : notes

        let task = DONEOTask(
            title: newTaskTitle,
            assignees: newTaskAssignees,
            dueDate: newTaskDueDate,
            createdAt: Date(),
            subtasks: newTaskSubtasks,
            attachments: newTaskAttachments,
            notes: finalNotes,
            createdBy: currentUser
        )
        project.tasks.insert(task, at: 0)
        project.lastActivity = Date()
        project.lastActivityPreview = "New task: \(newTaskTitle)"

        // Notify all members except the creator
        for member in project.members where member.id != currentUserId {
            project.addUnreadTask(task.id, for: member.id)
        }

        syncProject()
        resetNewTaskFields()
    }

    func resetNewTaskFields() {
        newTaskTitle = ""
        newTaskAssignees = []
        newTaskDueDate = nil
        newTaskNotes = ""
        newTaskAttachments = []
        newTaskSubtasks = []
        isCreatingTask = false
    }

    func addNewTaskAttachment(_ attachment: Attachment) {
        newTaskAttachments.append(attachment)
    }

    func removeNewTaskAttachment(_ attachment: Attachment) {
        newTaskAttachments.removeAll { $0.id == attachment.id }
    }

    func toggleNewTaskAssignee(_ user: User) {
        if let index = newTaskAssignees.firstIndex(where: { $0.id == user.id }) {
            newTaskAssignees.remove(at: index)
        } else {
            newTaskAssignees.append(user)
        }
    }

    func addNewTaskSubtask(title: String, description: String? = nil, assignees: [User] = []) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let desc = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtask = Subtask(title: title, description: desc?.isEmpty == true ? nil : desc, assignees: assignees)
        newTaskSubtasks.append(subtask)
    }

    func removeNewTaskSubtask(_ subtask: Subtask) {
        newTaskSubtasks.removeAll { $0.id == subtask.id }
    }

    func toggleTaskStatus(_ task: DONEOTask) {
        guard let index = project.tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let currentUserId = MockDataService.shared.currentUser.id
        let newStatus: TaskStatus = task.status == .pending ? .done : .pending
        project.tasks[index].status = newStatus
        project.tasks[index].lastActivity = Date()
        project.lastActivity = Date()
        if newStatus == .done {
            project.lastActivityPreview = "Completed: \(task.title)"
        } else {
            project.lastActivityPreview = "Reopened: \(task.title)"
        }

        // Notify all members except the one who toggled
        for member in project.members where member.id != currentUserId {
            project.addUnreadTask(task.id, for: member.id)
        }
        syncProject()
    }

    func deleteTask(_ task: DONEOTask) {
        project.tasks.removeAll { $0.id == task.id }
        syncProject()
    }

    func toggleTaskAssignee(_ task: DONEOTask, user: User) {
        guard let index = project.tasks.firstIndex(where: { $0.id == task.id }) else { return }
        if let userIndex = project.tasks[index].assignees.firstIndex(where: { $0.id == user.id }) {
            project.tasks[index].assignees.remove(at: userIndex)
        } else {
            project.tasks[index].assignees.append(user)
        }
        syncProject()
    }

    func markTaskAsRead(_ task: DONEOTask) {
        let currentUserId = MockDataService.shared.currentUser.id
        project.markTaskAsRead(task.id, for: currentUserId)
        syncProject()
    }
}
