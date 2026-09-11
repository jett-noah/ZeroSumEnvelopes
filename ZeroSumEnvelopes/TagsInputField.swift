import SwiftUI

/// A single text field for entering comma-separated tags, with a live
/// preview of the parsed tags as small chips underneath. Used by
/// AddTransactionView and EditTransactionView.
struct TagsInputField: View {
    @Binding var tagsText: String

    private var parsedTags: [String] {
        Self.parse(tagsText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Tags (comma separated)", text: $tagsText)

            if !parsedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(parsedTags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    /// The parsed, trimmed, non-empty tag list — what should actually be
    /// saved to Transaction.tags.
    static func parse(_ text: String) -> [String] {
        text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
