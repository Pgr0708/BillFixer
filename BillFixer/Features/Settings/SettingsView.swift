import SwiftUI
import UserNotifications

/// Board screen 20.
struct SettingsView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppRouter.self) private var router
    @EnvironmentObject private var settings: SettingsManager
    @Environment(\.openURL) private var openURL
    @AppStorage(AppStorageKeys.hapticsEnabled) private var haptics = true
    @AppStorage(AppStorageKeys.deadlineRemindersEnabled) private var reminders = true
    @State private var link: WebLink?
    @State private var confirmDelete = false
    @State private var confirmSignOut = false
    @State private var working = false
    @State private var notifStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Settings").font(BFFont.title(28)).foregroundStyle(BFColor.text1)

                Button { router.push(.account) } label: {
                    HStack(spacing: 14) {
                        Avatar(initial: session.user?.initial ?? "", size: 56)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.user?.displayName ?? session.user?.firstName ?? "Your account").font(BFFont.title3(18)).foregroundStyle(BFColor.text1)
                            Text(session.user?.email ?? "Signed in with Apple").font(.system(size: 14)).foregroundStyle(BFColor.text3)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(BFColor.text4)
                    }
                    .cardStyle(padding: 16, radius: 20)
                }
                .buttonStyle(.pressable)

                group {
                    Button { if session.isPremium { manageSubscription() } else { router.requirePremium(.general) } } label: {
                        SettingsRow(symbol: "crown.fill", title: "Subscription", tint: BFColor.amber, value: planLabel)
                    }
                    divider
                    Button { Task { await openNotificationSettings() } } label: {
                        SettingsRow(symbol: "bell.badge.fill", title: "Notifications", tint: BFColor.red, value: notifStatus == .authorized ? "On" : "Off")
                    }
                    divider
                    SettingsRow(symbol: "calendar.badge.clock", title: "Deadline reminders", tint: BFColor.blue) {
                        Toggle("", isOn: $reminders).labelsHidden().tint(BFColor.teal)
                    }
                    divider
                    SettingsRow(symbol: "iphone.radiowaves.left.and.right", title: "Haptics", tint: BFColor.violet) {
                        Toggle("", isOn: $haptics).labelsHidden().tint(BFColor.teal)
                    }
                    divider
                    SettingsRow(symbol: "circle.lefthalf.filled", title: "Appearance", tint: BFColor.navy2) {
                        Picker("Appearance", selection: $settings.selectedTheme) {
                            ForEach(AppTheme.allCases) { Text($0.rawValue).tag($0.rawValue) }
                        }
                        .labelsHidden().tint(BFColor.text2)
                    }
                }

                group {
                    Button { link = .support } label: { SettingsRow(symbol: "questionmark.circle.fill", title: "Help & Support", tint: BFColor.teal) }
                    divider
                    Button { emailSupport() } label: { SettingsRow(symbol: "envelope.fill", title: "Contact Us", tint: BFColor.blue) }
                    divider
                    Button { link = .privacy } label: { SettingsRow(symbol: "hand.raised.fill", title: "Privacy Policy", tint: BFColor.green) }
                    divider
                    Button { link = .terms } label: { SettingsRow(symbol: "doc.text.fill", title: "Terms of Service", tint: BFColor.text2) }
                }

                group {
                    Button { confirmSignOut = true } label: { SettingsRow(symbol: "rectangle.portrait.and.arrow.right", title: "Sign Out", tint: BFColor.text2, chevron: false) }
                    divider
                    Button { confirmDelete = true } label: { SettingsRow(symbol: "trash.fill", title: "Delete Account", destructive: true) }
                }

                Text("BillFixer \(AppInfo.version) (\(AppInfo.build)) · Not legal or medical advice.")
                    .font(.system(size: 12)).foregroundStyle(BFColor.text3).frame(maxWidth: .infinity)
            }
            .padding(BFSpacing.screen)
        }
        .scenicBackground(.settings)
        .toolbar(.hidden, for: .navigationBar)
        .webSheet($link)
        .loadingOverlay(working, "Deleting your data…")
        .onChange(of: reminders) { _, on in if !on { ReminderScheduler.cancelAll(); Toast.info("Deadline reminders off") } }
        .onChange(of: haptics) { _, on in if on { Haptics.success() } }
        .task { notifStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus }
        .confirmationDialog("Sign out of BillFixer?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { Task { await session.signOut() } }
        }
        .alert("Delete your account?", isPresented: $confirmDelete) {
            Button("Delete Everything", role: .destructive) { Task { await deleteAccount() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account, all cases, bill details, findings, letters and reminders. Subscriptions must be cancelled separately in the App Store.")
        }
    }

    private var planLabel: String {
        guard session.isPremium else { return "Free" }
        if let id = session.subscription.productId { return id.contains("annual") ? "Premium (Annual)" : "Premium (Monthly)" }
        return "Premium"
    }

    private var divider: some View { Divider().padding(.leading, 48) }

    private func group<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: 0) { content() }
            .buttonStyle(.plain)
            .padding(.horizontal, 14).padding(.vertical, 4)
            .background(BFColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(BFColor.line.opacity(0.7)))
    }

    private func manageSubscription() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") { openURL(url) }
    }

    private func openNotificationSettings() async {
        let center = UNUserNotificationCenter.current()
        if notifStatus == .notDetermined {
            let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            notifStatus = await center.notificationSettings().authorizationStatus
            if granted { Toast.success("Notifications on") }
        } else if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            openURL(url)
        }
    }

    private func emailSupport() {
        let subject = "BillFixer Support (v\(AppInfo.version))".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "mailto:\(AppInfo.supportEmail)?subject=\(subject)") {
            openURL(url) { ok in if !ok { UIPasteboard.general.string = AppInfo.supportEmail; Toast.info("Email copied", AppInfo.supportEmail) } }
        }
    }

    private func deleteAccount() async {
        working = true
        defer { working = false }
        do {
            try await session.deleteAccount()
            Toast.success("Account deleted", "All your data has been removed.")
        } catch { Toast.error(error) }
    }
}

struct AccountView: View {
    @Environment(AppSession.self) private var session
    @State private var name = ""
    @State private var saving = false

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Display name", text: $name).textContentType(.name)
                if let email = session.user?.email { LabeledContent("Email", value: email) }
                if let method = session.user?.signInMethod { LabeledContent("Sign-in", value: method == "apple" ? "Apple" : "Email") }
                if let created = session.user?.createdAt { LabeledContent("Member since", value: created.formatted(date: .abbreviated, time: .omitted)) }
            }
            Section {
                Button {
                    Task {
                        saving = true
                        defer { saving = false }
                        do { try await session.updateName(name.trimmed); Toast.success("Profile updated") } catch { Toast.error(error) }
                    }
                } label: { if saving { ProgressView() } else { Text("Save") } }
                .disabled(name.trimmed.isEmpty || name.trimmed == session.user?.displayName || saving)
            }
            Section {
                Label("Bill images are read on your iPhone and never uploaded. We store only the details you confirm.", systemImage: "lock.shield.fill")
                    .font(.footnote).foregroundStyle(BFColor.text2)
            }
        }
        .navigationTitle("Account")
        .scrollContentBackground(.hidden)
        .scenicBackground(.settings)
        .onAppear { name = session.user?.displayName ?? "" }
    }
}
