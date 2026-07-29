#if canImport(WidgetKit)
import WidgetKit
import SwiftUI

@available(visionOS 26.0, *)
@main
struct WordCardWidgetBundle: WidgetBundle {
    var body: some Widget {
        WordCardWidget()
    }
}
#endif
