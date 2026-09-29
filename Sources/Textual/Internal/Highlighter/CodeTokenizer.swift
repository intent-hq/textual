import Foundation
import os

#if canImport(JavaScriptCore)
  import JavaScriptCore
#endif

// MARK: - Overview
//
// CodeTokenizer wraps Prism.js via JavaScriptCore for syntax highlighting. The actor
// ensures thread-safe access to the JavaScript context.
//
// The tokenizer gracefully degrades when JavaScriptCore is unavailable, when the
// Prism bundle is missing, or when tokenization fails. In all cases, it returns
// a single plain token containing the entire code string.
//
// It is also disabled on iOS-family 26.x simulators, whose JavaScriptCore keeps only the
// low 36 bits of some compressed heap pointers (rope string fibers, for example). A
// simulator process runs in the Mac's much larger address space, so once the
// JavaScriptCore heap lands at or above 64 GiB, evaluating Prism dereferences a truncated
// pointer and crashes with EXC_BAD_ACCESS. Devices (address space below 64 GiB) and the
// 27.x simulators are unaffected. See https://github.com/intent-hq/ios/issues/427.

struct CodeToken: Hashable, Sendable {
  let content: String
  let type: StructuredText.HighlighterTheme.TokenType
}

#if canImport(JavaScriptCore)
  actor CodeTokenizer {
    private let context: JSContext
    private let logger = Logger(category: .codeTokenizer)

    static let shared = CodeTokenizer()

    init?() {
      guard Self.isSupported else {
        logger.error(
          "Syntax highlighting is disabled: this simulator's JavaScriptCore truncates heap pointers."
        )
        return nil
      }

      guard let context = JSContext() else {
        logger.error("JavascriptCore is not available.")
        return nil
      }

      guard
        let bundleURL = Bundle.textual?.url(
          forResource: "prism-bundle",
          withExtension: "js"
        ),
        let script = try? String(contentsOf: bundleURL, encoding: .utf8)
      else {
        logger.error("Prism JavaScript bundle is missing.")
        return nil
      }

      context.evaluateScript(script)
      self.context = context
    }

    func tokenize(code: String, language: String) -> [CodeToken] {
      guard
        let tokenizeCode = context.objectForKeyedSubscript("tokenizeCode"),
        let result = tokenizeCode.call(withArguments: [code, language]),
        let array = result.toArray() as? [[String: String]]
      else {
        logger.error("Tokenization failed.")
        return [CodeToken(content: code, type: .plain)]
      }

      return array.compactMap { token in
        guard
          let content = token["content"],
          let type = token["type"]
        else {
          return nil
        }
        return CodeToken(content: content, type: .init(rawValue: type))
      }
    }
  }
#else
  actor CodeTokenizer {
    private let logger = Logger(category: .codeTokenizer)

    static let shared = CodeTokenizer()

    init?() {
      logger.error("JavascriptCore is not available in this platform.")
      return nil
    }

    func tokenize(code: String, language: String) -> [CodeToken] {
      [CodeToken(content: code, type: .plain)]
    }
  }
#endif

extension CodeTokenizer {
  /// Whether JavaScriptCore can safely run Prism in the current process.
  static let isSupported: Bool = {
    #if targetEnvironment(simulator)
      let isSimulator = true
    #else
      let isSimulator = false
    #endif
    return isJavaScriptCoreSafe(
      isSimulator: isSimulator,
      osMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    )
  }()

  /// The 26.x simulators' JavaScriptCore crashes once its heap is mapped at or above 64 GiB,
  /// which the simulator's address space allows (intent-hq/ios#427).
  static func isJavaScriptCoreSafe(isSimulator: Bool, osMajorVersion: Int) -> Bool {
    !(isSimulator && osMajorVersion == 26)
  }
}

extension Logger.Textual.Category {
  fileprivate static let codeTokenizer = Self(rawValue: "codeTokenizer")
}
