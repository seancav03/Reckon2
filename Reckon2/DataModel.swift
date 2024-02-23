//
//  DataModel.swift
//  Reckon2
//
//  Created by Sean Cavalieri on 11/19/23.
//

import Foundation
import SwiftUI
import ARKit
import RealityKit

class DataModel: ObservableObject {
    @Published var arView: ARView
    @Published var models: [CompElement]
    @Published var planeHeight: Float
    @Published var selectionMenuOpen: Bool = false
    @Published var isImporting: Bool = false
    @Published var referenceID: UUID? = nil
    @Published var generatedMapURL: URL? = nil
    let refractionUtils: RefractionUtils = RefractionUtils()
    let planeAnchor: AnchorEntity
    let entitiesAnchor: AnchorEntity
    var planeUpdateCount = 0
    // long press vars
    var selectedEntity: ModelEntity? = nil
    var selectedEntityYOrigin: Float? = nil
    var pressYOrigin: CGFloat? = nil
    // File Management
    let fm = FileManager.default
    var modelsPath: URL
    var mapsPath: URL
    
//    var sessDel: ARSessionDelegate = ARSessDelegate()
    
    init() {
        // Set up file storage
        let documentsURL: URL = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        modelsPath = documentsURL.appendingPathComponent("Models")
        do {
            print("Creating Models directory")
            try fm.createDirectory(at: modelsPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Did not create Models directory: \(error)")
        }
        mapsPath = documentsURL.appendingPathComponent("Maps")
        do {
            print("Creating Maps directory")
            try fm.createDirectory(at: mapsPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Did not create Maps directory: \(error)")
        }
        
        // Set up AR
        models = []
        planeHeight = 0.0
        arView = ARView(frame: .zero)
//        arView.session.delegate = sessDel
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        
        planeAnchor = AnchorEntity(plane: .horizontal, minimumBounds: [0.2, 0.2])
        entitiesAnchor = AnchorEntity(plane: .horizontal, minimumBounds: [0.2, 0.2])
        
        arView.session.run(config)
        arView.addCoaching()
        
        setupWaterSurfacePlane()
        initializeModels()
        arView.renderCallbacks.postProcess = myPostProcessCallback
        
        updateSurface(0)
    }
    
    func setupWaterSurfacePlane() {
        // Add water surface plane
        let material = SimpleMaterial(color: UIColor.blue.withAlphaComponent(0.5), isMetallic: false)
        let meshPrimitive = MeshResource.generatePlane(width: 0.5, depth: 0.5)
        let modelEntity = ModelEntity(mesh: meshPrimitive, materials: [material])
        modelEntity.name = "Surface"
        modelEntity.generateCollisionShapes(recursive: false)
        
        planeAnchor.addChild(modelEntity)
        modelEntity.setPosition([0, 0, 0], relativeTo: planeAnchor)
        planeAnchor.name = "Plane"
        arView.installGestures([.translation], for: modelEntity)
        // Add the anchors to the scene
        arView.scene.anchors.append(planeAnchor)
    }
    
    func initializeModels() {
        // Read items from files
        do {
            let urls: [URL] = try fm.contentsOfDirectory(at: modelsPath, includingPropertiesForKeys: nil)
            print("URLS: \(urls), modelsPath: \(modelsPath)")

            for url in urls {
                guard let body: Entity = try? Entity.load(contentsOf: url) else { continue }
                let modelName: String = url.deletingPathExtension().lastPathComponent
                generateElement(modelName: modelName, body: body, url: url)
                if referenceID == nil {
                    referenceID = models[0].id
                }
            }
        } catch {
             print("Failed to read files")
        }
        
        arView.scene.anchors.append(entitiesAnchor)
    }
    
    func generateElement(modelName: String, body: Entity, url: URL) {
        recurseNaming(name: "projection", entity: body)
        let material = UnlitMaterial(color: .clear)
        // let material = SimpleMaterial()   // To visualize backing entity
        let backing = ModelEntity(mesh: MeshResource.generateBox(size: 0.01), materials: [material])
        backing.name = modelName
        
        entitiesAnchor.addChild(backing)
        backing.setPosition([0, 0, 0], relativeTo: planeAnchor.findEntity(named: "Surface"))
        backing.addChild(body)
        body.setPosition([0, 0, 0], relativeTo: backing)
        backing.generateCollisionShapes(recursive: true)
        
        // Install translation gesture for horizontal movement
        arView.installGestures([.translation, .rotation], for: backing)
        
        // Install long-press and pan gesture for vertical movement
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.3
        arView.addGestureRecognizer(longPress)
        
        backing.isEnabled = false
        
        models.append(CompElement(name: modelName, url: url, body: backing))
    }
    
    @objc func handleLongPress(_ recognizer: UITapGestureRecognizer? = nil) {
        
        // Get tap location - (0,0) is top left, +y is down, +x is right
        guard let touchInView = recognizer?.location(in: self.arView) else { return }
        
        switch recognizer?.state {
        case .some(.began):
            // Touch satisfied `minimumPressDuration`
            guard var entity: Entity = self.arView.entity(at: touchInView) else {
                // test code here
                return
            }
            while entity.name == "projection" {
                guard let parent = entity.parent else { return }
                entity = parent
            }
            selectedEntity = entity as? ModelEntity
            if selectedEntity != nil {
                pressYOrigin = touchInView.y
                selectedEntityYOrigin = entity.position(relativeTo: entitiesAnchor).y
            }
        case .some(.changed):
            // Touch moved after began
            let sensitivity = -0.005
            if let entity = selectedEntity,
               let entityYOrigin = selectedEntityYOrigin,
               let yOrigin = pressYOrigin {
                var pos = entity.position(relativeTo: entitiesAnchor)
                pos.y = entityYOrigin + Float((sensitivity * (touchInView.y - yOrigin)))
                entity.setPosition(pos, relativeTo: entitiesAnchor)
            }
        case .some(.ended):
            // Touch lifted after began
            (selectedEntity, selectedEntityYOrigin, pressYOrigin) = (nil, nil, nil)
        default:
            return
        }
    }
    
    func myPostProcessCallback(context: ARView.PostProcessContext) {
       // Handle postprocessing here (using positioning relative to planeAnchor)
        for compElem in models {
            let model = compElem.body
            if model.isEnabled {
                let cameraPos = planeAnchor.convert(position: arView.cameraTransform.translation, from: nil)
                let bodyPos = model.position(relativeTo: planeAnchor)
                let refractionOffset = refractionUtils.findProjection(camera: cameraPos, body: bodyPos, surface: planeHeight, model.name)
                if let body = model.findEntity(named: "projection") {
                    body.setPosition(refractionOffset, relativeTo: model)
                } else {
                    print("ERROR: Could not find projection body")
                }
            }
        }
        // Don't do any visual frame modifications, so just write to buffer
        let blitEncoder = context.commandBuffer.makeBlitCommandEncoder()
        blitEncoder?.copy(from: context.sourceColorTexture, to: context.targetColorTexture)
        blitEncoder?.endEncoding()
    }
    
    func updateSurface(_ delta: Float) {
        planeUpdateCount += 1
        if let plane = planeAnchor.findEntity(named: "Surface") {
            planeHeight += delta
            var pos = plane.position(relativeTo: planeAnchor)
            pos.y = planeHeight
            plane.setPosition(pos, relativeTo: planeAnchor)
            
            // Show the plane for 5 seconds
            let closure = { [planeUpdateCount] in
                if planeUpdateCount == self.planeUpdateCount {
                    plane.isEnabled = false
                }
            }
            plane.isEnabled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                closure()
            }
        }
    }
    
    func showModel(id: UUID) {
        for compElem in models {
            if compElem.id == id {
                compElem.body.isEnabled = true
//                compElem.body.position = planeAnchor.position
                if let surface = planeAnchor.findEntity(named: "Surface") {
                    compElem.body.setPosition([0,0,0], relativeTo: surface)
                }
                break
            }
        }
    }
    
    func hideAll() {
        for m in models {
            m.body.isEnabled = false
        }
                    
    }
    
    func deleteElement(id: UUID) {
        for (idx, model) in models.enumerated() {
            if model.id == id {
                do {
                    try fm.removeItem(at: model.url)
                    entitiesAnchor.removeChild(model.body)
                    models.remove(at: idx)
                    // Reset reference entity if removed
                    if let ref = referenceID, ref == model.id {
                        if models.count == 0 {
                            referenceID = nil
                        } else {
                            referenceID = models[0].id
                        }
                    }
                } catch {
                    print("Error: Unable to delete model file: \(error)")
                }
                return
            }
        }
        print("Error: Did not find model with that id")
    }
    
    func uploadModel(url: URL) {
        let newURL = modelsPath.appendingPathComponent(url.lastPathComponent)
        do {
            print("Copying \(url) to \(modelsPath)")
            try fm.copyItem(at: url, to: newURL)
            guard let body: Entity = try? Entity.load(contentsOf: newURL) else { return }
            recurseNaming(name: "projection", entity: body)
            let modelName: String = newURL.deletingPathExtension().lastPathComponent
            generateElement(modelName: modelName, body: body, url: newURL)
            if referenceID == nil {
                referenceID = models[0].id
            }
        } catch {
            print("Failed to store new file: \(error)")
        }
    }
    
    func recurseNaming(name: String, entity: Entity) {
        entity.name = name
        for child in entity.children {
            recurseNaming(name: name, entity: child)
        }
    }
    
    // MARK: POSITION EXPORT UTILS
    func mapElementsJSONString(relativeTo entity: Entity) -> String? {
        let dict = mapElements(relativeTo: entity)
        let jsonData = try? JSONEncoder().encode(dict)
        if jsonData != nil {
            guard let jsonString = String(data: jsonData!, encoding: .utf8) else {
                print("Failed to write JSON String")
                return nil
            }
            return jsonString
        } else {
            print("Failed to parse JSON")
            return nil
        }
    }
    
    // Gets dictionary of element positions relative to the given entity. RelativeTo Entity's orientation is considered
    func mapElements(relativeTo entity: Entity) -> Dictionary<String, Dictionary<String, Float>> {
        var data = Dictionary<String, Dictionary<String, Float>>()
        for model in models {
            if model.body.isEnabled {
                let pos: SIMD3<Float> = model.body.position(relativeTo: entity)
                let q: simd_quatf = model.body.orientation(relativeTo: entity)
                let yaw: Float = quadToYaw(q: q)
                data[model.name] = ["locX": pos.x, "locY": pos.y, "locZ": pos.z, "yaw": yaw]
            }
        }
        return data
    }
    
    func generateMap() {
        if let ref = referenceID, let refEntity = models.first(where: { $0.id == ref }) {
            guard let mapStr = mapElementsJSONString(relativeTo: refEntity.body) else {
                print("Failed to generate map JSON")
                return
            }
            // Export
            let fileURL = mapsPath.appendingPathComponent(Date().timeIntervalSince1970.description + ".txt")
            do {
                try mapStr.write(to: fileURL, atomically: true, encoding: .utf8)
                generatedMapURL = fileURL
            } catch {
                print("Failed to write to file")
            }
        } else {
            print("Failed to find reference object")
        }
    }
    
    func quadToYaw(q quat: simd_quatf) -> Float {

        let q = quat.normalized
        
        let q2sqr: Float = q.imag.y * q.imag.y;
        let t0: Float = -2.0 * (q2sqr + q.imag.z * q.imag.z) + 1.0;
        let t1: Float = +2.0 * (q.imag.x * q.imag.y + q.real * q.imag.z);
        var t2: Float = -2.0 * (q.imag.x * q.imag.z - q.real * q.imag.y);
        let t3: Float = +2.0 * (q.imag.y * q.imag.z + q.real * q.imag.x);
        let t4: Float = -2.0 * (q.imag.x * q.imag.x + q2sqr) + 1.0;

        t2 = t2 > 1.0 ? 1.0 : t2;
        t2 = t2 < -1.0 ? -1.0 : t2;

        // Yaw, Roll, Pitch
        var yaw = asin(t2)
        let roll = atan2(t3, t4)
        let pitch = atan2(t1, t0)
        
        // Adjust to prioritize yaw (undo flips in pitch/roll)
        if roll > Float.pi / 2 && pitch > Float.pi / 2 {
            if yaw < 0 {
                yaw = -Float.pi - yaw
            } else {
                yaw = Float.pi - yaw
            }
        }
        if yaw < 0 {
            yaw += 2 * Float.pi
        }
        
        return yaw
    }
}
