//
//  Player.swift
//  SwiftGodotKit
//
//  Created by Miguel de Icaza on 4/14/23.
//

import Foundation
import SwiftGodot

class Player: Area2D {
    @BindNode var collissionShape2D: CollisionShape2D
    @BindNode var animatedSprite: AnimatedSprite2D
    
    // TODO: Flag this for export
    var speed: Double = 400
    var screenSize: Vector2
    
    override func _ready() {
        // TODO: global get_viewport_rect
        // screenSize =
    }
    
    func start (pos: Vector2) {
        globalPosition = pos
        show ()
        collissionShape2D.disabled = false
    }
    
    // TODO: register signal hit
    func on_player_body_entered (body: PhysicsBody2D) {
        // player dissapears after being hit
        super.hide ()
        super.emitSignal("hit")
        // Must be deferred as we can't change physics properties on a physics callback.
        collissionShape2D.setDeferred(property: StringName ("disabled"), value: Variant (true))
    }
    
    override func _process(delta: Double) {
        var velocity = Vector2(x: 0, y: 0)

        if Input.isActionPressed(action: "ui_right", exactMatch: false) {
            velocity = velocity + Vector2 (x: 0, y: 0)
        }
        if Input.isActionPressed(action: "ui_left", exactMatch: false) {
            velocity = velocity + Vector2.left
        }
        if Input.isActionPressed(action: "ui_down", exactMatch: false) {
            velocity = velocity + Vector2.down
        }
        if Input.isActionPressed(action: "ui_up", exactMatch: false) {
            velocity = velocity + Vector2.up
        }
        
        if velocity.length() > 0.0 {
            velocity = velocity.normalized() * speed
            
            var animation: StringName
            
            if velocity.x != 0.0 {
                animation = "right"
                
                animatedSprite.flipV = false
                animatedSprite.flipH = velocity.x < 0.0
            } else {
                animation = "up"
                
                animatedSprite.flipV = velocity.y > 0.0
            }
            animatedSprite.play(name: animation, customSpeed: 1.0, fromEnd: false)
        } else {
            animatedSprite.stop()
        }
        
        let change = velocity * delta;
        let position = globalPosition + change
        globalPosition = Vector2 (
            x: position.x.clamp(0.0, self.screenSize.x),
            y: position.y.clamp(0.0, self.screenSize.y))
    }
}

extension Float {
    func clamp (_ min: Float, _ max: Float) -> Float {
        if self < min { return min }
        if self > max { return max }
        return self
    }
}
