import Foundation
import Observation

// MARK: - Activity Model

enum ActivityType: String {
    case taskAssigned = "assigned"
    case taskCompleted = "completed"
    case taskReopened = "reopened"
    case taskCreated = "created"
    case messageSent = "message"
}

struct Activity: Identifiable {
    let id: UUID
    let type: ActivityType
    let timestamp: Date
    let actorId: UUID      // Who performed the action
    let actorName: String
    let projectId: UUID
    let projectName: String
    let taskId: UUID?
    let taskTitle: String?
    let messagePreview: String?

    init(
        id: UUID = UUID(),
        type: ActivityType,
        timestamp: Date = Date(),
        actor: User,
        project: Project,
        task: DONEOTask? = nil,
        messagePreview: String? = nil
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.actorId = actor.id
        self.actorName = actor.name
        self.projectId = project.id
        self.projectName = project.name
        self.taskId = task?.id
        self.taskTitle = task?.title
        self.messagePreview = messagePreview
    }

    var description: String {
        let firstName = actorName.components(separatedBy: " ").first ?? actorName
        switch type {
        case .taskAssigned:
            return "\(firstName) assigned you: \(taskTitle ?? "a task")"
        case .taskCompleted:
            return "\(firstName) completed: \(taskTitle ?? "a task")"
        case .taskReopened:
            return "\(firstName) reopened: \(taskTitle ?? "a task")"
        case .taskCreated:
            return "\(firstName) created: \(taskTitle ?? "a task")"
        case .messageSent:
            return "\(firstName): \(messagePreview ?? "sent a message")"
        }
    }

    var icon: String {
        switch type {
        case .taskAssigned: return "person.badge.plus"
        case .taskCompleted: return "checkmark.circle.fill"
        case .taskReopened: return "arrow.uturn.backward.circle"
        case .taskCreated: return "plus.circle.fill"
        case .messageSent: return "message.fill"
        }
    }

    var iconColor: String {
        switch type {
        case .taskAssigned: return "blue"
        case .taskCompleted: return "green"
        case .taskReopened: return "orange"
        case .taskCreated: return "purple"
        case .messageSent: return "blue"
        }
    }
}

// MARK: - Mock Data Service

@Observable
final class MockDataService {
    static let shared = MockDataService()

    private init() {
        _currentUser = Self.allUsers[0]
    }

    // MARK: - Mock Users

    static let allUsers: [User] = [
        User(name: "Alex Johnson", phoneNumber: "+1 555-0100"),
        User(name: "Maria Garcia", phoneNumber: "+1 555-0101"),
        User(name: "James Wilson", phoneNumber: "+1 555-0102"),
        User(name: "Sarah Chen", phoneNumber: "+1 555-0103"),
        User(name: "Mike Thompson", phoneNumber: "+1 555-0104")
    ]

    private var _currentUser: User

    var currentUser: User {
        get { _currentUser }
        set { _currentUser = newValue }
    }

    var mockUsers: [User] {
        Self.allUsers
    }

    func switchUser(to user: User) {
        _currentUser = user
    }

    var currentUserIndex: Int {
        Self.allUsers.firstIndex(where: { $0.id == currentUser.id }) ?? 0
    }

    // MARK: - Projects (shared data store)

    var projects: [Project] = []

    func loadProjects() {
        if projects.isEmpty {
            projects = createMockProjects()
        }
    }

