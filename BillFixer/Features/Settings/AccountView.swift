import PhotosUI
import SwiftUI

/// Account: profile photo (on-device), display name and sign-in email.
struct AccountView: View {
    @Environment(AppSession.self) private var session
    @State private var photos = ProfilePhotoStore.shared
    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var showPhotoMenu = false

    @State private var name = ""
    @State private var savingName = false

    @State private var email = ""
    @State private var currentPassword = ""
    @State private var savingEmail = false
    @State private var emailErrors: [String: String] = [:]
    @State private var shake = 0

    private var hasPassword: Bool { session.user?.hasPassword == true }
    private var emailChanged: Bool { email.trimmed.lowercased() != (session.user?.email ?? "").lowercased() && !email.trimmed.isEmpty }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header.staggeredAppear(0)
                nameSection.staggeredAppear(1)
                emailSection.staggeredAppear(2)
                privacyNote.staggeredAppear(3)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .scrollDismissesKeyboard(.interactively)
        .scenicBackground(.settings)
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in Task { await loadPhoto(item) } }
        .confirmationDialog("Profile photo", isPresented: $showPhotoMenu) {
            Button("Choose Photo") { showPhotoPicker = true }
            if photos.image != nil {
                Button("Remove Photo", role: .destructive) {
                    withAnimation(BFMotion.gentle) { photos.remove() }
                    Toast.info("Photo removed")
                }
            }
        }
        .onAppear {
            name = session.user?.displayName ?? ""
            email = session.user?.email ?? ""
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            Button {
                Haptics.tap()
                if photos.image == nil { showPhotoPicker = true } else { showPhotoMenu = true }
            } label: {
                ProfileAvatar(size: 96)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(BFGradient.blue, in: Circle())
                            .overlay(Circle().strokeBorder(BFColor.surface, lineWidth: 3))
                            .offset(x: 2, y: 2)
                    }
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(photos.image == nil ? "Add profile photo" : "Change profile photo")

            Text(session.user?.displayName ?? "Your Account")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(BFColor.text1)
            if let email = session.user?.email {
                Text(email).font(.system(size: 14)).foregroundStyle(BFColor.text3)
            }
            Text(photos.image == nil ? "Tap to add a photo" : "Tap to change or remove")
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(BFColor.blue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(BFColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }

    // MARK: - Name

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BFTextField(label: "DISPLAY NAME", text: $name, prompt: "Your name", icon: "person.fill",
                        contentType: .name, autocapitalization: .words)
            BFButton(title: "Save Name", icon: "checkmark", kind: .navy, size: .md, isLoading: savingName,
                     isDisabled: name.trimmed.isEmpty || name.trimmed == session.user?.displayName) {
                Task {
                    savingName = true
                    defer { savingName = false }
                    do { try await session.updateName(name.trimmed); Toast.success("Name updated") } catch { Toast.error(error) }
                }
            }
        }
        .padding(16)
        .background(BFColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Email

    private var emailSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BFTextField(label: "EMAIL", text: $email, prompt: "you@example.com", icon: "envelope.fill",
                        keyboard: .emailAddress, contentType: .emailAddress, error: emailErrors["email"], autocapitalization: .never)
            if hasPassword && emailChanged {
                BFTextField(label: "CURRENT PASSWORD", text: $currentPassword, prompt: "Required to change email", icon: "lock.fill",
                            contentType: .password, isSecure: true, error: emailErrors["currentPassword"], autocapitalization: .never)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            if session.user?.signInMethod == "apple" {
                Label("You sign in with Apple. This changes the email we use to contact you.", systemImage: "apple.logo")
                    .font(.system(size: 12)).foregroundStyle(BFColor.text3)
            }
            BFButton(title: "Update Email", icon: "envelope.badge", kind: .blue, size: .md, isLoading: savingEmail,
                     isDisabled: !emailChanged || (hasPassword && currentPassword.isEmpty)) {
                Task { await saveEmail() }
            }
            .shake(shake)
        }
        .padding(16)
        .background(BFColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .animation(BFMotion.gentle, value: emailChanged)
    }

    private var privacyNote: some View {
        HStack(spacing: 10) {
            IconTile(symbol: "lock.shield.fill", tint: BFColor.green, fill: BFColor.greenSoft, size: 36)
            Text("Your photo stays on this iPhone. Bill images are read on your iPhone and never uploaded.")
                .font(.system(size: 13)).foregroundStyle(BFColor.text3).lineSpacing(3)
        }
        .padding(14)
        .background(BFColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Actions

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        defer { photoItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                Toast.error("Couldn’t load that photo"); return
            }
            try withAnimation(BFMotion.gentle) { try photos.save(image) }
            Toast.success("Profile photo updated")
        } catch {
            Toast.error("Couldn’t save photo", error.localizedDescription)
        }
    }

    private func saveEmail() async {
        emailErrors = [:]
        if let e = Validation.newEmail(email) { emailErrors["email"] = e; shake += 1; Haptics.error(); return }
        savingEmail = true
        defer { savingEmail = false }
        do {
            try await session.changeEmail(email.trimmed.lowercased(), currentPassword: hasPassword ? currentPassword : nil)
            currentPassword = ""
            email = session.user?.email ?? email
            Toast.success("Email updated", "Use your new email next time you sign in.")
        } catch let error as APIError {
            switch error {
            case let .validation(_, fields) where !fields.isEmpty: for (k, v) in fields { emailErrors[k] = v.first }
            case let .conflict(_, message): emailErrors["email"] = message
            default: Toast.error(error)
            }
            shake += 1
            Haptics.error()
        } catch { Toast.error(error) }
    }
}
