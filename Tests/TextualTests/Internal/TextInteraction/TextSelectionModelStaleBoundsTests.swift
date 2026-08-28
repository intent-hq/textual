#if TEXTUAL_ENABLE_TEXT_SELECTION && !targetEnvironment(macCatalyst)
  import Foundation
  import SwiftUI
  import Testing

  @testable import Textual

  // Regression tests for stale selection bounds: UIKit/AppKit can hold on to
  // `TextPosition` / `TextRange` values created against a previous layout collection and hand
  // them back after the collection has been rebuilt with fewer layouts, lines, runs, or slices.
  // Every query must fail gracefully instead of trapping on out-of-bounds indexing.
  struct TextSelectionModelStaleBoundsTests {
    // Positions whose index paths do not exist in the `two-paragraphs-bidi` fixture
    // (2 layouts of 2 lines each; layout 0 line 0 has 5 runs of at most 18 slices).
    private static let stalePositions = [
      TextPosition(indexPath: .init(runSlice: 0, run: 0, line: 0, layout: 5), affinity: .downstream),
      TextPosition(indexPath: .init(runSlice: 0, run: 0, line: 9, layout: 0), affinity: .downstream),
      TextPosition(indexPath: .init(runSlice: 0, run: 9, line: 0, layout: 0), affinity: .upstream),
      TextPosition(indexPath: .init(runSlice: 99, run: 0, line: 0, layout: 0), affinity: .upstream),
    ]

    @Test(arguments: stalePositions)
    func caretRectWithStalePosition(_ position: TextPosition) throws {
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")

      #expect(model.caretRect(for: position) == .zero)
    }

    @Test(arguments: stalePositions)
    func selectionRectsWithStaleRange(_ position: TextPosition) throws {
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")
      let range = TextRange(from: model.startPosition, to: position)

      #expect(model.selectionRects(for: range).isEmpty)
    }

    @Test(arguments: stalePositions)
    func firstRectWithStaleRange(_ position: TextPosition) throws {
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")
      let range = TextRange(from: model.startPosition, to: position)

      #expect(model.firstRect(for: range) == .null)
    }

    @Test(arguments: stalePositions)
    func attributedTextWithStaleRange(_ position: TextPosition) throws {
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")
      let range = TextRange(from: model.startPosition, to: position)

      #expect(model.attributedText(in: range).string.isEmpty)
    }

    @Test(arguments: stalePositions)
    func positionFromOffsetWithStalePosition(_ position: TextPosition) throws {
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")

      // A stale position resolves to a zero local character index; the result must simply
      // be a valid position, not a trap.
      _ = model.position(from: position, offset: 1)
    }

    @Test(arguments: stalePositions)
    func offsetWithStalePosition(_ position: TextPosition) throws {
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")

      _ = model.offset(from: model.startPosition, to: position)
      _ = model.offset(from: position, to: model.endPosition)
    }

    @Test(arguments: stalePositions)
    func positionAboveBelowWithStalePosition(_ position: TextPosition) throws {
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")

      #expect(model.positionAbove(position, anchor: position) == nil)
      #expect(model.positionBelow(position, anchor: position) == nil)
    }

    @Test(arguments: stalePositions)
    func isPositionAtBlockBoundaryWithStalePosition(_ position: TextPosition) throws {
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")

      if position.indexPath.layout >= 2 {
        #expect(model.isPositionAtBlockBoundary(position) == false)
      } else {
        _ = model.isPositionAtBlockBoundary(position)
      }
    }

    @Test
    func blockRangeWithStaleLayoutIndex() throws {
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")
      let position = TextPosition(indexPath: .init(layout: 5), affinity: .downstream)

      #expect(model.blockRange(for: position) == nil)
      #expect(model.blockStart(for: position) == nil)
      #expect(model.blockEnd(for: position) == nil)
    }

    @Test
    func queriesAgainstEmptyCollection() throws {
      // A rebuilt collection can also be empty (e.g. content cleared mid-stream) while
      // ranges from the previous non-empty collection are still in flight.
      let model = try TextSelectionModel(fixtureName: "empty")
      let stale = TextPosition(
        indexPath: .init(runSlice: 1, run: 2, line: 0, layout: 0),
        affinity: .downstream
      )
      let staleRange = TextRange(
        start: TextPosition(indexPath: .init(layout: 0), affinity: .downstream),
        end: stale
      )

      #expect(model.caretRect(for: stale) == .zero)
      #expect(model.selectionRects(for: staleRange).isEmpty)
      #expect(model.firstRect(for: staleRange) == .null)
      #expect(model.attributedText(in: staleRange).string.isEmpty)
      #expect(model.positionAbove(stale, anchor: stale) == nil)
      #expect(model.positionBelow(stale, anchor: stale) == nil)
      #expect(model.isPositionAtBlockBoundary(stale) == false)
      #expect(model.blockRange(for: stale) == nil)
      #expect(model.closestPosition(to: .zero) == nil)
      #expect(model.characterRange(at: .zero) == nil)
    }

    @Test
    func selectionSurvivesLayoutShrink() throws {
      // Simulates the crash scenario: a selection made against a two-layout collection is
      // queried after the collection is swapped for a smaller one without reconciliation.
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")
      let range = TextRange(start: model.startPosition, end: model.endPosition)
      model.selectedRange = range

      let empty = try TextSelectionModel(fixtureName: "empty")

      #expect(empty.selectionRects(for: range).isEmpty)
      #expect(empty.firstRect(for: range) == .null)
      #expect(empty.caretRect(for: range.end) == .zero)
      #expect(empty.attributedText(in: range).string.isEmpty)
    }
  }
#endif
