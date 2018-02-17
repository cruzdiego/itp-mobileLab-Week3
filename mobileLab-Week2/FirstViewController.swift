//
//  FirstViewController.swift
//  mobileLab-Week3
//
//  Created by Diego Cruz on 2/7/18.
//  Copyright © 2018 Diego Cruz. All rights reserved.
//

import UIKit
import CoreMotion

class FirstViewController: UIViewController {
    //MARK: - Properties
    //MARK: Public
    //IBOutlets
    
    //*** Orientations ***
    @IBOutlet weak var orientation1ImageView: UIImageView?
    @IBOutlet weak var orientation2ImageView: UIImageView?
    @IBOutlet weak var orientation3ImageView: UIImageView?
    @IBOutlet weak var orientation4ImageView: UIImageView?
    @IBOutlet weak var orientation5ImageView: UIImageView?
    @IBOutlet weak var orientation6ImageView: UIImageView?
    public var orientationImageViews: [UIImageView?] {
        return [orientation1ImageView,orientation2ImageView,orientation3ImageView,orientation4ImageView,orientation5ImageView,orientation6ImageView]
    }
    //********************
    
    //*** Overlays ***
    @IBOutlet weak var tryAgainOverlayView:UIView?
    @IBOutlet weak var lockedOverlayView: UIView?
    @IBOutlet weak var unlockedOverlayView: UIView?
    //****************
    
    //MARK: Private
    //Objects
    private let correctPasscode:[Orientation] = [.landscapeRight, .landscapeRight, .landscapeRight, .landscapeRight, .landscapeRight, .landscapeRight]
    private var attemptedPasscode = [Orientation](){
        didSet{
            didSetAttemptedPasscode()
        }
    }
    private var currentState: State = .inputing {
        didSet {
            didSetCurrentState()
        }
    }
    private var totalAttempts = 0
    private let motionManager = CMMotionManager()
    private let motionOperationqueue = OperationQueue()
    private var lastOrientationRegistered: Date?
    
    //Enums
    private enum Orientation: String {
        case noOrientation = "noOrientationIcon"
        case portrait = "portraitIcon"
        case landscapeRight = "landscapeRightIcon"
        case landscapeLeft = "landscapeLeftIcon"
        case portraitUpsideDown = "portraitUpsideDownIcon"
        
        var image: UIImage? {
            return UIImage(named:self.rawValue)
        }
    }
    private enum State {
        case inputing
        case unlocked
        case locked
        case tryAgain
    }
    
    //MARK: - Public methods
    //MARK: View events
    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        reset()
    }
    
    //MARK: - Private methods
    //MARK: didSet
    private func didSetAttemptedPasscode() {
        refreshUI()
    }
    private func didSetCurrentState() {
        refreshUI()
        
        switch currentState {
        case .tryAgain:
            perform(after: 2.0, closure: {
                self.reset()
            })
        case .unlocked:
            perform(after: 2.0, closure: {
                self.performSegue(withIdentifier: "unlockSegue", sender: self)
            })
            
        default:
            return
        }
    }
    
    //MARK: Configure
    private func configure() {
        refreshUI()
        configureMotion()
    }
    
    //MARK: UI
    private func refreshUI() {
        //*** Orientations ***
        func refreshOrientationsUI() {
            for (index,imageView) in orientationImageViews.enumerated() {
                guard attemptedPasscode.count > index else {
                    imageView?.image = Orientation.noOrientation.image
                    continue
                }
                
                imageView?.image = attemptedPasscode[index].image
            }
        }
        //********************
        
        //*** Overlays ***
        func refreshOverlaysUI() {
            tryAgainOverlayView?.isHidden = currentState != .tryAgain
            lockedOverlayView?.isHidden = currentState != .locked
            unlockedOverlayView?.isHidden = currentState != .unlocked
        }
        //****************
        
        //
        refreshOrientationsUI()
        refreshOverlaysUI()
    }
    
    //MARK: Util
    private func reset() {
        self.clearAttemptedPasscode()
        self.currentState = .inputing
    }
    
    private func isPasscodeCorrect() -> Bool {
        return correctPasscode == attemptedPasscode
    }
    
    private func input(orientation: Orientation) {
        //*** is AttemptedCode Full ***
        func isAttemptepCodeFull() -> Bool{
            return attemptedPasscode.count == 6
        }
        //*****************************
        
        //*** got MaxAttempts ***
        func gotMaxAttempts() -> Bool {
            return totalAttempts >= 3
        }
        //***********************
        
        //
        attemptedPasscode.append(orientation)
        guard isAttemptepCodeFull() else {
            return
        }
        
        totalAttempts += 1
        if isPasscodeCorrect() {
            currentState = .unlocked
        } else {
            currentState = gotMaxAttempts() ? .locked : .tryAgain
        }
    }
    
    private func clearAttemptedPasscode() {
        attemptedPasscode.removeAll()
    }
    
    private func perform(after: TimeInterval, closure:@escaping ()->()) {
        let timeAfter = DispatchTime.now() + after
        DispatchQueue.main.asyncAfter(deadline: timeAfter, execute: closure)
    }
    
    //MARK: Motion
    private func configureMotion() {
        guard motionManager.isDeviceMotionAvailable else {
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 0.02
        motionManager.startDeviceMotionUpdates(to: motionOperationqueue) {
            [weak self] (data: CMDeviceMotion?, error: Error?) in
            self?.handle(motion: data)
        }
    }
    
    private func handle(motion: CMDeviceMotion?) {
        //*** didShake ***
        func didShake() -> Bool{
            guard   let acelerationY = motion?.userAcceleration.y,
                    let acelerationX = motion?.userAcceleration.x else {
                return false
            }
            
            if fabs(acelerationY) > 1.0 || fabs(acelerationX) > 1.0 {
                return true
            }
            
            return false
        }
        //****************
        
        //*** Current Orientation ***
        func currentOrientation() -> Orientation {
            guard let gravity = motion?.gravity else {
                return .noOrientation
            }
            
            //Credits: https://stackoverflow.com/questions/27718123/detect-actual-orientation-of-the-device-when-the-orientation-lock-is-enabled-io
            if fabs(gravity.x) > fabs(gravity.y) { //Landscape
                if gravity.x >= 0 { // Left
                    return .landscapeLeft
                } else{ // Right
                    return .landscapeRight
                }
            }
            else{ // Portrait
                if gravity.y >= 0 { //upsideDown
                    return .portraitUpsideDown
                }
                else{ //up
                    return .portrait
                }
            }
        }
        //***************************
        
        //
        if didShake() {
            let lastDate = lastOrientationRegistered ?? Date.distantPast
            
            if  fabs(lastDate.timeIntervalSinceNow) <= 0.5 {
                return
            }
            
            lastOrientationRegistered = Date()
            OperationQueue.main.addOperation {
                print("Orientation: \(currentOrientation().rawValue)")
                self.input(orientation: currentOrientation())
            }
        }
    }
}

