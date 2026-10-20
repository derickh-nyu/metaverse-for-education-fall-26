import SwiftUI
import RealityKit

/// Week 1–2: a stand-in "machine" (gray box) at a fixed spot in the room,
/// with labels and an arrow attached to it.
///
/// Coordinates are in meters. Origin = the user's feet when the space opens.
///   +x = right, +y = up, -z = forward.
///
/// Every label is a CHILD of `machine`, so its position is relative to the machine.
/// In Week 3 you swap the gray box for the real tracked object, and all the labels follow it.
struct ImmersiveView: View {
    var body: some View {
        RealityView { content, attachments in
            // 1. The stand-in machine: 50 cm wide box, 1.5 m in front of you, at table height.
            let machine = ModelEntity(
                mesh: .generateBox(width: 0.5, height: 0.4, depth: 0.4, cornerRadius: 0.02),
                materials: [SimpleMaterial(color: .gray, isMetallic: true)]
            )
            machine.position = [0, 1.0, -1.5]
            content.add(machine)

            // 2. Warning label floating above the machine.
            if let warning = attachments.entity(for: "warning") {
                warning.position = [0, 0.32, 0]
                machine.addChild(warning)
            }

            // 3. Arrow on the right side, pointing at the machine.
            //    A cone points up (+y) by default; rotate 90° around z so it points left (-x).
            let arrow = ModelEntity(
                mesh: .generateCone(height: 0.12, radius: 0.04),
                materials: [SimpleMaterial(color: .systemYellow, isMetallic: false)]
            )
            arrow.position = [0.38, 0, 0]
            arrow.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
            machine.addChild(arrow)

            // 4. Part label next to the arrow.
            if let partLabel = attachments.entity(for: "powerSwitch") {
                partLabel.position = [0.6, 0, 0]
                machine.addChild(partLabel)
            }
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
