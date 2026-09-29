import Foundation
import Observation

/// Who is signed in and what they're entitled to. Injected at the root; every screen reads from it.
@MainActor
@Observable
final class AppSession {
    enum Phase: Equatable { case launching, signedOut, signedIn }

    private(set) var phase: Phase = .launching
    private(set) var user: User?
    private(set) var subscription: SubscriptionStatus = .free

    let auth: AuthServicing
    let subscriptions: SubscriptionServicing
    private let store: SubscriptionManager

    convenience init() { self.init(auth: AuthService(), subscriptions: SubscriptionService(), store: .shared) }

    init(auth: AuthServicing, subscriptions: SubscriptionServicing, store: SubscriptionManager) {
        self.auth = auth
        self.subscriptions = subscriptions
        self.store = store
        NotificationCenter.default.addObserver(forName: .sessionExpired, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.phase == .signedIn else { return }
                Toast.warning("Please sign in again", "Your session expired.")
                Task { await self.clearLocal() }
            }
        }
    }

    /// Premium if the server says so, or the store just confirmed it (server catches up via webhook/validate).
    var isPremium: Bool { subscription.tier == .premium || store.entitlementActive }

    func bootstrap() async {
        guard await auth.hasSession() else { phase = .signedOut; return }
        phase = .signedIn   // optimistic: open straight into the app with cached data
        await refresh()
    }

    func refresh() async {
        do {
            let me = try await auth.me()
            user = me.user
            subscription = me.subscription
            await store.identify(userId: me.user.id)
        } catch let error as APIError {
            if case .unauthorized = error { await clearLocal() }
        } catch {}
    }

    func didSignIn(_ user: User) async {
        self.user = user
        phase = .signedIn
        Haptics.success()
        await refresh()
    }

    func updateName(_ name: String) async throws {
        user = try await auth.updateDisplayName(name)
    }

    /// After a purchase/restore: ask the server to re-verify with RevenueCat.
    func syncSubscription() async {
        do { subscription = try await subscriptions.sync() } catch {
            // Webhook will still land; the local entitlement keeps the UI unlocked meanwhile.
        }
    }

    func signOut() async {
        await auth.logout()
        await clearLocal()
        Toast.info("Signed out")
    }

    func deleteAccount() async throws {
        try await auth.deleteAccount()
        await clearLocal()
    }

    private func clearLocal() async {
        user = nil
        subscription = .free
        phase = .signedOut
        await DiskCache.shared.clear()
        ReminderScheduler.cancelAll()
        await store.reset()
    }
}
