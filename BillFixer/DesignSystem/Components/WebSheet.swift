import SafariServices
import SwiftUI

/// In-app browser for support / terms / privacy — stays inside Bill Fixer (no jump to Safari).
struct SafariSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredControlTintColor = UIColor(hex: 0x2E7DF6)
        vc.dismissButtonStyle = .close
        return vc
    }

    func updateUIViewController(_: SFSafariViewController, context _: Context) {}
}

struct WebLink: Identifiable, Hashable {
    let url: URL
    var id: String { url.absoluteString }

    static let support = WebLink(url: URL(string: AppInfo.supportURLString)!)
    static let terms = WebLink(url: URL(string: AppInfo.termsURLString)!)
    static let privacy = WebLink(url: URL(string: AppInfo.privacyURLString)!)
    static func external(_ string: String?) -> WebLink? {
        guard let string, let url = URL(string: string), ["http", "https"].contains(url.scheme?.lowercased()) else { return nil }
        return WebLink(url: url)
    }
}

extension View {
    /// `.webSheet($link)` — presents any `WebLink` in an in-app Safari sheet.
    func webSheet(_ link: Binding<WebLink?>) -> some View {
        sheet(item: link) { SafariSheet(url: $0.url).ignoresSafeArea() }
    }
}
