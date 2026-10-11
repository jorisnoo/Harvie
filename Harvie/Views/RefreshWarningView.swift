import SwiftUI

struct RefreshWarningView: View {
    let error: String
    let lastRefreshed: Date?
    let retry: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Label(Strings.RefreshWarning.refreshFailed(error), systemImage: "exclamationmark.triangle")
                if let lastRefreshed {
                    Text(Strings.RefreshWarning.showingSavedDataFrom(lastRefreshed.formatted(date: .abbreviated, time: .shortened)))
                } else {
                    Text(Strings.RefreshWarning.showingSavedData)
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
