import SwiftUI

@main
struct MachineGuideApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        // The floating control window
        WindowGroup {
            ContentView()
                .environment(appModel)
        }

        // The 3D space where labels appear in the room.
        // .mixed = virtual content is drawn on top of the real world.
        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .onAppear { appModel.immersiveSpaceState = .open }
                .onDisappear { appModel.immersiveSpaceState = .closed }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
