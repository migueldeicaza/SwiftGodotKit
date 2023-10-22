//
//  MainTest.swift
//
//
//  Created by Mikhail Tishin on 22.10.2023.
//

import XCTest
import SwiftGodot
import SwiftGodotKit

final class MainTest: XCTestCase {
    
    private func runTests () {
        run (test: Vector2iTests ())
    }
    
    private func run (test: XCTest) {
        XCTestSuite.default.perform (XCTestRun (test: test))
    }
    
    override func run () {
        GodotRuntime.run {
            self.runTests ()
            GodotRuntime.stop ()
        }
    }
    
    func test () {
    }
    
}

class GodotTestCase: XCTestCase {
    
    override func run () {
        guard GodotRuntime.isRunning else { return }
        super.run ()
    }
    
}
