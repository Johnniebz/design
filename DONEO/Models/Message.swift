import Foundation

// MARK: - Message Type

enum MessageType: Hashable {
    case regular
    case subtaskCompleted(SubtaskReference)
    case subtaskReopened(SubtaskReference)
}

struct Message: Identifiable, Hashable {
    let id: UUID
    let content: String
    let sender: User
    let timestamp: Date
    var isFromCurrentUser: Bool
    var referencedTask: TaskReference?
    var referencedSubtask: SubtaskReference?
    var quotedMessage: QuotedMessage?
    var attachment: MessageAttachment?
    var messageType: MessageType

    init(
        id: UUID = UUID(),
        content: String,
        sender: User,
        timestamp: Date = Date(),
        isFromCurrentUser: Bool = false,
        referencedTask: TaskReference? = nil,
        referencedSubtask: SubtaskReference? = nil,
        quotedMessage: QuotedMessage? = nil,
        attachment: MessageAttachment? = nil,
        messageType: MessageType = .regular
    ) {
        self.id = id
        self.content = content
        self.sender = sender
        self.timestamp = timestamp
        self.isFromCurrentUser = isFromCurrentUser
        self.referencedTask = referencedTask
        self.referencedSubtask = referencedSubtask
        self.quotedMessage = quotedMessage
        self.attachment = attachment
        self.messageType = messageType
    }
}

// MARK: - Quoted Message (for replying to messages)

struct QuotedMessage: Hashable {
    let messageId: UUID
    let senderName: String
    let content: String

    init(message: Message) {
        self.messageId = message.id
        self.senderName = message.sender.displayFirstName
        self.content = message.content
    }

    init(messageId: UUID, senderName: String, content: String) {
        self.messageId = messageId
        self.senderName = senderName
        self.content = content
    }
}

// MARK: - Task Reference (for mentioning tasks in chat)

struct TaskReference: Hashable {
    let taskId: UUID
    let taskTitle: String

    init(task: DONEOTask) {
        self.taskId = task.id
        self.taskTitle = task.title
    }

    init(taskId: UUID, taskTitle: String) {
        self.taskId = taskId
        self.taskTitle = taskTitle
    }
}

// MARK: - Subtask Reference (for mentioning subtasks in chat)

struct SubtaskReference: Hashable {
    let subtaskId: UUID
    let subtaskTitle: String

    init(subtask: Subtask) {
        self.subtaskId = subtask.id
        self.subtaskTitle = subtask.title
    }

    init(subtaskId: UUID, subtaskTitle: String) {
        self.subtaskId = subtaskId
        self.subtaskTitle = subtaskTitle
    }
}

// MARK: - Message Attachment (for sending files in chat)

struct MessageAttachment: Hashable {
    let id: UUID
    let type: AttachmentType
    let fileName: String
    let fileSize: Int64
    let thumbnailURL: URL?
    let fileURL: URL?

    init(
        id: UUID = UUID(),
        type: AttachmentType,
        fileName: String,
        fileSize: Int64 = 0,
        thumbnailURL: URL? = nil,
        fileURL: URL? = nil
    ) {
        self.id = id
        self.type = type
        self.fileName = fileName
        self.fileSize = fileSize
        self.thumbnailURL = thumbnailURL
        self.fileURL = fileURL
    }
}
