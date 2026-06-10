//
//  GameScene.swift
//  SpaceGame
//
//  Created by Mobile on 4/7/26.
//

import SpriteKit
import GameplayKit

class GameScene: SKScene, SKPhysicsContactDelegate {
    var player: SKSpriteNode!
    var isMoving: Bool = false
    var score = 0
    
    let scoreLabel = SKLabelNode(text: "Score: 0")
    
    let noCategory: UInt32 = 0x0
    let playerCategory: UInt32 = 0x1 << 0 // 0000.....0001
    let laserCategory: UInt32 = 0x1 << 1 // 0000.....0010
    let enemyCategory: UInt32 = 0x1 << 2 // 0000.....0100
    let itemCategory: UInt32 = 0x1 << 3 // 0000.....1000
    let asteroidCategory: UInt32 = 0x1 << 5
    
    // Power-up state
    let normalLaserInterval: TimeInterval = 0.5
    let poweredUpLaserInterval: TimeInterval = 0.15
    var isPoweredUp: Bool = false
    let powerUpLabel = SKLabelNode(text: "RAPID FIRE")
    
    let explosionSound = SKAction.playSoundFileNamed("explosion", waitForCompletion: false)
    let laserSound = SKAction.playSoundFileNamed("laser", waitForCompletion: false)
    
    override func didMove(to view: SKView) {
        
        let music = SKAudioNode(fileNamed: "music.m4a")
        music.autoplayLooped = true
        music.run(SKAction.changeVolume(to: 2, duration: 1))
        self.addChild(music)
        
        self.player = (self.childNode(withName: "player") as! SKSpriteNode)
        self.player.physicsBody?.categoryBitMask = playerCategory
        self.player.physicsBody?.contactTestBitMask = enemyCategory | itemCategory
        player.physicsBody?.collisionBitMask = noCategory
        
        self.physicsWorld.contactDelegate = self
        view.showsPhysics = true
        
        scoreLabel.position = CGPoint(x: -210, y: -630) // (0,0) at CENTER of screen!
        scoreLabel.fontColor = .white
        scoreLabel.fontSize = 50
        self.addChild(scoreLabel)
        
        // Power-up label (hidden by default)
        powerUpLabel.position = CGPoint(x: 0, y: -580)
        powerUpLabel.fontColor = .yellow
        powerUpLabel.fontSize = 30
        powerUpLabel.isHidden = true
        self.addChild(powerUpLabel)
        
        startLaserSpawning(interval: normalLaserInterval)
        
        let spawnEnemySequence = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.run(spawnEnemy),
                SKAction.wait(forDuration: 0.75)
            ])
        )
        self.run(spawnEnemySequence)
        
        let spawnItemSequence = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.run(spawnItem),
                SKAction.wait(forDuration: 15.0)
            ])
        )
        self.run(spawnItemSequence)
        
        let spawnAsteroidSequence = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.run(spawnAsteroid),
                SKAction.wait(forDuration: TimeInterval(Int.random(in: 10 ... 20)))
            ])
        )
        self.run(spawnAsteroidSequence)
        
        //stars
        let starryEmitter = self.childNode(withName: "starsEmitter") as! SKEmitterNode
        starryEmitter.advanceSimulationTime(15)
    }
    
    // MARK: - Laser spawning (restartable for power-up)
    
    func startLaserSpawning(interval: TimeInterval) {
        // Remove any existing laser spawner before starting a new one
        self.removeAction(forKey: "laserSpawner")
        
        let spawnLaserSequence = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.run(spawnLaser),
                SKAction.wait(forDuration: interval)
            ])
        )
        self.run(spawnLaserSequence, withKey: "laserSpawner")
    }
    
    // MARK: - Power-up activation
    
    func activateRapidFire() {
        isPoweredUp = true
        powerUpLabel.isHidden = false
        
        // Switch to fast laser spawning
        startLaserSpawning(interval: poweredUpLaserInterval)
        
        // Cancel any previous power-up timer so collecting another item resets the 5s
        self.removeAction(forKey: "powerUpTimer")
        
        // After 5 seconds, revert to normal
        let deactivate = SKAction.sequence([
            SKAction.wait(forDuration: 5.0),
            SKAction.run { [weak self] in
                self?.deactivateRapidFire()
            }
        ])
        self.run(deactivate, withKey: "powerUpTimer")
        
        // Pulse the label while active
        powerUpLabel.removeAllActions()
        let pulse = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 0.3),
                SKAction.fadeAlpha(to: 1.0, duration: 0.3)
            ])
        )
        powerUpLabel.run(pulse)
    }
    
    func deactivateRapidFire() {
        isPoweredUp = false
        powerUpLabel.isHidden = true
        powerUpLabel.removeAllActions()
        powerUpLabel.alpha = 1.0
        
        // Revert to normal fire rate
        startLaserSpawning(interval: normalLaserInterval)
    }
    
    // MARK: - Physics contact
    
    func didBegin(_ contact: SKPhysicsContact){
        guard let categoryA = contact.bodyA.node?.physicsBody?.categoryBitMask else {
            return
        }
        guard let categoryB = contact.bodyB.node?.physicsBody?.categoryBitMask else {
            return
        }
        
        if categoryA == laserCategory || categoryB == laserCategory{
            contact.bodyA.node?.removeFromParent()
            contact.bodyB.node?.removeFromParent()
            
            score += 1
            scoreLabel.text = "Score: \(score)"
            if let explosion = SKEmitterNode(fileNamed: "Explosion") {
                                explosion.position = contact.contactPoint
                                self.addChild(explosion)
                                explosion.run(SKAction.sequence([
                                    SKAction.wait(forDuration: 0.1),
                                    SKAction.run {
                                        explosion.particleBirthRate = 0
                                    }
                                ]))
                                explosion.run(SKAction.sequence([
                                    SKAction.wait(forDuration: 1.0),
                                    SKAction.removeFromParent()
                                ]))
                            }
//            spawnEnemy()
            let explosionSound = SKAction.playSoundFileNamed("explosion", waitForCompletion: false)
            run(explosionSound)
        } else if categoryA == itemCategory || categoryB == itemCategory {
            // Player picked up a power-up item
            if categoryA == itemCategory {
                contact.bodyA.node?.removeFromParent()
            } else {
                contact.bodyB.node?.removeFromParent()
            }
            activateRapidFire()
        } else if categoryA == enemyCategory || categoryB == enemyCategory {
            // game over
            self.isPaused = true
            //transition
            if let view = self.view {
                if let scene = SKScene(fileNamed: "TitleScreen") {
                    scene.scaleMode = .aspectFill
                    let transition = SKTransition.doorsCloseHorizontal(withDuration: 2)
                    
                    view.presentScene(scene, transition: transition)
                }
            }
        } else if  categoryA == asteroidCategory || categoryB == asteroidCategory {
            self.isPaused = true
            //transition
            if let view = self.view {
                if let scene = SKScene(fileNamed: "TitleScreen") {
                    scene.scaleMode = .aspectFill
                    let transition = SKTransition.doorsCloseHorizontal(withDuration: 2)
                    
                    view.presentScene(scene, transition: transition)
                }
            }
        }
    }
    
