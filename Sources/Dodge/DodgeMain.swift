//
//  DodgeMain.swift
//  SwiftGodotKit
//
//  Created by Miguel de Icaza on 4/14/23.
//

import Foundation
import SwiftGodot

@Godot
class Main: Node {
    @BindNode var startTimer: SwiftGodot.Timer
    @BindNode var scoreTimer: SwiftGodot.Timer
    @BindNode var mobTimer: SwiftGodot.Timer
    @BindNode var hud: Hud
    @BindNode var music: AudioStreamPlayer
    @BindNode var deathSound: AudioStreamPlayer
    @BindNode var startPosition: Marker2D
    @BindNode var player: Player
    
    @Export var mob_scene: PackedScene = PackedScene()
    
    var score: Double = 0
    
    @Callable
    func game_over () {
        // TODO: get_tree().call_group(&"mobs", &"queue_free")
        scoreTimer.stop()
        mobTimer.stop()
        Task {
            await hud.showGameOver ()
            Task { @MainActor in
                music.stop ()
                deathSound.play ()
            }
        }
    }
    
    @Callable
    func new_game () {
        score = 0
        player.start (pos: startPosition.position)
        startTimer.start ()
        hud.updateScore(score: score)
        hud.showMessage("Get Ready")
        music.play()
    }

    @Callable
    func _on_ScoreTimer_timeout () {
        score += 1
        hud.updateScore(score: score)
    }
    
    @Callable
    func _on_StartTimer_timeout () {
        add = true
        mobTimer.start()
        scoreTimer.start ()
    }
    
    var add = true
    @Callable
    func _on_MobTimer_timeout() {
        if !add { return }
        add = false
        // Create a new instance of the Mob scene.
        guard let mob = mob_scene.instantiate() as? RigidBody2D else {
            print ("MobScene is not a RigidBody2D")
            return
        }
        
        // Choose a random location on Path2D.
        guard let mobSpawnLocation = getNode (path: "MobPath/MobSpawnLocation") as? PathFollow2D else {
            print ("Error")
            return
        }
        
        // Choose a random location on Path2D.
        mobSpawnLocation.progress = Double (Int.random(in: Int.min..<Int.max))
        // Set the mob's direction perpendicular to the path direction.
        var direction = mobSpawnLocation.rotation + Double.pi / 2.0

        // Set the mob's position to a random location.
        mob.position = mobSpawnLocation.position

        //Add some randomness to the direction.
        direction += Double.random(in: -Double.pi/4..<Double.pi/4)
        mob.rotation = direction

        // Choose the velocity for the mob.
        let velocity = Vector2(x: Float.random (in: 150..<250), y: 0)
        mob.linearVelocity = velocity.rotated(angle: direction)

        // Spawn the mob by adding it to the Main scene.
        addChild(node: mob)
    }
}
