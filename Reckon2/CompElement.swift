//
//  CompElement.swift
//  Reckon2
//
//  Created by Sean Cavalieri on 12/31/23.
//

import Foundation
import ARKit
import RealityKit

struct CompElement: Identifiable {
    let id: UUID = UUID()
    let name: String
    let url: URL
    let body: Entity
}
