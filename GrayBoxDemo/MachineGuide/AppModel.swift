import SwiftUI

/// Shared app state.
@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"

    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed

    /// ARKit object tracking for the real machine.
    let tracker = ObjectTracker()
}