//    func angleBetweenPoints(_ pt1: CGPoint, _ pt2: CGPoint) -> Double {
//        let deltaX = Float(pt1.x - pt2.x)
//        let deltaY = Float(pt1.y - pt2.y)
//        let angle = atan2(deltaY, deltaX)
//        return Double(angle)
//    }
    
    func angle(from origin: CGPoint, to destination: CGPoint) -> Double {
        let deltaX = Double(destination.x - origin.x)
        let deltaY = Double(destination.y - origin.y)
        return atan2(deltaY, deltaX)
    }
    
//    func makeVector(_ r: Double, _ angle: Double) -> CGVector {
//        CGVector(dx: r * CoreGraphics.cos(angle), dy: r * CoreGraphics.sin(angle))
//    }
//    
//    func makePoint(_ r: Double, _ angle: Double) -> CGPoint {
//        CGPoint(x: r * CoreGraphics.cos(angle), y: r * CoreGraphics.sin(angle))
//    }
    
    func polarToPoint(_ r: Double, _ angle: Double) -> CGPoint {
        CGPoint(x: r * cos(angle), y: r * sin(angle))
    }
    
    func polarToVector(_ r: Double, _ angle: Double) -> CGVector {
        let p = polarToPoint(r, angle)
        return CGVector(dx: p.x, dy: p.y)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        isMoving = false
        for t in touches {
            let loc = t.location(in: self)
            if(player.contains(loc) || isMoving){
                self.player.position = loc
                isMoving = true
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let loc = t.location(in: self)
            let angle = angle(from: loc, to: player.position) + .pi / 2
            player.zRotation = CGFloat(angle)
            
            if isMoving || player.contains(loc) {
                isMoving = true
                player.position = loc
            }
        }
    }
    
//    override func update(_ currentTime: TimeInterval) {
//        // Called before each frame is rendered
//        // potentail downside: we can't spawn things fully out of the screne
//        for childNode in self.children {
//            // Don't remove the emitter particles though
//            if let child = childNode as? SKSpriteNode {
//                // if it's off the screen, remove it (enemy, laser)
//                if !child.intersects(self) {
//                    child.removeFromParent()
//                }
//            }
//        }
//    }
    
    func spawnLaser() {
        if let scene = SKScene(fileNamed: "Laser.sks") {
            if let laser = scene.childNode(withName: "laser") {
                // move the laser
                laser.move(toParent: self)
                laser.position = player.position
                laser.physicsBody?.categoryBitMask = laserCategory
                laser.physicsBody?.contactTestBitMask = enemyCategory
                laser.physicsBody?.collisionBitMask = noCategory
                
                laser.zRotation = player.zRotation
                let laserAngle = Double(player.zRotation) + Double.pi / 2.0
                let laserSpeed = 1000.0
                laser.physicsBody?.velocity = polarToVector(laserSpeed, laserAngle)
                
                let laserFadeActions = SKAction.repeatForever(
                    SKAction.sequence([
                        SKAction.fadeOut(withDuration: 1),
                        SKAction.fadeIn(withDuration: 1)
                    ])
                )
                laser.run(laserFadeActions)
                
                let laserSound = SKAction.playSoundFileNamed("laser", waitForCompletion: false)
                run(laserSound)
                
                let despawnLaser = SKAction.sequence([
                    SKAction.wait(forDuration: 2),
                    SKAction.run{laser.removeFromParent()}
                ])
                laser.run(despawnLaser)
                // the nodes are autopaused when transferred to the screne, so we need to unpause it
                laser.isPaused = false
            }
        }
    }
    
    func spawnEnemy() {
        let enemyNode = SKSpriteNode(imageNamed: "enemy_frame1")
        enemyNode.size = CGSize(width: 100, height: 100)
        
        // Animate each enemy with its own animation
        let frame1 = SKTexture(imageNamed: "enemy_frame1")
        let frame2 = SKTexture(imageNamed: "enemy_frame2")
        let frame3 = SKTexture(imageNamed: "enemy_frame3")
        let frame4 = SKTexture(imageNamed: "enemy_frame4")
        let animation = SKAction.repeatForever(
            SKAction.animate(with: [frame1, frame2, frame3, frame4], timePerFrame: 0.1)
        )
        enemyNode.run(animation)
        
        enemyNode.physicsBody = SKPhysicsBody(texture: enemyNode.texture!, size: enemyNode.size)
        
        //let enemyAngle = CGFloat(Int.random(in: 0 ... 360))
        //let enemyDistance = 400.0
        
        let enemyAngle = Double.random(in: 0...(2 * .pi))
        let enemyDistance = self.size.height / 2
        enemyNode.position = polarToPoint(enemyDistance, enemyAngle)
        
        //let halfWidth = Int(self.size.width/2)
        //enemyNode.position = CGPoint(x: enemyDistance * CoreGraphics.cos(enemyAngle), y: enemyDistance * CoreGraphics.sin(enemyAngle))
        
        let angleToPlayer = angle(from: enemyNode.position, to: player.position)
        let enemySpeed = 500.0
        enemyNode.physicsBody?.velocity = polarToVector(enemySpeed, angleToPlayer)
        
//        let vectorToPlayer = CGVector(dx: player.position.x - enemyNode.position.x, dy: player.position.y - enemyNode.position.y)
//        let moveAction = SKAction.applyImpulse(vectorToPlayer, duration: (sqrt(Double(score)) + 1/10))
//        enemyNode.run(moveAction)
        
        //enemyNode.position = CGPoint(x: Int.random(in: -1*halfWidth ... halfWidth), y: Int(self.size.height/2))
        
        let despawn = SKAction.sequence([
            SKAction.wait(forDuration: 10),
            SKAction.removeFromParent()
        ])
        
        enemyNode.run(despawn)
        enemyNode.physicsBody?.categoryBitMask = enemyCategory
        enemyNode.physicsBody?.contactTestBitMask = playerCategory | laserCategory
        enemyNode.physicsBody?.collisionBitMask = noCategory
        enemyNode.physicsBody?.friction = 0
        
        enemyNode.isPaused = false

        self.addChild(enemyNode)
    }
    
    func spawnItem() {
        let itemNode = SKSpriteNode(imageNamed: "item0")
        itemNode.size = CGSize(width: 100, height: 100)
        
        let halfHeight = Int(self.size.height/2)
        itemNode.position = CGPoint(x: Int(self.size.width/2), y: Int.random(in: -1*halfHeight ... 0))
        itemNode.physicsBody = SKPhysicsBody(rectangleOf: itemNode.size)
        itemNode.physicsBody?.velocity = CGVectorMake(-300, 0)
        itemNode.physicsBody?.categoryBitMask = itemCategory
        itemNode.physicsBody?.contactTestBitMask = playerCategory
        itemNode.physicsBody?.collisionBitMask = noCategory
        itemNode.physicsBody?.friction = 0
        
        self.addChild(itemNode)
    }
    
    func spawnAsteroid() {
        let asteroidNode = SKSpriteNode(imageNamed: "asteroid")
        asteroidNode.size = CGSize(width: 100, height: 100)
        
        let halfWidth = Int(self.size.width/2)
        asteroidNode.position = CGPoint(x: Int.random(in: -1*halfWidth ... halfWidth), y: Int(self.size.height/2))
        asteroidNode.physicsBody = SKPhysicsBody(texture: asteroidNode.texture!, size: asteroidNode.size)
        asteroidNode.physicsBody?.velocity = CGVectorMake(0, CGFloat(Int.random(in:  -500 ... -100)))
        asteroidNode.physicsBody?.categoryBitMask = asteroidCategory
        asteroidNode.physicsBody?.contactTestBitMask = playerCategory
        asteroidNode.physicsBody?.collisionBitMask = noCategory
        asteroidNode.physicsBody?.friction = 0
        
        self.addChild(asteroidNode)
    }
    
}
