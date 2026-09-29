import SwiftUI
import Observation

/// Profile photo, kept only on this device (Application Support, complete file protection).
/// The backend stores no images by design, so the photo never leaves the phone and is removed on sign-out.
@MainActor
@Observable
final class ProfilePhotoStore {
    static let shared = ProfilePhotoStore()
    private(set) var image: UIImage?
    private var userId: String?

    private var dir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("profile", isDirectory: true)
    }
    private func file(_ id: String) -> URL { dir.appendingPathComponent("\(id).jpg") }

    func load(for userId: String) {
        guard self.userId != userId else { return }
        self.userId = userId
        image = (try? Data(contentsOf: file(userId))).flatMap(UIImage.init(data:))
    }

    /// Center-crops to a square, scales to 512px and saves as JPEG.
    func save(_ picked: UIImage) throws {
        guard let userId else { return }
        let side = min(picked.size.width, picked.size.height)
        let crop = CGRect(x: (picked.size.width - side) / 2, y: (picked.size.height - side) / 2, width: side, height: side)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let square = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512), format: format).image { _ in
            picked.draw(in: CGRect(x: -crop.minX * 512 / side, y: -crop.minY * 512 / side,
                                   width: picked.size.width * 512 / side, height: picked.size.height * 512 / side))
        }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try square.jpegData(compressionQuality: 0.85)?.write(to: file(userId), options: [.atomic, .completeFileProtection])
        image = square
    }

    func remove() {
        if let userId { try? FileManager.default.removeItem(at: file(userId)) }
        image = nil
    }

    /// Sign-out / account deletion.
    func clearAll() {
        try? FileManager.default.removeItem(at: dir)
        image = nil
        userId = nil
    }
}

/// Circular avatar: the saved photo, or the app icon when there is none.
struct ProfileAvatar: View {
    var size: CGFloat = 44
    @Environment(AppSession.self) private var session
    @State private var photos = ProfilePhotoStore.shared

    var body: some View {
        ZStack {
            if let image = photos.image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                // No photo yet: show the app icon rather than a letter.
                Image("AppLogo").resizable().scaledToFill()
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: size > 60 ? 3 : 2))
        .shadow(color: Color(hex: 0x2E7DF6).opacity(0.3), radius: size * 0.18, y: size * 0.07)
        .onAppear { if let id = session.user?.id { photos.load(for: id) } }
        .onChange(of: session.user?.id) { _, id in if let id { photos.load(for: id) } }
        .accessibilityHidden(true)
    }
}
