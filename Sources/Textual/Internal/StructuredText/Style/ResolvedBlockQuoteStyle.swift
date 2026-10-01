import SwiftUI

extension StructuredText {
  // NB: Enables environment resolution in `BlockQuoteStyle`
  struct ResolvedBlockQuoteStyle<S: BlockQuoteStyle>: View {
    private let style: S
    private let configuration: S.Configuration

    init(_ style: S, configuration: S.Configuration) {
      self.style = style
      self.configuration = configuration
    }

    var body: some View {
      Group(subviews: configuration.label) { blocks in
        style.makeBody(configuration: .init(
          label: .init(ForEach(blocks) { $0 }),
          indentationLevel: configuration.indentationLevel
        ))
        .modifier(BlockSpacingModifier(spacing: blocks.blockSpacing))
      }
    }
  }
}

extension StructuredText.BlockQuoteStyle {
  @MainActor func resolve(configuration: Configuration) -> some View {
    StructuredText.ResolvedBlockQuoteStyle(self, configuration: configuration)
  }
}
