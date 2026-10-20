import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        VStack(spacing: 24) {
            Text("Machine Guide")
                .font(.extraLargeTitle)

            Text("Places labels, arrows and warnings around a machine.")
                .font(.title3)
                .foregroundStyle(.secondary)

            Button(appModel.immersiveSpaceState == .open ? "Hide Labels" : "Show Labels") {
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
