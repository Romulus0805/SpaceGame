//
//  TitleScreen.swift
//  SpaceGame
//
//  Created by Mobile on 4/17/26.
//

import SpriteKit

class TitleScreen: SKScene {
    override func didMove(to view: SKView) {
        // do setup such as emitter nodes for stars, ect
        let labelNode = self.childNode(withName: "Title") as! SKLabelNode
        labelNode.text = "Welcome to \nSpaceGame"
        labelNode.fontName = "Futura"
        labelNode.fontSize = 50
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let view = self.view {
            if let scene = SKScene(fileNamed: "GameScene") {
                scene.scaleMode = .aspectFill
                let transition = SKTransition.doorsOpenHorizontal(withDuration: 2)
                
                view.presentScene(scene, transition: transition)
            }
        }
    }
}
