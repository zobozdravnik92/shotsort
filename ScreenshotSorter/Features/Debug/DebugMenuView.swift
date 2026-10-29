#if DEBUG
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Debug builds only: reprocess, wipe, and import sample images for the Simulator.
struct DebugMenuView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @Query private var items: [Item]
    @Query private var screenshots: [Screenshot]
    @State private var isImporting = false
    @State private var confirmWipe = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Sorting") {
                    LabeledContent("Provider", value: services.providerID)
                    if let notice = services.providerNotice {
                        Text(notice).font(.footnote).foregroundStyle(.secondary)
                    }
                    if services.progress.isRunning {
                        LabeledContent("Processing", value: "\(services.progress.done) of \(services.progress.total)")
                    }
                }

                Section("Store") {
                    LabeledContent("Items", value: "\(items.count)")
                    LabeledContent("Screenshots", value: "\(screenshots.count)")
                }

                Section {
                    Button("Test new-screenshot alert", systemImage: "bell.badge") {
                        Task {
                            do {
                                try MockScreenshots.writeFresh()
                                message = "Added one new screenshot. Running the background check…"
                                await services.backgroundCheck()
                                message = "Background check done. A notification should appear; tap it to open triage."
                            } catch {
                                message = "Couldn't add a screenshot: \(error.localizedDescription)"
                            }
                        }
                    }
                    Button("Simulate notification tap", systemImage: "hand.tap") {
                        // Same call the notification handler makes.
                        NotificationRouter.shared.requestTriage()
                    }
                    Button("Add mock screenshots", systemImage: "photo.stack") {
                        do {
                            let added = try MockScreenshots.write()
                            message = added == 0
                                ? "Mock screenshots are already added."
                                : "Added \(added) mock screenshot\(added == 1 ? "" : "s")."
                            services.startIngest()
                        } catch {
                            message = "Couldn't add mocks: \(error.localizedDescription)"
                        }
                    }
                    Button("Import sample images from Files", systemImage: "square.and.arrow.down") {
                        isImporting = true
                    }
                    Button("Reprocess all", systemImage: "arrow.clockwise") {
                        Task {
                            await services.reprocessAll()
                            message = "Reprocessing started."
                        }
                    }
                    Button("Wipe store", systemImage: "trash", role: .destructive) {
                        confirmWipe = true
                    }
                } footer: {
                    Text("Mocks cover every category, plus one exact duplicate. Mocks and imported samples go through the same pipeline. Deleting one only removes the app's copy.")
                }

                if let message {
                    Section { Text(message) }
                }
            }
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls):
                    do {
                        let added = try SampleSource.importFiles(urls)
                        message = "Imported \(added) image\(added == 1 ? "" : "s")."
                        services.startIngest()
                    } catch {
                        message = "Import failed: \(error.localizedDescription)"
                    }
                case .failure(let error):
                    message = "Import failed: \(error.localizedDescription)"
                }
            }
            .confirmationDialog("Wipe all items, screenshots and stats?", isPresented: $confirmWipe, titleVisibility: .visible) {
                Button("Wipe store", role: .destructive) {
                    Task {
                        await services.wipeStore()
                        message = "Store wiped. Screenshots will be processed again on next launch."
                    }
                }
            }
        }
    }
}

#Preview {
    DebugMenuView()
        .environment(AppServices.preview)
        .modelContainer(AppServices.preview.container)
}
#endif
