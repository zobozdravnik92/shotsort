import SwiftUI

struct NoticeBanner: View {
    let systemImage: String
    let text: String

    var body: some View {
        Label {
            Text(text).font(.subheadline)
        } icon: {
            Image(systemName: systemImage).foregroundStyle(.tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    NoticeBanner(systemImage: "info.circle", text: "Apple Intelligence is still getting ready. The app uses simple keyword rules for now.")
        .padding()
        .background(Color(.systemGroupedBackground))
}
