//
//  Vector2iTests.swift
//
//
//  Created by Mikhail Tishin on 21.10.2023.
//

import XCTest
@testable import SwiftGodot
@testable import SwiftGodotKit

final class Vector2iTests: XCTestCase {
    
    func testOperatorPlus() async {
        await GodotRuntime.ensureRunning()
        var value: Vector2i
        
        value = Vector2i.init(x: 1, y: 2) + Vector2i.init(x: 3, y: 4)
        XCTAssertEqual(value.x, 4)
        XCTAssertEqual(value.x, 6)
    }
    
}
