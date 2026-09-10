import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: SettingsViewModel?
    @State private var shareErrorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                cloudSharingSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if viewModel == nil {
                    viewModel = SettingsViewModel(modelContext: modelContext)
                }
            }
            .alert(
                "Can't Share Budget",
                isPresented: Binding(
                    get: { shareErrorMessage != nil },
                    set: { isPresented in if !isPresented { shareErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { shareErrorMessage = nil }
            } message: {
                Text(shareErrorMessage ?? "")
            }
        }
    }

    private var profileSection: some View {
        Section("Profile") {
            TextField(
                "Display Name",
                text: Binding(
                    get: { viewModel?.displayName ?? "" },
                    set: { viewModel?.saveDisplayName($0) }
                )
            )
        }
    }

    private var cloudSharingSection: some View {
        Section {
            Button("Share Budget") {
                presentShare()
            }
        } header: {
            Text("Cloud Sharing")
        } footer: {
            Text("Invite household members to collaborate on every account, envelope, and transaction.")
        }
    }

    private func presentShare() {
        guard let rootViewController = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
            .first
        else { return }

        CloudSharingManager.shared.presentShare(
            modelContext: modelContext,
            from: rootViewController
        ) { result in
            if case let .failure(error) = result {
                shareErrorMessage = error.localizedDescription
            }
        }
    }
}
