import Foundation
import SwiftUI

struct Project: Identifiable, Hashable {
    let id: UUID
    var name: String
    var description: String?
    var members: [User]
    var tasks: [DONEOTask]
    var messages: [Message]  // Project-level chat messages
    var unreadTaskIds: [UUID: Set<UUID>]  // Maps user ID to set of unread task IDs
    var lastActivity: Date?
    var lastActivityPreview: String?

    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        members: [User] = [],
        tasks: [DONEOTask] = [],
        messages: [Message] = [],
        unreadTaskIds: [UUID: Set<UUID>] = [:],
        lastActivity: Date? = nil,
        lastActivityPreview: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.members = members
        self.tasks = tasks
        self.messages = messages
        self.unreadTaskIds = unreadTaskIds
        self.lastActivity = lastActivity
        self.lastActivityPreview = lastActivityPreview
    }

    // Last message for preview in HomeView
    var lastMessage: Message? {
        messages.sorted { $0.timestamp > $1.timestamp }.first
    }

    // Get unread count for current user
    var unreadCount: Int {
        let currentUserId = MockDataService.shared.currentUser.id
        return unreadTaskIds[currentUserId]?.count ?? 0
    }

    // Mark a task as read for a user
    mutating func markTaskAsRead(_ taskId: UUID, for userId: UUID) {
        unreadTaskIds[userId]?.remove(taskId)
    }

    // Add unread notification for a user
    mutating func addUnreadTask(_ taskId: UUID, for userId: UUID) {
        if unreadTaskIds[userId] == nil {
            unreadTaskIds[userId] = []
        }
        unreadTaskIds[userId]?.insert(taskId)
    }

    var pendingTaskCount: Int {
        tasks.filter { $0.status == .pending }.count
    }

    var completedTaskCount: Int {
        tasks.filter { $0.status == .done }.count
    }

    var overdueTaskCount: Int {
        tasks.filter { $0.isOverdue }.count
    }

    var initials: String {
        let parts = name.components(separatedBy: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}
