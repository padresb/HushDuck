import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var isPaused: Bool = false
    @Published var isFnHeld: Bool = false
    @Published var isDucked: Bool = false
    @Published var hasAccessibility: Bool = false
}
