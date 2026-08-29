import SwiftUI

// MARK: - Overview
//
// `AttachmentTapInteraction` adds opt-in tap handling for rendered attachments.
//
// `AttachmentOverlay` draws attachments as non-interactive `Canvas` symbols. This modifier reads
// the same resolved `Text.Layout` geometry and installs clear hit-shapes over each attachment
// run's typographic bounds. Tapping a hit-shape invokes the environment's `attachmentTapAction`.
//
// The hit-shapes cover attachment run rects only, so taps elsewhere fall through to link and
// selection handling. When no action is set in the environment, no hit-shapes are installed and
// behavior is unchanged.
//
// When text selection is enabled, the platform interaction view (`UITextInteractionView` /
// `NSTextInteractionView`) wins hit-testing over these hit-shapes; it resolves attachment taps
// itself via `TextSelectionModel.attachment(for:)` and invokes the same environment action.

extension EnvironmentValues {
  @Entry var attachmentTapAction: (@MainActor (AnyAttachment) -> Void)? = nil
}

struct AttachmentTapInteraction: ViewModifier {
  @Environment(\.attachmentTapAction) private var attachmentTapAction

  func body(content: Content) -> some View {
    content
      .overlayPreferenceValue(Text.LayoutKey.self) { value in
        if let attachmentTapAction, let anchoredLayout = value.first {
          GeometryReader { geometry in
            let origin = geometry[anchoredLayout.origin]
            ForEach(tapTargets(in: anchoredLayout.layout)) { target in
              Color.clear
                .frame(width: target.rect.width, height: target.rect.height)
                .contentShape(.rect)
                .onTapGesture {
                  attachmentTapAction(target.attachment)
                }
                .offset(
                  x: origin.x + target.rect.minX,
                  y: origin.y + target.rect.minY
                )
            }
          }
        }
      }
  }

  private struct TapTarget: Identifiable {
    let id: Int
    let rect: CGRect
    let attachment: AnyAttachment
  }

  private func tapTargets(in layout: Text.Layout) -> [TapTarget] {
    var targets: [TapTarget] = []
    for line in layout {
      for run in line {
        guard let attachment = run.attachment else { continue }
        targets.append(
          TapTarget(
            id: targets.count,
            rect: run.typographicBounds.rect,
            attachment: attachment
          )
        )
      }
    }
    return targets
  }
}
