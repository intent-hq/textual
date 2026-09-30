import Foundation
import Testing

@testable import Textual

#if canImport(Darwin)
  import Darwin
#endif

struct CodeTokenizerTests {
  @Test(.enabled(if: CodeTokenizer.isSupported))
  @available(watchOS, unavailable)
  func tokenize() async {
    // given
    let tokenizer = CodeTokenizer()

    // when
    let tokens: [CodeToken] =
      if let tokenizer {
        await tokenizer.tokenize(
          code: "let greeting = \"Hello, world!\"",
          language: "swift"
        )
      } else {
        []
      }

    // then
    #expect(tokenizer != nil)
    #expect(
      tokens == [
        .init(content: "let", type: .keyword),
        .init(content: " greeting ", type: .plain),
        .init(content: "=", type: .operator),
        .init(content: " ", type: .plain),
        .init(content: "\"Hello, world!\"", type: .string),
      ]
    )
  }

  @Test(.enabled(if: CodeTokenizer.isSupported))
  @available(watchOS, unavailable)
  func tokenizeUnsupportedLanguage() async {
    // given
    let tokenizer = CodeTokenizer()

    // when
    let tokens: [CodeToken] =
      if let tokenizer {
        await tokenizer.tokenize(
          code: "let greeting = \"Hello, world!\"",
          language: "unsupported"
        )
      } else {
        []
      }

    // then
    #expect(tokenizer != nil)
    #expect(
      tokens == [
        .init(content: "let greeting = \"Hello, world!\"", type: .plain)
      ]
    )
  }

  @Test(arguments: [
    (isSimulator: true, osMajorVersion: 26, expected: false),
    (isSimulator: false, osMajorVersion: 26, expected: true),
    (isSimulator: true, osMajorVersion: 18, expected: true),
    (isSimulator: true, osMajorVersion: 27, expected: true),
    (isSimulator: false, osMajorVersion: 15, expected: true),
  ])
  func javaScriptCoreSafety(isSimulator: Bool, osMajorVersion: Int, expected: Bool) {
    #expect(
      CodeTokenizer.isJavaScriptCoreSafe(isSimulator: isSimulator, osMajorVersion: osMajorVersion)
        == expected
    )
  }

  // Regression test for https://github.com/intent-hq/ios/issues/427: the iOS 26 simulator's
  // JavaScriptCore truncates heap pointers to 36 bits, so evaluating Prism crashes once the
  // JavaScriptCore heap lands at or above 64 GiB. Filling the low address space first forces
  // that placement, making the crash deterministic on an affected runtime.
  @Test
  @available(watchOS, unavailable)
  func tokenizerSurvivesJavaScriptCoreHeapAbove64GiB() async {
    // given
    let reservations = LowAddressSpaceReservations()
    defer { reservations.release() }

    // when
    let tokenizer = CodeTokenizer()
    let tokens =
      if let tokenizer {
        await tokenizer.tokenize(code: "let greeting = \"Hello, world!\"", language: "swift")
      } else {
        [CodeToken]()
      }

    // then
    if CodeTokenizer.isSupported {
      #expect(tokenizer != nil)
      #expect(tokens.first == .init(content: "let", type: .keyword))
    } else {
      #expect(tokenizer == nil)
    }
  }
}

/// Maps 16 MiB `PROT_NONE` regions until the kernel starts returning addresses at or above
/// 64 GiB (2^36), so allocations made afterwards land above that boundary.
private final class LowAddressSpaceReservations {
  private var regions: [UnsafeMutableRawPointer] = []
  private let regionSize = 16 << 20

  init() {
    #if canImport(Darwin)
      for _ in 0..<4096 {
        guard
          let region = mmap(nil, regionSize, PROT_NONE, MAP_PRIVATE | MAP_ANON, -1, 0),
          region != MAP_FAILED
        else {
          return
        }
        regions.append(region)
        if UInt(bitPattern: region) >= 1 << 36 {
          return
        }
      }
    #endif
  }

  func release() {
    #if canImport(Darwin)
      for region in regions {
        munmap(region, regionSize)
      }
    #endif
    regions.removeAll()
  }
}
