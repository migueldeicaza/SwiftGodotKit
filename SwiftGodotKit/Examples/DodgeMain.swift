//
//  DodgeMain.swift
//  SwiftGodotKit
//
//  Created by Miguel de Icaza on 4/14/23.
//

import Foundation
import SwiftGodot

class Main: Node {
    @BindNode var startTimer: SwiftGodot.Timer
    @BindNode var scoreTimer: SwiftGodot.Timer
    @BindNode var mobTimer: SwiftGodot.Timer
    @BindNode var hud: Hud
    @BindNode var music: AudioStreamPlayer
    @BindNode var deathSound: AudioStreamPlayer
    @BindNode var startPosition: Marker2D
    @BindNode var player: Player
    
    // TODO: @Export this
    var mobScene = PackedScene()
    
    var score: Double = 0
    
    required init () {
        super.init()
    }
    
    required init(nativeHandle: UnsafeRawPointer) {
        fatalError()
    }
    
    func gameOver () async {
        mobTimer.stop ()
        await hud.showGameOver ()
        music.stop ()
        deathSound.play (fromPosition: 0.0)
    }
    
    func newGame () {
        score = 0
        player.start (pos: startPosition.position)
        startTimer.start ()
        hud.updateScore(score: score)
        hud.showMessage("Get Ready")
        music.play()
    }

    func on_ScoreTimer_timeout () {
        score += 1
        hud.updateScore(score: score)
    }
    
    func on_StartTimer_timeout () {
        mobTimer.start()
        scoreTimer.start ()
    }
    
    func on_MobTimer_timeout() {
        guard let mob = mobScene.instantiate() as? RigidBody2D else {
            print ("MobScene is not a RigitBody2D")
            return
        }
        
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
