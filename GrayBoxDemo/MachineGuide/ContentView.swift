import SwiftUI

/// Control window. Object tracking itself runs in the ImmersiveSpace (see ImmersiveView),
/// because ARKit object tracking does not work inside a regular window.
struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        @Bindable var tracker = appModel.tracker

        VStack(spacing: 24) {
            Text("Machine Guide")
                .font(.extraLargeTitle)

            Text("Look at the machine. Labels, arrows and warnings snap onto it.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Label(tracker.status.message, systemImage: tracker.status.icon)
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.thinMaterial, in: Capsule())

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Show 3D model overlay", isOn: $tracker.showModelOverlay)
            }
            .frame(maxWidth: 520)

            Button(appModel.immersiveSpaceState == .open ? "Stop Tracking" : "Start Tracking") {
                Task { await toggleImmersiveSpace() }
            }
            .font(.title2)
            .disabled(appModel.immersiveSpaceState == .inTransition)
        }
        .padding(48)
    }

    private func toggleImmersiveSpace() async {
        switch appModel.immersiveSpaceState {
        case .open:
            appModel.immersiveSpaceState = .inTransition
            await dismissImmersiveSpace()
        case .closed:
            appModel.immersiveSpaceState = .inTransition
            switch await openImmersiveSpace(id: appModel.immersiveSpaceID) {
            case .opened:
                break
            default:
                appModel.immersiveSpaceState = .closed
            }
        case .inTransition:
            break
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
