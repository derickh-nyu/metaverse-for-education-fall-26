import ARKit
import RealityKit
import SwiftUI

/// Object tracking, following Apple's "Implementing object tracking in your app"
/// and WWDC26 "Explore enhancements to visionOS object tracking".
///
/// Pipeline:  USDZ model ──Create ML──▶ .referenceobject ──ARKit──▶ ObjectAnchor ──▶ RealityKit content
///
/// `machineRoot` follows the real object's pose. Anything you add as a child of it
/// (labels, arrows, the model overlay) moves with the physical object.
///
/// IMPORTANT (from the tutorial): object tracking only works inside an ImmersiveSpace.
/// In a regular window it fails silently, so `run()` is called from ImmersiveView.
@MainActor
@Observable
final class ObjectTracker {
    enum Status: Equatable {
        case idle
        case loading
        case requestingPermission
        case searching
        case tracking
        case lost
        case simulatorFallback
        case failed(String)

        var message: String {
            switch self {
            case .idle: "Tap Start to begin tracking."
            case .loading: "Loading reference object…"
            case .requestingPermission: "Requesting world-sensing permission…"
            case .searching: "Look at the machine to find it…"
            case .tracking: "Machine found. Labels attached."
            case .lost: "Lost sight of the machine. Look back at it."
            case .simulatorFallback: "Object tracking isn't available here (Simulator). Showing the gray-box stand-in."
            case .failed(let reason): reason
            }
        }

        var icon: String {
            switch self {
            case .tracking: "checkmark.circle.fill"
            case .searching, .loading, .requestingPermission: "viewfinder"
            case .lost: "eye.slash"
            case .failed: "xmark.octagon.fill"
            case .idle, .simulatorFallback: "info.circle"
            }
        }
    }

    /// Name of the Create ML output in the app bundle (without extension).
    let referenceObjectName = "MyObjectTracker 1"

    var status: Status = .idle

    /// Show the USDZ packaged inside the reference object as a translucent overlay,
    /// so you can judge tracking quality (tutorial: "Export the reference object file").
    var showModelOverlay = true {
        didSet { overlay?.isEnabled = showModelOverlay }
    }

    /// Bounding box of the tracked object, in the anchor's own space. Used to lay out labels.
    private(set) var objectCenter: SIMD3<Float> = .zero
    private(set) var objectExtent: SIMD3<Float> = [0.5, 0.4, 0.4]

    /// Root entity that follows the physical object.
    let machineRoot = Entity()

    private var session = ARKitSession()
    private var overlay: Entity?

    init() {
        machineRoot.name = "TrackedMachine"
        machineRoot.isEnabled = false
    }

    // MARK: - Lifecycle

    func run() async {
        // Simulator / unsupported device: keep the week 1–2 gray box so the demo still works.
        guard ObjectTrackingProvider.isSupported else {
            showGrayBoxFallback()
            return
        }

        // 1. Load the .referenceobject trained in Create ML.
        setStatus(.loading)
        guard let url = Bundle.main.url(forResource: referenceObjectName, withExtension: "referenceobject") else {
            setStatus(.failed("Can't find \(referenceObjectName).referenceobject in the app bundle. Check its Target Membership."))
            return
        }
        let referenceObject: ReferenceObject
        do {
            referenceObject = try await loadReferenceObject(from: url)
        } catch {
            setStatus(.failed("Couldn't load the reference object: \(error.localizedDescription)"))
            return
        }
        await addModelOverlay(for: referenceObject)

        // 2. Ask for world-sensing permission (needs NSWorldSensingUsageDescription).
        setStatus(.requestingPermission)
        let authorization = await session.requestAuthorization(for: ObjectTrackingProvider.requiredAuthorizations)
        guard authorization.values.allSatisfy({ $0 == .allowed }) else {
            setStatus(.failed("World-sensing permission was denied. Turn it on in Settings › Privacy & Security."))
            return
        }

        // 3. Run an ObjectTrackingProvider in an ARKitSession.
        let provider = ObjectTrackingProvider(referenceObjects: [referenceObject])
        do {
            try await session.run([provider])
        } catch {
            setStatus(.failed("Couldn't start object tracking: \(error.localizedDescription)"))
            return
        }
        setStatus(.searching)

        // 4. Consume anchor updates and move the content with the object.
        for await update in provider.anchorUpdates {
            let anchor = update.anchor
            switch update.event {
            case .added:
                objectCenter = anchor.boundingBox.center
                objectExtent = anchor.boundingBox.extent
                follow(anchor)
            case .updated:
                follow(anchor)
            case .removed:
                machineRoot.isEnabled = false
                setStatus(.searching)
            }
        }
    }

    func stop() {
        session.stop()
        session = ARKitSession()   // a stopped session can't be reused; get a fresh one for next time
        machineRoot.isEnabled = false
        setStatus(.idle)
    }

    // MARK: - Helpers

    private func loadReferenceObject(from url: URL) async throws -> ReferenceObject {
        // High frame rate tracking (WWDC26) needs the visionOS 27 SDK / Xcode 27.
        // Once you have it, you can replace this line with:
        //   var configuration = ReferenceObject.Configuration()
        //   configuration.highFrameRateTrackingEnabled = true
        //   return try await ReferenceObject(from: url, configuration: configuration)
        return try await ReferenceObject(from: url)
    }

    private func follow(_ anchor: ObjectAnchor) {
        machineRoot.transform = Transform(matrix: anchor.originFromAnchorTransform)
        // Hide content while the object isn't visible, like `isEnabled = anchor.isTracked` in the WWDC sample.
        machineRoot.isEnabled = anchor.isTracked
        setStatus(anchor.isTracked ? .tracking : .lost)
    }

    private func addModelOverlay(for referenceObject: ReferenceObject) async {
        // usdzFile is nil if "Strip USDZ Files from Reference Object" is turned on in Build Settings.
        guard overlay == nil,
              let usdz = referenceObject.usdzFile,
              let model = try? await Entity(contentsOf: usdz) else { return }
        model.name = "ModelOverlay"
        model.components.set(OpacityComponent(opacity: 0.35))
        model.isEnabled = showModelOverlay
        machineRoot.addChild(model)
        overlay = model
    }

    private func showGrayBoxFallback() {
        if machineRoot.findEntity(named: "GrayBox") == nil {
            let box = ModelEntity(
                mesh: .generateBox(width: 0.5, height: 0.4, depth: 0.4, cornerRadius: 0.02),
                materials: [SimpleMaterial(color: .gray, isMetallic: true)]
            )
            box.name = "GrayBox"
            machineRoot.addChild(box)
        }
        machineRoot.transform = Transform(translation: [0, 1.0, -1.5])
        objectCenter = .zero
        objectExtent = [0.5, 0.4, 0.4]
        machineRoot.isEnabled = true
        setStatus(.simulatorFallback)
    }

    /// Only write when the value changes, so SwiftUI doesn't redraw on every tracking frame.
    private func setStatus(_ newStatus: Status) {
        if status != newStatus { status = newStatus }
    }
}
