import SwiftUI
import RealityKit
import ARKit

struct ContentView: View {
    @State private var session = ARKitSession()
    
    // Store root entity and spawned child entities keyed by anchor ID
    @State private var rootEntity = Entity()
    @State private var trackedEntities: [UUID: Entity] = [:]

    var body: some View {
        RealityView { content in
            content.add(rootEntity)
        }
        .task {
            await startObjectTracking()
        }
    }

    private func startObjectTracking() async {
        guard let url = Bundle.main.url(forResource: "MyObjectTracker 1", withExtension: "referenceobject") else {
            print("Error: Could not locate 'MyObjectTracker 1.referenceobject' in the main bundle.")
            return
        }

        do {
            let referenceObject = try await ReferenceObject(from: url)
            let provider = ObjectTrackingProvider(referenceObjects: [referenceObject])

            guard ObjectTrackingProvider.isSupported else {
                print("ObjectTrackingProvider is not supported on this platform/simulator.")
                return
            }

            try await session.run([provider])
            print("Tracking session started for: \(referenceObject.name)")

            for await update in provider.anchorUpdates {
                let anchor = update.anchor

                switch update.event {
                case .added:
                    print("Found anchor at: \(anchor.originFromAnchorTransform)")
                    
                    // Create an anchor parent entity positioned at the detected physical object
                    let anchorEntity = Entity()
                    anchorEntity.transform = Transform(matrix: anchor.originFromAnchorTransform)

                    // Load your 3D model (replace "YourModelName" with your .usdz file name without extension)
                    if let modelEntity = try? await Entity(named: "YourModelName") {
                        // --- SET SCALE ---
                        // [1, 1, 1] is native size. Use [0.1, 0.1, 0.1] if the model is too large.
                        modelEntity.scale = SIMD3<Float>(1.0, 1.0, 1.0)

                        // --- SET POSITION ---
                        // Position is relative to the anchor origin (in meters: [X, Y, Z]).
                        // [0, 0.05, 0] sits 5cm directly on top of the detected object center.
                        modelEntity.position = SIMD3<Float>(0.0, 0.05, 0.0)

                        anchorEntity.addChild(modelEntity)
                    } else {
                        // Fallback: visual debug cube if the 3D model asset fails to load
                        let debugBox = ModelEntity(
                            mesh: .generateBox(size: 0.05),
                            materials: [SimpleMaterial(color: .systemGreen, isMetallic: false)]
                        )
                        debugBox.position = SIMD3<Float>(0.0, 0.025, 0.0)
                        anchorEntity.addChild(debugBox)
                    }

                    rootEntity.addChild(anchorEntity)
                    trackedEntities[anchor.id] = anchorEntity

                case .updated:
                    // Keep the entity anchored to the object as the user moves
                    if let entity = trackedEntities[anchor.id] {
                        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)
                    }

                case .removed:
                    print("Lost anchor tracking.")
                    if let entity = trackedEntities.removeValue(forKey: anchor.id) {
                        entity.removeFromParent()
                    }
                }
            }
        } catch {
            print("Failed to load reference object or start session: \(error)")
        }
    }
}
