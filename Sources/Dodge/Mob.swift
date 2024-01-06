//
//  Mob.swift
//  SwiftGodotKit
//
//  Created by Miguel de Icaza on 4/14/23.
//

import Foundation
import SwiftGodot

@Godot
class Mob: RigidBody2D {
    @BindNode var animatedSprite2D: AnimatedSprite2D
    
    var minSpeed: Float = 150
    var maxSpeed: Float = 250
    
    override func _ready() {
        
        // animatedSprite2D.setPlaying = true
        let mobTypes = animatedSprite2D.spriteFrames?.getAnimationNames()
        
        let randomPick = Int.random(in: 0..<(Int (mobTypes?.size() ?? 1)))
        let name = StringName (String (mobTypes! [randomPick]))
        
        animatedSprite2D.animation = name
    }
}
