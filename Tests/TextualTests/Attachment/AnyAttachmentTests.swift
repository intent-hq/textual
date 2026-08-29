import SwiftUI
import Testing

@testable import Textual

struct AnyAttachmentTests {
  struct TestAttachment: Textual.Attachment {
    let name: String

    var description: String {
      name
    }

    var body: some View {
      Color.red
    }

    func sizeThatFits(
      _ proposal: ProposedViewSize,
      in environment: TextEnvironmentValues
    ) -> CGSize {
      .zero
    }
  }

  @Test func baseReturnsWrappedAttachment() {
    let attachment = TestAttachment(name: "image")
    let anyAttachment = AnyAttachment(attachment)

    #expect(anyAttachment.base as? TestAttachment == attachment)
  }

  @Test func initFlattensNestedAnyAttachment() {
    let attachment = TestAttachment(name: "image")
    let anyAttachment = AnyAttachment(AnyAttachment(attachment))

    #expect(anyAttachment.base as? TestAttachment == attachment)
  }

  @Test func existentialInitFlattensNestedAnyAttachment() {
    let makeAnyAttachment: (any Textual.Attachment) -> AnyAttachment = AnyAttachment.init
    let attachment = TestAttachment(name: "image")
    let anyAttachment = makeAnyAttachment(AnyAttachment(attachment))

    #expect(anyAttachment.base as? TestAttachment == attachment)
  }
}
