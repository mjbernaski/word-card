#if !os(tvOS)
import SwiftUI

struct URLCardProposalView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sourceURL = ""
    @State private var apiKey = ""
    @State private var proposal: CardProposal?
    @State private var isGenerating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            if let proposal {
                CardEditorView(proposal: proposal)
            } else {
                Form {
                    Section("Source") {
                        TextField("https://example.com/article", text: $sourceURL)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            #endif
                            .autocorrectionDisabled()
                    }

                    Section {
                        SecureField("OpenAI API key", text: $apiKey)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                            .autocorrectionDisabled()

                        if !apiKey.isEmpty {
                            Button("Forget Saved API Key", role: .destructive) {
                                OpenAIKeychain.delete()
                                apiKey = ""
                            }
                        }
                    } header: {
                        Text("OpenAI")
                    } footer: {
                        Text("The key is sent only to OpenAI and is stored in this device's Keychain after a proposal succeeds.")
                    }

                    Section {
                        Button {
                            generateProposal()
                        } label: {
                            HStack {
                                Text("Generate Proposal")
                                Spacer()
                                if isGenerating { ProgressView() }
                            }
                        }
                        .disabled(isGenerating || sourceURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } footer: {
                        Text("Nothing is added until you review the proposal and tap Save in the card editor.")
                    }
                }
                .formStyle(.grouped)
                .navigationTitle("Propose from URL")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                .alert("Could Not Generate Proposal", isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(errorMessage ?? "An unknown error occurred.")
                }
            }
        }
        .onAppear {
            if apiKey.isEmpty { apiKey = OpenAIKeychain.load() }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 520)
        #endif
    }

    private func generateProposal() {
        let rawURL = sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: rawURL), url.host != nil else {
            errorMessage = CardProposalError.invalidURL.localizedDescription
            return
        }

        isGenerating = true
        errorMessage = nil
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                let result = try await CardProposalService().propose(from: url, apiKey: key)
                try OpenAIKeychain.save(key)
                proposal = result
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }
}
#endif
