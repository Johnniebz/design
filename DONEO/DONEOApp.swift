import SwiftUI

// MARK: - Main Tab View

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Image(systemName: "folder.fill")
                Text("Projects")
            }
            .tag(0)

            NavigationStack {
                ActivityTimelineView()
            }
            .tabItem {
                Image(systemName: "bell.fill")
                Text("Activity")
            }
            .tag(1)

            NavigationStack {
                CallsPlaceholderView()
            }
            .tabItem {
                Image(systemName: "phone.fill")
                Text("Calls")
            }
            .tag(2)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Image(systemName: "gearshape.fill")
                Text("Settings")
            }
            .tag(3)
        }
    }
}

// MARK: - Activity Timeline View

struct ActivityTimelineView: View {
    private var dataService = MockDataService.shared

    var body: some View {
        let _ = dataService.currentUser
        List {
            ForEach(dataService.activitiesForCurrentUser) { activity in
                ActivityRow(activity: activity)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Activity")
        .onAppear {
            dataService.loadMockActivities()
        }
        .overlay {
            if dataService.activitiesForCurrentUser.isEmpty {
                ContentUnavailableView(
                    "No Activity Yet",
                    systemImage: "bell",
                    description: Text("Updates from your projects will appear here")
                )
            }
        }
    }
}

struct ActivityRow: View {
    let activity: Activity

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: activity.icon)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                // Description
                Text(activity.description)
                    .font(.system(size: 15))
                    .lineLimit(2)

                // Project name + time
                HStack(spacing: 6) {
                    Text(activity.projectName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.primary)

                    Text("•")
                        .foregroundStyle(.tertiary)

                    Text(formatTime(activity.timestamp))
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }

    private var iconColor: Color {
        switch activity.iconColor {
        case "blue": return Theme.primary
        case "green": return .green
        case "orange": return .orange
        case "purple": return Theme.primary
        default: return .secondary
        }
    }

    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)

        if let days = components.day, days > 0 {
            if days == 1 {
                return "Yesterday"
            } else {
                return date.formatted(.dateTime.month(.abbreviated).day())
            }
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h ago"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "Just now"
        }
    }
}

// MARK: - Calls Placeholder

struct CallsPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Coming Soon",
            systemImage: "phone.fill",
            description: Text("Voice and video calls will be available in a future update")
        )
        .navigationTitle("Calls")
    }
}

// MARK: - App

@main
struct DONEOApp: App {
    @State private var showOnboarding = false
    @State private var hasCheckedAuth = false

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasCheckedAuth {
                    // Loading state
                    ProgressView()
                        .onAppear {
                            checkAuth()
                        }
                } else if showOnboarding {
                    OnboardingContainerView { projectName, projectDescription in
                        if let name = projectName, !name.trimmingCharacters(in: .whitespaces).isEmpty {
                            let currentUser = MockDataService.shared.currentUser
                            let newProject = Project(
                                name: name,
                                description: projectDescription,
                                members: [currentUser],
                                lastActivity: Date(),
                                lastActivityPreview: "Project created"
                            )
                            MockDataService.shared.projects.insert(newProject, at: 0)
                        }
                        showOnboarding = false
                    }
                } else {
                    MainTabView()
                }
            }
        }
    }

    private func checkAuth() {
        // For demo purposes, show onboarding only on first launch
        // In production, check AuthManager.shared.isAuthenticated
        let hasLaunched = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")

        if !hasLaunched {
            showOnboarding = true
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        } else {
            showOnboarding = false
        }

        hasCheckedAuth = true
    }
}
