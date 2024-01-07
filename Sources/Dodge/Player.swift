//
//  Player.swift
//  SwiftGodotKit
//
//  Created by Miguel de Icaza on 4/14/23.
//

import Foundation
import SwiftGodot

@Godot
class Player: Area2D {
    @BindNode var collisionShape2D: CollisionShape2D
    @BindNode var animatedSprite2D: AnimatedSprite2D
    @BindNode var trail: GPUParticles2D
    
    @Export var speed: Double = 400
    var screenSize: Vector2 = Vector2(x: 0, y: 0)
    #signal("hit")
    
    override func _ready() {
        screenSize = getViewportRect().size
        hide()
    }
    
    func start (pos: Vector2) {
        position = pos
        show ()
        collisionShape2D.disabled = false
    }
    
    // TODO: register signal hit
    func on_player_body_entered (body: PhysicsBody2D) {
        // player dissapears after being hit
        super.hide ()
        super.emitSignal("hit")
        // Must be deferred as we can't change physics properties on a physics callback.
        collisionShape2D.setDeferred(property: StringName ("disabled"), value: Variant (true))
    }
    
    override func _process(delta: Double) {
        var velocity = Vector2(x: 0, y: 0)

        if Input.isActionPressed(action: "ui_right") {
            velocity = velocity + Vector2 (x: 0, y: 0)
        }
        if Input.isActionPressed(action: "ui_left") {
            velocity = velocity + Vector2.left
        }
        if Input.isActionPressed(action: "ui_down") {
            velocity = velocity + Vector2.down
        }
        if Input.isActionPressed(action: "ui_up") {
            velocity = velocity + Vector2.up
        }
        
        if velocity.length() > 0.0 {
            velocity = velocity.normalized() * speed
            animatedSprite2D.play()
        } else {
            animatedSprite2D.stop()
        }
        let pos = position + velocity * delta
        position = pos.clamp(min: Vector2.zero, max: screenSize)
                
        if velocity.x != 0.0 {
            animatedSprite2D.animation = "right"
            
            animatedSprite2D.flipV = false
            trail.rotation = 0
            animatedSprite2D.flipH = velocity.x < 0.0
        } else if velocity.y != 0.0 {
            animatedSprite2D.animation = "up"
            
            animatedSprite2D.flipV = velocity.y > 0.0
            trail.rotation = velocity.y > 0 ? .pi : 0
        }
    }
    
    @Callable
    func _on_Player_body_entered ()
    {
        hide() // Player disappears after being hit.
        emit(signal: Player.hit)
           
        // Must be deferred as we can't change physics properties on a physics callback.
        collisionShape2D.setDeferred(property: "disabled", value: Variant (true))
    }
}