    func updateProject(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        }
    }

    // MARK: - Activities (timeline)

    var activities: [Activity] = []

    func addActivity(type: ActivityType, actor: User, project: Project, task: DONEOTask? = nil, messagePreview: String? = nil) {
        let activity = Activity(
            type: type,
            actor: actor,
            project: project,
            task: task,
            messagePreview: messagePreview
        )
        activities.insert(activity, at: 0)
    }

    // Activities for current user (excludes own actions)
    var activitiesForCurrentUser: [Activity] {
        activities.filter { $0.actorId != currentUser.id }
    }

    func loadMockActivities() {
        guard activities.isEmpty else { return }
        let maria = Self.allUsers[1]
        let james = Self.allUsers[2]
        let sarah = Self.allUsers[3]

        guard let project1 = projects.first,
              let project2 = projects.dropFirst().first else { return }

        // Create some mock activities
        activities = [
            Activity(type: .messageSent, timestamp: Date().addingTimeInterval(-300), actor: maria, project: project1, messagePreview: "Can you check the measurements?"),
            Activity(type: .taskCompleted, timestamp: Date().addingTimeInterval(-1800), actor: james, project: project1, task: project1.tasks.first { $0.status == .done }),
            Activity(type: .taskAssigned, timestamp: Date().addingTimeInterval(-3600), actor: sarah, project: project2, task: project2.tasks.first),
            Activity(type: .taskCreated, timestamp: Date().addingTimeInterval(-7200), actor: maria, project: project1, task: project1.tasks.first),
            Activity(type: .messageSent, timestamp: Date().addingTimeInterval(-86400), actor: james, project: project1, messagePreview: "I'll finish the tiling tomorrow"),
        ]
    }

    func project(withId id: UUID) -> Project? {
        projects.first { $0.id == id }
    }

    // MARK: - Mock Projects

    private func createMockProjects() -> [Project] {
        let alex = Self.allUsers[0]
        let maria = Self.allUsers[1]
        let james = Self.allUsers[2]
        let sarah = Self.allUsers[3]
        let mike = Self.allUsers[4]

        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)
        let nextWeek = Calendar.current.date(byAdding: .day, value: 5, to: today)

        // Create sample messages for projects
        let project1Messages: [Message] = [
            Message(
                content: "Let's start ordering the kitchen materials this week",
                sender: alex,
                timestamp: Calendar.current.date(byAdding: .hour, value: -5, to: today) ?? today,
                isFromCurrentUser: true
            ),
            Message(
                content: "I'll get the quotes from suppliers today",
                sender: maria,
                timestamp: Calendar.current.date(byAdding: .hour, value: -4, to: today) ?? today,
                isFromCurrentUser: false
            ),
            Message(
                content: "Can you check the measurements?",
                sender: maria,
                timestamp: Calendar.current.date(byAdding: .minute, value: -30, to: today) ?? today,
                isFromCurrentUser: false
            )
        ]

        let project2Messages: [Message] = [
            Message(
                content: "Final walkthrough scheduled for tomorrow",
                sender: alex,
                timestamp: Calendar.current.date(byAdding: .hour, value: -3, to: today) ?? today,
                isFromCurrentUser: true
            ),
            Message(
                content: "I'll prepare the checklist",
                sender: sarah,
                timestamp: Calendar.current.date(byAdding: .hour, value: -2, to: today) ?? today,
                isFromCurrentUser: false
            )
        ]

        let project3Messages: [Message] = [
            Message(
                content: "HVAC units need to be ordered by Friday",
                sender: mike,
                timestamp: Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today,
                isFromCurrentUser: false
            ),
            Message(
                content: "Got it, I'll coordinate with the supplier",
                sender: alex,
                timestamp: Calendar.current.date(byAdding: .hour, value: -6, to: today) ?? today,
                isFromCurrentUser: true
            ),
            Message(
                content: "Blueprints review meeting tomorrow at 10am",
                sender: maria,
                timestamp: Calendar.current.date(byAdding: .minute, value: -45, to: today) ?? today,
                isFromCurrentUser: false
            )
        ]

        // Create tasks with known IDs for notification tracking
        let task1_1 = DONEOTask(
            title: "Order materials for kitchen",
            assignees: [maria],
            status: .pending,
            dueDate: today,
            subtasks: [
                Subtask(title: "Get quotes from 3 suppliers", isDone: true, assignees: [maria], createdBy: james),
                Subtask(title: "Compare prices and quality", isDone: true, assignees: [maria, james], createdBy: james),
                Subtask(title: "Place order with selected vendor", isDone: false, assignees: [maria], createdBy: james),
                Subtask(title: "Confirm delivery date", isDone: false, createdBy: james)
            ],
            attachments: [
                Attachment(
                    type: .document,
                    category: .reference,
                    fileName: "Kitchen_Materials_List.pdf",
                    fileSize: 245_000,
                    uploadedBy: james
                ),
                Attachment(
                    type: .image,
                    category: .reference,
                    fileName: "Kitchen_Blueprint.jpg",
                    fileSize: 1_200_000,
                    uploadedBy: james
                )
            ],
            notes: """
            Contact: HomeDepot Pro Desk
            Phone: (555) 123-4567
            Account #: PRO-2847593

            Materials needed:
            - 24 sq ft ceramic tiles (Tuscany Beige)
            - 3 bags thin-set mortar
            - Grout (Sandstone color)
            - Tile spacers 1/4"

            Delivery address:
            742 Maple Street, Downtown
            """,
            createdBy: james
        )
        let task1_2 = DONEOTask(
            title: "Schedule electrical inspection",
            assignees: [alex],
            status: .pending,
            dueDate: tomorrow,
            subtasks: [
                Subtask(title: "Call inspector office", isDone: true, assignees: [alex], createdBy: maria),
                Subtask(title: "Prepare documentation", isDone: false, assignees: [james, alex], createdBy: maria),
                Subtask(title: "Clear access to electrical panel", isDone: false, createdBy: maria)
            ],
            notes: """
            City Inspector: Bob Martinez
            Office: (555) 234-5678

            Required documents:
            - Permit #EL-2024-0847
            - Electrical plans (revised)
            - Contractor license copy

            Inspector prefers morning appointments (8-10am)
            """,
            createdBy: maria,
            acknowledgedBy: [alex.id] // Alex has accepted this task
        )
        let task1_3 = DONEOTask(title: "Complete bathroom tiling", assignees: [james], status: .done, createdBy: alex)

        // New task for Alex - painting
        let task1_4_paint = DONEOTask(
            title: "Paint living room walls",
            assignees: [alex, james],
            status: .pending,
            dueDate: tomorrow,
            subtasks: [
                Subtask(title: "Buy paint supplies", isDone: true, assignees: [james], createdBy: maria),
                Subtask(title: "Prep walls and tape edges", isDone: false, assignees: [alex], createdBy: maria),
                Subtask(title: "Apply first coat", isDone: false, assignees: [alex, james], createdBy: maria),
                Subtask(title: "Apply second coat", isDone: false, createdBy: maria)
            ],
            notes: "Color: Benjamin Moore Cloud White OC-130\n2 gallons needed",
            createdBy: maria
            // Not acknowledged by Alex yet - NEW task
        )

        let task1_5 = DONEOTask(
            title: "Install new windows",
            assignees: [alex],
            status: .pending,
            dueDate: nextWeek,
            subtasks: [
                Subtask(title: "Measure all window frames", isDone: false, assignees: [james], createdBy: james),
                Subtask(title: "Order custom windows", isDone: false, assignees: [maria, alex], createdBy: james),
                Subtask(title: "Remove old windows", isDone: false, createdBy: james),
                Subtask(title: "Install new windows", isDone: false, createdBy: james),
                Subtask(title: "Seal and insulate", isDone: false, createdBy: james)
            ],
            attachments: [
                Attachment(
                    type: .document,
                    category: .reference,
                    fileName: "Window_Specifications.pdf",
                    fileSize: 890_000,
                    uploadedBy: james
                ),
                Attachment(
                    type: .image,
                    category: .reference,
                    fileName: "Window_Measurements_Photo.jpg",
                    fileSize: 2_400_000,
                    uploadedBy: james
                ),
                Attachment(
                    type: .image,
                    category: .work,
                    fileName: "Old_Window_Removed.jpg",
                    fileSize: 1_800_000,
                    uploadedBy: alex,
                    caption: "First window removed successfully"
                )
            ],
            notes: """
            Window supplier: ClearView Glass Co.
            Sales rep: Jennifer Wong
            Phone: (555) 345-6789

            Specs: Double-pane, Low-E, Argon filled
            Frame color: White vinyl

            Lead time: 2-3 weeks for custom sizes
            """,
            createdBy: james,
            acknowledgedBy: [alex.id] // Alex acknowledged
        )

        // More tasks for Downtown Renovation
        let task1_6 = DONEOTask(
            title: "Fix leaking faucet in kitchen",
            assignees: [alex],
            status: .pending,
            dueDate: today,
            notes: "Client reported leak under sink. Check P-trap and connections.",
            createdBy: maria,
            acknowledgedBy: [alex.id]
        )

        let task1_7 = DONEOTask(
            title: "Install cabinet hardware",
            assignees: [alex],
            status: .pending,
            subtasks: [
                Subtask(title: "Unpack all hardware", isDone: true, assignees: [alex], createdBy: james),
                Subtask(title: "Mark drill positions", isDone: true, assignees: [alex], createdBy: james),
                Subtask(title: "Install handles on upper cabinets", isDone: false, createdBy: james),
                Subtask(title: "Install handles on lower cabinets", isDone: false, createdBy: james),
                Subtask(title: "Install drawer pulls", isDone: false, createdBy: james)
            ],
            createdBy: james,
            acknowledgedBy: [alex.id]
        )

        let task2_1 = DONEOTask(
            title: "Final walkthrough",
            assignees: [alex],
            status: .pending,
            dueDate: yesterday,
            subtasks: [
                Subtask(title: "Check all rooms", isDone: true, assignees: [alex], createdBy: sarah),
                Subtask(title: "Test electrical outlets", isDone: true, createdBy: sarah),
                Subtask(title: "Test plumbing", isDone: false, assignees: [alex, sarah], createdBy: sarah),
                Subtask(title: "Document any issues", isDone: false, assignees: [sarah], createdBy: sarah)
            ],
            attachments: [
                Attachment(
                    type: .document,
                    category: .reference,
                    fileName: "Walkthrough_Checklist.pdf",
                    fileSize: 156_000,
                    uploadedBy: sarah
                ),
                Attachment(
                    type: .image,
                    category: .work,
                    fileName: "Living_Room_Complete.jpg",
                    fileSize: 2_100_000,
                    uploadedBy: alex,
                    caption: "Living room inspection passed"
                ),
                Attachment(
                    type: .image,
                    category: .work,
                    fileName: "Kitchen_Outlets_Test.jpg",
                    fileSize: 1_900_000,
                    uploadedBy: alex,
                    caption: "All kitchen outlets working"
                )
            ],
            notes: """
            Property: Smith Residence
            Address: 1847 Oak Avenue, Riverside

            Client contact: Mr. & Mrs. Smith
            Phone: (555) 456-7890

            Gate code: 4523
            Lockbox code: 1234

            Take photos of any issues found!
            """,
            createdBy: sarah,
            acknowledgedBy: [alex.id] // Alex has accepted this task
        )
        let task2_2 = DONEOTask(title: "Fix garage door", assignees: [sarah], status: .done, createdBy: alex)

        // New tasks for Smith Residence
        let task2_3 = DONEOTask(
            title: "Touch up paint in hallway",
            assignees: [alex],
            status: .pending,
            dueDate: today,
            notes: "Small scuffs near front door. Paint code: SW7015 Repose Gray",
            createdBy: sarah
            // NEW - not acknowledged
        )

        let task2_4 = DONEOTask(
            title: "Replace smoke detector batteries",
            assignees: [alex, sarah],
            status: .pending,
            subtasks: [
                Subtask(title: "Check upstairs detectors", isDone: false, assignees: [alex], createdBy: sarah),
                Subtask(title: "Check downstairs detectors", isDone: false, assignees: [sarah], createdBy: sarah),
                Subtask(title: "Test all alarms", isDone: false, createdBy: sarah)
            ],
            createdBy: sarah,
            acknowledgedBy: [alex.id, sarah.id]
        )

        let task3_1 = DONEOTask(
            title: "Review blueprints",
            assignees: [mike],
            status: .pending,
            dueDate: today,
            subtasks: [
                Subtask(title: "Review structural plans", isDone: true, assignees: [mike], createdBy: alex),
                Subtask(title: "Check electrical layout", isDone: false, assignees: [alex, mike], createdBy: alex),
                Subtask(title: "Verify plumbing routes", isDone: false, assignees: [maria], createdBy: alex)
            ],
            createdBy: alex
        )
        let task3_2 = DONEOTask(
            title: "Order HVAC units",
            assignees: [maria, alex],
            status: .pending,
            dueDate: nextWeek,
            notes: """
            Supplier: Climate Control Systems
            Contact: Tom Richards
            Phone: (555) 567-8901
            Email: tom@climatecontrol.com

            Quote #: CCS-2024-1847
            2x Carrier 5-ton units
            Total: $12,450 (includes installation)

            Requires 50% deposit to order
            """,
            createdBy: mike,
            acknowledgedBy: [maria.id] // Maria accepted, but Alex hasn't yet - NEW for Alex
        )
        let task3_3 = DONEOTask(
            title: "Coordinate with city inspector",
            assignees: [alex],
            status: .pending,
            notes: """
            Building Department: (555) 678-9012
            Permit #: BLD-2024-0293

            Inspections needed:
            1. Foundation (PASSED)
            2. Framing (PASSED)
            3. Electrical rough-in (SCHEDULED)
            4. Plumbing rough-in (PENDING)
            5. Final inspection

            Inspector assigned: Carlos Mendez
            """,
            createdBy: maria // Maria assigned this to Alex - NEW task needing acknowledgment
        )
        let task3_4 = DONEOTask(title: "Complete foundation work", assignees: [mike], status: .done, createdBy: alex)
        let task3_5 = DONEOTask(title: "Install plumbing rough-in", assignees: [alex], status: .pending, dueDate: tomorrow, createdBy: mike)

        // More tasks for Office Building
        let task3_6 = DONEOTask(
            title: "Schedule concrete pour",
            assignees: [alex],
            status: .pending,
            dueDate: nextWeek,
            notes: "Need 15 cubic yards. Coordinate with pump truck.",
            createdBy: mike,
            acknowledgedBy: [alex.id]
        )

        let task3_7 = DONEOTask(
            title: "Order electrical panels",
            assignees: [alex, maria],
            status: .pending,
            dueDate: today,
            subtasks: [
                Subtask(title: "Get quote from ElectroPro", isDone: true, assignees: [maria], createdBy: mike),
                Subtask(title: "Confirm panel specs with engineer", isDone: false, assignees: [alex], createdBy: mike),
                Subtask(title: "Place order", isDone: false, createdBy: mike)
            ],
            createdBy: mike
            // NEW - Alex hasn't acknowledged
        )

        let task3_8 = DONEOTask(
            title: "Update project timeline",
            assignees: [alex],
            status: .pending,
            notes: "Client wants revised schedule by EOD Friday",
            createdBy: maria
            // NEW - not acknowledged
        )

        let task4_1 = DONEOTask(title: "Service excavator", assignees: [james], status: .done, createdBy: alex)
        let task4_2 = DONEOTask(title: "Replace drill bits", assignees: [mike], status: .done, createdBy: alex)

        // New tasks for Equipment Maintenance
        let task4_3 = DONEOTask(
            title: "Inspect safety harnesses",
            assignees: [alex],
            status: .pending,
            dueDate: tomorrow,
            notes: "Annual inspection due. Check all 8 harnesses.",
            createdBy: james,
            acknowledgedBy: [alex.id]
        )

        let task4_4 = DONEOTask(
            title: "Order replacement blades",
            assignees: [alex, mike],
            status: .pending,
            subtasks: [
                Subtask(title: "Check inventory", isDone: true, assignees: [mike], createdBy: james),
                Subtask(title: "Get quotes", isDone: false, assignees: [alex], createdBy: james),
                Subtask(title: "Submit purchase order", isDone: false, createdBy: james)
            ],
            createdBy: james
            // NEW - Alex hasn't acknowledged
        )

        let task5_1 = DONEOTask(title: "Send invoice", assignees: [alex], status: .pending, dueDate: yesterday, createdBy: sarah, acknowledgedBy: [alex.id])
        let task5_2 = DONEOTask(title: "Schedule follow-up meeting", assignees: [sarah], status: .pending, dueDate: tomorrow, createdBy: alex)

        // More tasks for ABC Corp
        let task5_3 = DONEOTask(
            title: "Prepare project closeout docs",
            assignees: [alex],
            status: .pending,
            dueDate: nextWeek,
            subtasks: [
                Subtask(title: "Compile warranties", isDone: false, assignees: [alex], createdBy: sarah),
                Subtask(title: "Gather as-built drawings", isDone: false, createdBy: sarah),
                Subtask(title: "Write project summary", isDone: false, assignees: [sarah], createdBy: sarah)
            ],
            createdBy: sarah,
            acknowledgedBy: [alex.id]
        )

        let task5_4 = DONEOTask(
            title: "Review final punch list",
            assignees: [alex],
            status: .pending,
            dueDate: today,
            notes: "12 items remaining. Client walkthrough at 2pm.",
            createdBy: sarah
            // NEW - not acknowledged
        )

        // Create mock attachments for projects
        let project1Attachments: [ProjectAttachment] = [
            ProjectAttachment(
                type: .document,
                fileName: "Kitchen_Materials_Quote.pdf",
                fileSize: 245_000,
                uploadedBy: maria,
                uploadedAt: Calendar.current.date(byAdding: .day, value: -3, to: today) ?? today,
                linkedTaskId: task1_1.id
            ),
            ProjectAttachment(
                type: .document,
                fileName: "Supplier_Comparison.xlsx",
                fileSize: 128_000,
                uploadedBy: maria,
                uploadedAt: Calendar.current.date(byAdding: .day, value: -2, to: today) ?? today,
                linkedTaskId: task1_1.id
            ),
            ProjectAttachment(
                type: .image,
                fileName: "Kitchen_Measurements.jpg",
                fileSize: 3_200_000,
                uploadedBy: james,
                uploadedAt: Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today,
                linkedTaskId: task1_1.id
            ),
            ProjectAttachment(
                type: .document,
                fileName: "Electrical_Permit.pdf",
                fileSize: 89_000,
                uploadedBy: alex,
                uploadedAt: Calendar.current.date(byAdding: .hour, value: -5, to: today) ?? today,
                linkedTaskId: task1_2.id
            ),
            ProjectAttachment(
                type: .image,
                fileName: "Bathroom_Tiling_Complete.jpg",
                fileSize: 2_800_000,
                uploadedBy: james,
                uploadedAt: Calendar.current.date(byAdding: .day, value: -4, to: today) ?? today,
                linkedTaskId: task1_3.id
            ),
            ProjectAttachment(
                type: .document,
                fileName: "Window_Specs.pdf",
                fileSize: 156_000,
                uploadedBy: alex,
                uploadedAt: Calendar.current.date(byAdding: .hour, value: -2, to: today) ?? today,
                linkedTaskId: task1_5.id
            )
        ]

        let project2Attachments: [ProjectAttachment] = [
            ProjectAttachment(
                type: .document,
                fileName: "Walkthrough_Checklist.pdf",
                fileSize: 67_000,
                uploadedBy: sarah,
                uploadedAt: Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today,
                linkedTaskId: task2_1.id
            ),
            ProjectAttachment(
                type: .image,
                fileName: "Plumbing_Issue.jpg",
                fileSize: 1_950_000,
                uploadedBy: alex,
                uploadedAt: Calendar.current.date(byAdding: .hour, value: -3, to: today) ?? today,
                linkedTaskId: task2_1.id
            ),
            ProjectAttachment(
                type: .image,
                fileName: "Garage_Door_Fixed.jpg",
                fileSize: 2_100_000,
                uploadedBy: sarah,
                uploadedAt: Calendar.current.date(byAdding: .day, value: -2, to: today) ?? today,
                linkedTaskId: task2_2.id
            )
        ]

        let project3Attachments: [ProjectAttachment] = [
            ProjectAttachment(
                type: .document,
                fileName: "Phase2_Blueprints_v3.pdf",
                fileSize: 4_500_000,
                uploadedBy: mike,
                uploadedAt: Calendar.current.date(byAdding: .day, value: -5, to: today) ?? today,
                linkedTaskId: task3_1.id
            ),
            ProjectAttachment(
                type: .document,
                fileName: "HVAC_Quote_ClimateControl.pdf",
                fileSize: 312_000,
                uploadedBy: maria,
                uploadedAt: Calendar.current.date(byAdding: .day, value: -2, to: today) ?? today,
                linkedTaskId: task3_2.id
            ),
            ProjectAttachment(
                type: .document,
                fileName: "City_Permit_BLD-2024-0293.pdf",
                fileSize: 178_000,
                uploadedBy: alex,
                uploadedAt: Calendar.current.date(byAdding: .day, value: -7, to: today) ?? today,
                linkedTaskId: task3_3.id
            ),
            ProjectAttachment(
                type: .image,
                fileName: "Foundation_Inspection_Pass.jpg",
                fileSize: 2_400_000,
                uploadedBy: mike,
                uploadedAt: Calendar.current.date(byAdding: .day, value: -10, to: today) ?? today,
                linkedTaskId: task3_4.id
            ),
            ProjectAttachment(
                type: .document,
                fileName: "Plumbing_Layout.pdf",
                fileSize: 890_000,
                uploadedBy: alex,
                uploadedAt: Calendar.current.date(byAdding: .hour, value: -6, to: today) ?? today,
                linkedTaskId: task3_5.id
            )
        ]

        let project5Attachments: [ProjectAttachment] = [
            ProjectAttachment(
                type: .document,
                fileName: "Invoice_ABC-2024-0158.pdf",
                fileSize: 145_000,
                uploadedBy: alex,
                uploadedAt: Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today,
                linkedTaskId: task5_1.id
            ),
            ProjectAttachment(
                type: .document,
                fileName: "Project_Summary.docx",
                fileSize: 234_000,
                uploadedBy: sarah,
                uploadedAt: Calendar.current.date(byAdding: .hour, value: -8, to: today) ?? today
            )
        ]

        return [
            Project(
                name: "Downtown Renovation",
                members: [alex, maria, james],
                tasks: [task1_1, task1_2, task1_3, task1_4_paint, task1_5, task1_6, task1_7],
                messages: project1Messages,
                attachments: project1Attachments,
                unreadTaskIds: [
                    alex.id: [task1_1.id, task1_3.id],
                    maria.id: [task1_2.id],
                    james.id: [task1_1.id, task1_2.id]
                ],
                lastActivity: Date(),
                lastActivityPreview: "Maria: Can you check the measurements?"
            ),
            Project(
                name: "Smith Residence",
                members: [alex, sarah],
                tasks: [task2_1, task2_2, task2_3, task2_4],
                messages: project2Messages,
                attachments: project2Attachments,
                unreadTaskIds: [:],
                lastActivity: Calendar.current.date(byAdding: .hour, value: -2, to: Date()),
                lastActivityPreview: "Completed: Fix garage door"
            ),
            Project(
                name: "Office Building - Phase 2",
                members: [alex, maria, mike],
                tasks: [task3_1, task3_2, task3_3, task3_4, task3_5, task3_6, task3_7, task3_8],
                messages: project3Messages,
                attachments: project3Attachments,
                unreadTaskIds: [
                    alex.id: [task3_1.id, task3_2.id, task3_4.id, task3_5.id],
                    maria.id: [task3_1.id, task3_3.id, task3_4.id],
                    mike.id: [task3_2.id, task3_3.id, task3_5.id]
                ],
                lastActivity: Calendar.current.date(byAdding: .minute, value: -30, to: Date()),
                lastActivityPreview: "New task: Install plumbing rough-in"
            ),
            Project(
                name: "Equipment Maintenance",
                members: [alex, james, mike],
                tasks: [task4_1, task4_2, task4_3, task4_4],
                messages: [],
                attachments: [],
                unreadTaskIds: [:],
                lastActivity: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
                lastActivityPreview: "Completed: Replace drill bits"
            ),
            Project(
                name: "Client: ABC Corp",
                members: [alex, sarah],
                tasks: [task5_1, task5_2, task5_3, task5_4],
                messages: [],
                attachments: project5Attachments,
                unreadTaskIds: [
                    alex.id: [task5_2.id]
                ],
                lastActivity: Calendar.current.date(byAdding: .hour, value: -5, to: Date()),
                lastActivityPreview: "Sarah: Invoice is ready for review"
            )
        ]
    }
}
