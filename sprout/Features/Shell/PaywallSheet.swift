import SwiftUI

/// PaywallSheet is removed from V1 public routes.
/// Retained as a dead stub so that any lingering references compile.
/// Delete this file when the pro features roadmap is activated.
@available(*, deprecated, message: "Paywall removed from V1 public paths. Remove this file when pro features ship.")
struct PaywallSheet: View {
    let featureTitle: String

    var body: some View {
        EmptyView()
    }
}
