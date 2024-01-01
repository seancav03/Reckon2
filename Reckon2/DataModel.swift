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
    @Published var models: [Entity]
    @Published var planeHeight: Float
    let refractionUtils: RefractionUtils = RefractionUtils()
    let planeAnchor: AnchorEntity
    let entitiesAnchor: AnchorEntity
    var planeUpdateCount = 0
    // long press vars
    var selectedEntity: ModelEntity? = nil
    var selectedEntityYOrigin: Float? = nil
    var pressYOrigin: CGFloat? = nil
    
//    var sessDel: ARSessionDelegate = ARSessDelegate()
    
    init() {
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
        
        planeAnchor.addChild(modelEntity)
        modelEntity.setPosition([0, 0, 0], relativeTo: planeAnchor)
        planeAnchor.name = "Plane"
        // Add the anchors to the scene
        arView.scene.anchors.append(planeAnchor)
    }
    
    func initializeModels() {
        // Initialize the Models
        let elemsAnchor = try! Experience.loadElements()
        let modelNames = ["Cube", "Sphere", "Cone"]
        
        // Process scene
        for model in modelNames {
            guard let body = elemsAnchor.findEntity(named: model) as? Entity & HasCollision else {
                print("No entity found with name: ", model)
                continue
            }
            body.name = "projection"
            // Hidden Backing
            //            let material = UnlitMaterial(color: .clear)
            let material = SimpleMaterial()
            let backing = ModelEntity(mesh: MeshResource.generateBox(size: 0.01), materials: [material])
            backing.name = model
            
            entitiesAnchor.addChild(backing)
            backing.setPosition([0, 0, 0], relativeTo: entitiesAnchor)
            backing.addChild(body)
            body.setPosition([0, 0, 0], relativeTo: backing)
            backing.generateCollisionShapes(recursive: false)
            
            // Install translation gesture for horizontal movement
            arView.installGestures(.translation, for: backing)
            
            // Install long-press and pan gesture for vertical movement
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            longPress.minimumPressDuration = 0.3
            arView.addGestureRecognizer(longPress)
            
            backing.isEnabled = false
            models.append(backing)
        }
        
        arView.scene.anchors.append(entitiesAnchor)
    }
    
    @objc func handleLongPress(_ recognizer: UITapGestureRecognizer? = nil) {
        
        // Get tap location - (0,0) is top left, +y is down, +x is right
        guard let touchInView = recognizer?.location(in: self.arView) else { return }
        
        switch recognizer?.state {
        case .some(.began):
            // Touch satisfied `minimumPressDuration`
            guard var entity: Entity = self.arView.entity(at: touchInView) else { return }
            if entity.name == "projection" {
                guard let parent = entity.parent as? ModelEntity else { return }
                entity = parent
            }
            selectedEntity = entity as? ModelEntity
            pressYOrigin = touchInView.y
            selectedEntityYOrigin = entity.position(relativeTo: entitiesAnchor).y
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
        for model in models {
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
            plane.setPosition([0, planeHeight, 0], relativeTo: planeAnchor)
            
            // Show the plane for 5 seconds
            let closure = { [planeUpdateCount] in
                if planeUpdateCount == self.planeUpdateCount {
                    plane.isEnabled = false
                }
            }
            plane.isEnabled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                closure()
            }
        }
    }
    
    func showModel(idx: Int) {
        if idx < models.count && idx >= 0 {
            models[idx].isEnabled = true
            models[idx].position = planeAnchor.position
        }
    }
    
    func hideAll() {
        for m in models {
            m.isEnabled = false
        }
                    
    }
    
}
