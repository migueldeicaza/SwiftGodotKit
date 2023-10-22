//
//  main.swift
//
//
//  Created by Mikhail Tishin on 22.10.2023.
//

import XCTest
import SwiftGodot
import SwiftGodotKit

final class _MainTest: XCTestCase {
    
    private func runTests() {
        run(test: Vector2iTests())
    }
    
    private func run(test: XCTest) {
        XCTestSuite.default.perform(XCTestRun(test: test))
    }
    
    override func run() {
        GodotRuntime.run {
            self.runTests()
            GodotRuntime.stop()
            self.testRun?.stop()
        }
    }
    
    func test() {
    }
    
}
