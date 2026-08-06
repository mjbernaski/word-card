#if canImport(WidgetKit)
import WidgetKit
import SwiftUI

@available(iOS 17.0, macOS 14.0, visionOS 26.0, *)
@main
struct WordCardWidgetBundle: WidgetBundle {
    var body: some Widget {
        WordCardWidget()
    }
}
#endif
