//
//  ViewController.swift
//  ArDancing
//
//  Created by Kiro on 12/10/18.
//  Copyright © 2018 Kiro. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    var animations = [String: CAAnimation]()
    let updateQueue = DispatchQueue(label: "com.kiro.updateQueue")
    var objectNode:SCNNode!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleGesture(gesture:)))
        self.sceneView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    @objc func handleGesture(gesture:UITapGestureRecognizer) {
        let tapLocation = gesture.location(in: sceneView)
        let hitTestResults = sceneView.hitTest(tapLocation, types: .estimatedHorizontalPlane)
        guard let hitTestResult = hitTestResults.first else { return }
        loadAnimations(hitTestResult:hitTestResult)

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        // Run the view's session
        sceneView.session.run(configuration)

    }
    
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        updateQueue.async {
            guard let planeAnchor = anchor as? ARPlaneAnchor , self.objectNode != nil else { return }
            self.adjustOntoPlaneAnchor(planeAnchor, using: node)
        }
    }
    
    
    func loadAnimations (hitTestResult:ARHitTestResult) {
        guard objectNode == nil else { return }
        // Load the character in the idle animation
        let idleScene = SCNScene(named: "art.scnassets/christmas.dae")!
        // This node will be parent of all the animation models
        objectNode = SCNNode()
        // Add all the child nodes to the parent node
        for child in idleScene.rootNode.childNodes {
            objectNode.addChildNode(child)
        }
        let merryChristmasScene = SCNScene(named: "art.scnassets/merryChristmas.dae")!
        let merryChristmasNode = SCNNode()
        merryChristmasNode.position = SCNVector3(0, -0.9, -2.05)

        for child in merryChristmasScene.rootNode.childNodes {
            merryChristmasNode.addChildNode(child)
        }
        objectNode.addChildNode(merryChristmasNode)
        
        // Set up some properties
        let transform = hitTestResult.worldTransform
        let thirdColumn = transform.columns.3
        objectNode.position = SCNVector3(thirdColumn.x, thirdColumn.y, thirdColumn.z )
        objectNode.scale = SCNVector3(0.09, 0.09, 0.09)
        
        // Add the node to the scene
        sceneView.scene.rootNode.addChildNode(objectNode)
        
        let sceneURL = Bundle.main.url(forResource: "art.scnassets/christmas", withExtension: "dae")
        let sceneSource = SCNSceneSource(url: sceneURL!, options: nil)
        
        if let animationObject = sceneSource?.entryWithIdentifier("Dancing", withClass: CAAnimation.self) {
            // The animation will only play once
            animationObject.repeatCount = 1
            // To create smooth transitions between animations
            animationObject.fadeInDuration = CGFloat(1)
            animationObject.fadeOutDuration = CGFloat(0.5)
            
            sceneView.scene.rootNode.addAnimation(animationObject, forKey: "Dancing")
            
        }
        
        let particle = SCNParticleSystem(named: "rainingSnow.scnp", inDirectory: nil)!
        let particleNode = SCNNode()
        particleNode.eulerAngles.x = .pi / 2
        particleNode.position = SCNVector3(thirdColumn.x, thirdColumn.y, thirdColumn.z)

        self.sceneView.scene.rootNode.addChildNode(particleNode)
        particleNode.addParticleSystem(particle)
        
        
        let audioSource = SCNAudioSource(fileNamed: "jingle.mp3")!
        
        audioSource.loops = true
        audioSource.load()
        objectNode.addAudioPlayer(SCNAudioPlayer(source: audioSource))

    }
    
    func adjustOntoPlaneAnchor(_ anchor: ARPlaneAnchor, using node: SCNNode) {
        
        // Get the object's position in the plane's coordinate system.
        let planePosition = node.convertPosition(objectNode.position, from:  objectNode.parent)
        
        // Check that the object is not already on the plane.
        guard planePosition.y != 0 else { return }
        
        // Add 10% tolerance to the corners of the plane.
        let tolerance: Float = 0.1
        
        let minX: Float = anchor.center.x - anchor.extent.x / 2 - anchor.extent.x * tolerance
        let maxX: Float = anchor.center.x + anchor.extent.x / 2 + anchor.extent.x * tolerance
        let minZ: Float = anchor.center.z - anchor.extent.z / 2 - anchor.extent.z * tolerance
        let maxZ: Float = anchor.center.z + anchor.extent.z / 2 + anchor.extent.z * tolerance
        
        guard (minX...maxX).contains(planePosition.x) && (minZ...maxZ).contains(planePosition.z) else {
            return
        }
        
        // Move onto the plane if it is near it (within 5 centimeters).
        let verticalAllowance: Float = 0.05
        let epsilon: Float = 0.001 // Do not update if the difference is less than 1 mm.
        let distanceToPlane = abs(planePosition.y)
        if distanceToPlane > epsilon && distanceToPlane < verticalAllowance {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = CFTimeInterval(distanceToPlane * 500) // Move 2 mm per second.
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            objectNode.position.y = anchor.transform.columns.3.y
            SCNTransaction.commit()
        }
    }
}
