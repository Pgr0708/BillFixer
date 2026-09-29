import SwiftUI
import UserNotifications

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
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(hex: 0xF0F4FF), Color(hex: 0xF7F9FD)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            circleDecorations

            ScrollView {
                VStack(spacing: 20) {

                    // Title
                    HStack {
                        Text("Settings")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(BFColor.text1)
                        Spacer()
                    }
                    .padding(.top, 8)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -10)

                    // ── Account card ──────────────────────────────────────
                    accountCard
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: appeared)

                    // ── Subscription status banner ────────────────────────
                    subscriptionBanner
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.08), value: appeared)

                    // ── Preferences group ─────────────────────────────────
                    settingsGroup("Preferences") {
                        settingsRow("bell.badge.fill", "Notifications",
                                    tint: BFColor.red,
                                    value: notifStatus == .authorized ? "On" : "Off") {
                            Task { await openNotificationSettings() }
                        }
                        Divider().padding(.leading, 56)
                        settingsToggleRow("calendar.badge.clock", "Deadline reminders",
                                          tint: BFColor.blue, isOn: $reminders)
                        Divider().padding(.leading, 56)
                        settingsToggleRow("iphone.radiowaves.left.and.right", "Haptics",
                                          tint: BFColor.violet, isOn: $haptics)
                        Divider().padding(.leading, 56)
                        appearanceRow
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.12), value: appeared)

                    // ── Support group ─────────────────────────────────────
                    settingsGroup("Support & Legal") {
                        settingsRow("questionmark.circle.fill", "Help & Support", tint: BFColor.teal) { link = .support }
                        Divider().padding(.leading, 56)
                        settingsRow("envelope.fill", "Contact Us", tint: BFColor.blue) { emailSupport() }
                        Divider().padding(.leading, 56)
                        settingsRow("hand.raised.fill", "Privacy Policy", tint: BFColor.green) { link = .privacy }
                        Divider().padding(.leading, 56)
                        settingsRow("doc.text.fill", "Terms of Service", tint: BFColor.text2) { link = .terms }
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.16), value: appeared)

                    // ── Danger zone ───────────────────────────────────────
                    settingsGroup("Account Actions") {
                        settingsRow("rectangle.portrait.and.arrow.right", "Sign Out",
                                    tint: BFColor.text3, chevron: false) { confirmSignOut = true }
                        Divider().padding(.leading, 56)
                        settingsRow("trash.fill", "Delete Account",
                                    tint: BFColor.red, chevron: false) { confirmDelete = true }
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.20), value: appeared)

                    // Version
                    Text("BillFixer \(AppInfo.version) (\(AppInfo.build)) · Not legal or medical advice.")
                        .font(.system(size: 12))
                        .foregroundStyle(BFColor.text4)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .opacity(appeared ? 1 : 0)

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
        }
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
            Text("This permanently deletes your account, all cases, bill details, findings, letters and reminders.")
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) { appeared = true }
        }
    }

    // MARK: - Account card

    private var accountCard: some View {
        Button { router.push(.account) } label: {
            HStack(spacing: 14) {
                // Large circular avatar
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: 0x0B2B5C), Color(hex: 0x2E7DF6)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 56, height: 56)
                    Text(session.user?.initial ?? "U")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.user?.displayName ?? session.user?.firstName ?? "Your Account")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(BFColor.text1)
                    Text(session.user?.email ?? "Signed in with Apple")
                        .font(.system(size: 13))
                        .foregroundStyle(BFColor.text3)
                }
                Spacer()
                Circle()
                    .fill(BFColor.blueSoft)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(BFColor.blue)
                    }
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        }
        .buttonStyle(.pressable)
    }

    // MARK: - Subscription banner

    @ViewBuilder
    private var subscriptionBanner: some View {
        Button {
            if session.isPremium { manageSubscription() } else { router.requirePremium(.general) }
        } label: {
            HStack(spacing: 14) {
                // Crown circle
                Circle()
                    .fill(session.isPremium
                        ? LinearGradient(colors: [Color(hex: 0xFFC554), Color(hex: 0xF5A623)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [BFColor.line, BFColor.line],
                                          startPoint: .top, endPoint: .bottom))
                    .frame(width: 46, height: 46)
                    .overlay {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(session.isPremium ? .white : BFColor.text3)
                    }
                    .shadow(color: session.isPremium ? Color(hex: 0xF5A623).opacity(0.35) : .clear,
                            radius: 8, y: 3)

                VStack(alignment: .leading, spacing: 3) {
                    Text(session.isPremium ? "Premium Active" : "Free Plan")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(session.isPremium ? Color(hex: 0x78350F) : BFColor.text1)
                    Text(session.isPremium ? planLabel : "Unlock all findings, letters & cases")
                        .font(.system(size: 13))
                        .foregroundStyle(session.isPremium ? Color(hex: 0x92400E) : BFColor.text3)
                }
                Spacer()
                Circle()
                    .fill(session.isPremium ? Color(hex: 0xFEF3C7) : BFColor.blueSoft)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: session.isPremium ? "arrow.up.right" : "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(session.isPremium ? Color(hex: 0xB45309) : BFColor.blue)
                    }
            }
            .padding(16)
            .background(session.isPremium ? Color(hex: 0xFFFBEB) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(session.isPremium ? Color(hex: 0xFCD34D).opacity(0.5) : BFColor.line.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        }
        .buttonStyle(.pressable)
    }

    // MARK: - Settings group

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(BFColor.text3)
                .tracking(0.6)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        }
    }

    // MARK: - Row helpers

    private func settingsRow(_ symbol: String, _ title: String,
                              tint: Color, value: String? = nil,
                              chevron: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(tint == BFColor.red && !chevron ? BFColor.red : BFColor.text1)
                Spacer()
                if let value {
                    Text(value)
                        .font(.system(size: 14))
                        .foregroundStyle(BFColor.text3)
                }
                if chevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(BFColor.text4)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func settingsToggleRow(_ symbol: String, _ title: String,
                                    tint: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(tint.opacity(0.12))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tint)
                }
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(BFColor.text1)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(BFColor.teal)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    private var appearanceRow: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(BFColor.navy2.opacity(0.12))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(BFColor.navy2)
                }
            Text("Appearance")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(BFColor.text1)
            Spacer()
            Picker("Appearance", selection: $settings.selectedTheme) {
                ForEach(AppTheme.allCases) { Text($0.rawValue).tag($0.rawValue) }
            }
            .labelsHidden()
            .tint(BFColor.text2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    // MARK: - Background circles

    private var circleDecorations: some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0x2E7DF6).opacity(0.05))
                .frame(width: 260, height: 260)
                .offset(x: 150, y: -120)
            Circle()
                .fill(Color(hex: 0x00BFA5).opacity(0.05))
                .frame(width: 200, height: 200)
                .offset(x: -100, y: 500)
        }
    }

    // MARK: - Actions

    private var planLabel: String {
        guard session.isPremium else { return "Free" }
        if let id = session.subscription.productId {
            return id.contains("annual") ? "Premium Annual — tap to manage" : "Premium Monthly — tap to manage"
        }
        return "Premium"
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
        let sub = "BillFixer Support (v\(AppInfo.version))".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "mailto:\(AppInfo.supportEmail)?subject=\(sub)") {
            openURL(url) { ok in
                if !ok { UIPasteboard.general.string = AppInfo.supportEmail; Toast.info("Email copied", AppInfo.supportEmail) }
            }
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

// MARK: - AccountView

struct AccountView: View {
    @Environment(AppSession.self) private var session
    @State private var name = ""
    @State private var saving = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0xF0F4FF), Color(hex: 0xF7F9FD)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Profile header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color(hex: 0x0B2B5C), Color(hex: 0x2E7DF6)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 80, height: 80)
                                .shadow(color: Color(hex: 0x2E7DF6).opacity(0.3), radius: 16, y: 6)
                            Text(session.user?.initial ?? "U")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        Text(session.user?.displayName ?? "Your Account")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(BFColor.text1)
                        if let email = session.user?.email {
                            Text(email)
                                .font(.system(size: 14))
                                .foregroundStyle(BFColor.text3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 4)

                    // Edit name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DISPLAY NAME")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(BFColor.text3)
                            .tracking(0.8)
                            .padding(.leading, 4)

                        HStack(spacing: 12) {
                            Circle()
                                .fill(BFColor.blueSoft)
                                .frame(width: 36, height: 36)
                                .overlay {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(BFColor.blue)
                                }
                            TextField("Display name", text: $name)
                                .textContentType(.name)
                                .font(.system(size: 15))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                    }

                    // Save button
                    Button {
                        Task {
                            saving = true
                            defer { saving = false }
                            do {
                                try await session.updateName(name.trimmed)
                                Toast.success("Profile updated")
                            } catch { Toast.error(error) }
                        }
                    } label: {
                        Group {
                            if saving { ProgressView().tint(.white) }
                            else { Text("Save Changes").font(.system(size: 16, weight: .bold, design: .rounded)) }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(LinearGradient(colors: [Color(hex: 0x2E7DF6), BFColor.navy],
                                                   startPoint: .leading, endPoint: .trailing))
                        .clipShape(Capsule())
                        .shadow(color: Color(hex: 0x2E7DF6).opacity(0.3), radius: 12, y: 6)
                    }
                    .buttonStyle(.plain)
                    .disabled(name.trimmed.isEmpty || name.trimmed == session.user?.displayName || saving)

                    // Privacy note
                    HStack(spacing: 10) {
                        Circle()
                            .fill(BFColor.greenSoft)
                            .frame(width: 36, height: 36)
                            .overlay {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(BFColor.green)
                            }
                        Text("Bill images are read on your iPhone and never uploaded. We store only the details you confirm.")
                            .font(.system(size: 13))
                            .foregroundStyle(BFColor.text3)
                            .lineSpacing(3)
                    }
                    .padding(14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .onAppear { name = session.user?.displayName ?? "" }
    }
}
