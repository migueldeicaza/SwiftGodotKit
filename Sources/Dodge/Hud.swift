//
//  Hud.swift
//  SwiftGodotKit
//
//  Created by Miguel de Icaza on 4/11/23.
//

import Foundation
import SwiftGodot

@Godot
class Hud: CanvasLayer {
    @BindNode var messageLabel: Label
    @BindNode var messageTimer: SwiftGodot.Timer
    @BindNode var startButton: Button
    @BindNode var scoreLabel: Label
    #signal("start_game")
    
    func showMessage (_ text: String) {
        messageLabel.text = text
        messageLabel.show ()
        messageTimer.start()
    }
    
    func showGameOver () async {
        showMessage("Game over")
        
        await messageTimer.timeout.emitted
        messageLabel.text = "Dodge the creeps"
        messageLabel.show ()
        guard let t = getTree()?.createTimer(timeSec: 1) else {
            return
        }
        
        await t.timeout.emitted
        startButton.show ()
    }
    
    func updateScore (score: Double) {
        scoreLabel.text = "\(score)"
    }
    
    @Callable
    func _on_StartButton_pressed () {
        startButton.hide()
        emit (signal: Hud.startGame)
    }
    
    @Callable
    func _on_MessageTimer_timeout () {
        messageLabel.hide()
    }
}
