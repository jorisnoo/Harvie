import SwiftUI

struct RefreshWarningView: View {
    let error: String
    let lastRefreshed: Date?
    let retry: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Refresh failed: \(error)", systemImage: "exclamationmark.triangle")
                if let lastRefreshed {
                    Text("Showing saved data from \(lastRefreshed.formatted(date: .abbreviated, time: .shortened)).")
                } else {
                    Text("Showing saved data. Balances and statuses may be out of date.")
                }
            }
            Spacer(minLength: 4)
            Button(Strings.Common.retry, action: retry)
        }
        .font(.caption)
        .padding(10)
        .background(.orange.opacity(0.1))
    }
}
