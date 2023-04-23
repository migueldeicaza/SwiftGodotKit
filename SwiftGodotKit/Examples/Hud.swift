//
//  Hud.swift
//  SwiftGodotKit
//
//  Created by Miguel de Icaza on 4/11/23.
//

import Foundation
import SwiftGodot

class Hud: CanvasLayer {
    @BindNode var messageLabel: Label
    @BindNode var messageTimer: SwiftGodot.Timer
    @BindNode var startButton: Button
    @BindNode var scoreLabel: Label
    
    required init () {
        super.init ()
    }
    
    required init(nativeHandle: UnsafeRawPointer) {
        fatalError("init(nativeHandle:) has not been implemented")
    }
    
    func showMessage (_ text: String) {
        messageLabel.text = text
        messageLabel.show ()
        messageTimer.start()
    }
    
    func showGameOver () {
        showMessage("Game over")
        // TODO: This is a signal
        //await timer.timeout()
        messageLabel.text = "Dodge the creeps"
        messageLabel.show ()
        let t = getTree().createTimer(timeSec: 1)
        // TODO this is a signal
        // await t.timeout()
        startButton.show ()
    }
    
    func updateScore (score: Double) {
        scoreLabel.text = "\(score)"
    }
    
    public func on_StartButton_pressed () {
        startButton.hide()
        emitSignal (signal: "StartGame")
    }
    
    public func on_MessageTimer_timeout () {
        messageLabel.hide()
    }
}
