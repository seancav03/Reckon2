//
//  RefractionUtils.swift
//  Reckon2
//
//  Created by Sean Cavalieri on 12/3/23.
//

import Foundation

class RefractionUtils {
    
    // All positions relative to world anchor
    func findProjection(camera: SIMD3<Float>, body: SIMD3<Float>, surface: Float, _ name: String = "Unnamed") -> SIMD3<Float> {
        if !validate(camera: camera, body: body, surface: surface, name: name) {
            // No offset if refraction isn't desired
            return SIMD3(x: 0, y: 0, z: 0)
        }
        
        let a = camera.y - surface
        let b = surface - body.y
        let d = sqrt(pow((camera.x - body.x), 2) + pow((camera.z - body.z), 2))
        
        let surfaceP = findSurfacePoint(a: a, b: b, d: d)
        
        let (profOffset_x, profOffset_y) = findProjectionOffsets(a: a, b: b, x: surfaceP, y: d - surfaceP)
        
        let y_diff = (a + b) - profOffset_y
        
        let horiz_theta = atan2(body.z - camera.z, body.x - camera.x)
        let b_offset = profOffset_x - sqrt(pow(body.z - camera.z, 2) + pow(body.x - camera.x, 2))
        
        let x_diff = cos(horiz_theta) * b_offset
        let z_diff = sin(horiz_theta) * b_offset
        let proj_rel_body = SIMD3(x: x_diff, y: y_diff, z: z_diff)
        
//        print("---")
//        print("1: C: \(printSIMD3(camera)), B: \(printSIMD3(body)), S: \(surface)")
//        print("2: a: \(printFl(a)), b: \(printFl(b)), d: \(printFl(d))")
//        print("3: surfaceP: \(surfaceP)")
//        print("4: proj_x: \(surfaceP), pro_offsetX: \(profOffset_x), pro_offsetY: \(profOffset_y)")
//        print("5: horiz_theta: \(horiz_theta), b_offset: \(b_offset)")
//        print("6: x_diff: \(x_diff), y_diff: \(y_diff), z_diff: \(z_diff)")
        
        return proj_rel_body
    }
    
    func printSIMD3(_ sim: SIMD3<Float>) -> String {
        let x = round(sim.x * 100) / 100
        let y = round(sim.y * 100) / 100
        let z = round(sim.z * 100) / 100
        return "[\(x), \(y), \(z)]"
    }
    func printFl(_ f: Float) -> String {
        return "\(round(f * 100) / 100)"
    }
    
    // Find surface point given easily found parameters
    func findSurfacePoint(a: Float, b: Float, d: Float, thresh: Float = 0.01) -> Float {
        var l: Float = (d / (a + b)) * a
        var r: Float = d
        var x: Float = d/2
        while r - l > thresh {
            if f(a: a, x: x) > g(b: b, d: d, x: x) {
                l = x
                x = (l + r) / 2
            } else {
                r = x
                x = (l + r) / 2
            }
        }
        return x
    }
    
    // Returns projection's location in delta_x and delta_y from camera position (delta_x is shortest dist horizontal, delta_y is veritical dist)
    func findProjectionOffsets(a: Float, b: Float, x: Float, y: Float) -> (Float, Float) {
        let pd = sqrt(pow(y, 2) + pow(b, 2)) + sqrt(pow(a, 2) + pow(x, 2))
        let theta_1 = atan2(a, x)
        return (cos(theta_1) * pd, sin(theta_1) * pd)
    }
    
    // f and g intersect at desired x
    func f(a: Float, x: Float) -> Float {
        return atan2(a, x)
    }
    
    // f and g intersect at desired x
    func g(b: Float, d: Float, x: Float) -> Float {
        let t = atan2(b, d - x)
        let c = (4/3) * cos(t)
        // If acos is undefined, return -1 to ensure function guesses further right (visualize in desmos)
        return (-1 <= c && c <= 1) ? acos(c) : -1
    }
    
    func validate(camera: SIMD3<Float>, body: SIMD3<Float>, surface: Float, name: String) -> Bool {
        if camera.y - 0.1 <= surface {
            // Camera must be 10 centimeters above the water
//            print("Camera is underwater")
        } else if body.y + 0.11 >= surface {
            // Body must be 10 centimeters below the water
//            print("Body \(name) is above water by ", (body.y - surface), " meters")
        } else {
//            print("Performing Refraction Calculation on ", name)
            return true
        }
        return false
    }
    
}
