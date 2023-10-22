//
//  GodotRuntime.swift
//
//
//  Created by Mikhail Tishin on 22.10.2023.
//

import Foundation
import SwiftGodotKit

final class GodotRuntime {
    
    static var isRunning: Bool = false
    
    static func ensureRunning() async {
        guard !isRunning else { return }
        isRunning = true
        await withUnsafeContinuation { continuation in
            DispatchQueue.main.async {
                runGodot(args: [], initHook: {
                    level in
                }, loadScene: { scene in
                    continuation.resume()
                }, loadProjectSettings: {
                    settings in
                })
            }
        }
    }
    
}
