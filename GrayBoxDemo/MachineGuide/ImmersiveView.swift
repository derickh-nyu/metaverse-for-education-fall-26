import SwiftUI
import RealityKit

/// Week 3: labels follow the REAL tracked object.
///
/// `appModel.tracker.machineRoot` is moved by ARKit object tracking to the physical
/// machine's pose. Every label is a child of it, so positions below are relative to the
/// object (meters, +x right, +y up, -z forward in the object's own space).
///
/// On the Simulator (no object tracking) the tracker falls back to the week 1–2 gray box.
struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        RealityView { content, attachments in
            let machine = appModel.tracker.machineRoot
            content.add(machine)

            // Rebuild the labels each time the space opens, so reopening doesn't duplicate them.
            machine.findEntity(named: "Labels")?.removeFromParent()
            let labels = Entity()
            labels.name = "Labels"
            machine.addChild(labels)

            // Warning label above the object.
            if let warning = attachments.entity(for: "warning") {
                labels.addChild(warning)
            }

            // Arrow on the right side, pointing at the object.
            // A cone points up (+y) by default; rotate 90° around z so it points left (-x).
            let arrow = ModelEntity(
                mesh: .generateCone(height: 0.12, radius: 0.04),
                materials: [SimpleMaterial(color: .systemYellow, isMetallic: false)]
            )
            arrow.name = "Arrow"
            arrow.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
            labels.addChild(arrow)

            // Part label next to the arrow.
            if let partLabel = attachments.entity(for: "powerSwitch") {
                labels.addChild(partLabel)
            }

            layoutLabels(attachments: attachments)
        } update: { _, attachments in
            // Re-runs when the tracker reports the real object's bounding box.
            layoutLabels(attachments: attachments)
        } attachments: {
            Attachment(id: "warning") {
                InfoLabel(icon: "exclamationmark.triangle.fill",
                          text: "Hot Surface: Do Not Touch",
                          color: .orange)
            }
            Attachment(id: "powerSwitch") {
                InfoLabel(icon: "power", text: "Power Switch", color: .white)
            }
        }
        .task {
            await appModel.tracker.run()
        }
        .onDisappear {
            appModel.tracker.stop()
        }
    }

    /// Places labels around the object's bounding box, so they fit whatever object you trained.
    private func layoutLabels(attachments: RealityViewAttachments) {
        let center = appModel.tracker.objectCenter
        let extent = appModel.tracker.objectExtent
        let machine = appModel.tracker.machineRoot

        attachments.entity(for: "warning")?.position = center + [0, extent.y / 2 + 0.12, 0]
        machine.findEntity(named: "Arrow")?.position = center + [extent.x / 2 + 0.08, 0, 0]
        attachments.entity(for: "powerSwitch")?.position = center + [extent.x / 2 + 0.30, 0, 0]
    }
}

/// A floating glass label with an icon.
struct InfoLabel: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        Label(text, systemImage: icon)
            .font(.title)
            .foregroundStyle(color)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .glassBackgroundEffect()
    }
}
