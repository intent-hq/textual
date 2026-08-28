#if TEXTUAL_ENABLE_TEXT_SELECTION
  import Foundation

  // MARK: - Overview
  //
  // Selection state can outlive the layout collection it was created from: platform text input
  // systems (UIKit's `UITextInput`, AppKit's selection machinery) hold on to `TextPosition` /
  // `TextRange` values and can hand them back after SwiftUI has rebuilt the resolved layouts —
  // for example after a streaming text update shrinks the number of layouts, lines, or runs.
  // Indexing into the collection with such a stale index path traps, so every geometry or
  // positioning query validates index paths before subscripting.

  extension TextLayoutCollection {
    /// Whether `indexPath` refers to a run slice that exists in this collection.
    func contains(_ indexPath: IndexPath) -> Bool {
      guard
        indexPath.count == 4,
        layouts.indices.contains(indexPath.layout)
      else {
        return false
      }
      let layout = layouts[indexPath.layout]
      guard layout.lines.indices.contains(indexPath.line) else {
        return false
      }
      let line = layout.lines[indexPath.line]
      guard line.runs.indices.contains(indexPath.run) else {
        return false
      }
      return line.runs[indexPath.run].slices.indices.contains(indexPath.runSlice)
    }

    /// Whether `position` points at a run slice that exists in this collection.
    func contains(_ position: TextPosition) -> Bool {
      contains(position.indexPath)
    }

    /// Whether both ends of `range` point at run slices that exist in this collection.
    func contains(_ range: TextRange) -> Bool {
      contains(range.start) && contains(range.end)
    }
  }
#endif
