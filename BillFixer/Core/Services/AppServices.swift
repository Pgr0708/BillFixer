import SwiftUI

/// Dependency container (AGENTS.md rule 6). Swap any member for a mock in previews/tests.
struct AppServices {
    var cases: CaseServicing = CaseService()
    var analysis: AnalysisServicing = AnalysisService()
    var content: ContentServicing = ContentService()
    var reference: ReferenceServicing = ReferenceService()
}

extension EnvironmentValues {
    @Entry var services = AppServices()
}
