//
//  ARView+CoachingOverlay.swift
//  Reckon2
//
//  Created by Sean Cavalieri on 11/19/23.
//

import Foundation
import ARKit
import RealityKit

extension ARView: ARCoachingOverlayViewDelegate {
  func addCoaching() {
    // Create a ARCoachingOverlayView object
    let coachingOverlay = ARCoachingOverlayView()
    // Make sure it rescales if the device orientation changes
    coachingOverlay.autoresizingMask = [
      .flexibleWidth, .flexibleHeight
    ]
    self.addSubview(coachingOverlay)
    // Set the Augmented Reality goal
    coachingOverlay.goal = .horizontalPlane
    // Set the ARSession
    coachingOverlay.session = self.session
    // Set the delegate for any callbacks
    coachingOverlay.delegate = self
  }
//  // Example callback for the delegate object
//    public func coachingOverlayViewDidDeactivate(
//    _ coachingOverlayView: ARCoachingOverlayView
//  ) {
//    self.addObjectsToScene()
//  }
}
