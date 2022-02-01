//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PVControllerManager.swift
//  Provenance
//
//  Created by James Addyman on 19/09/2015.
//  Copyright © 2015 James Addyman. All rights reserved.
//

import Foundation
import GameController
import PVLibrary
import PVSupport
#if !targetEnvironment(macCatalyst) && !os(macOS) && canImport(SteamController)
import SteamController
#endif

extension Notification.Name {
    static let PVControllerManagerControllerReassigned = Notification.Name("PVControllerManagerControllerReassignedNotification")
}

typealias iCadeListenCompletion = () -> Void

#if targetEnvironment(simulator)
    let isSimulator = true
#else
    let isSimulator = false
#endif

final class PVControllerManager: NSObject {
    var allLiveControllers: [Int: GCController] {
        var allLiveControllers = [Int: GCController]()
        if let player1 = player1 {
            allLiveControllers[1] = player1
        }
        if let player2 = player2 {
            allLiveControllers[2] = player2
        }
        if let player3 = player3 {
            allLiveControllers[3] = player3
        }
        if let player4 = player4 {
            allLiveControllers[4] = player4
        }

        return allLiveControllers
    }

    private(set) var player1: GCController? {
        didSet {
            if player1 != oldValue {
                setController(player1, toPlayer: 1)
            }
        }
    }

    private(set) var player2: GCController? {
        didSet {
            if player2 != oldValue {
                setController(player2, toPlayer: 2)
            }
        }
    }

    private(set) var player3: GCController? {
        didSet {
            if player3 != oldValue {
                setController(player3, toPlayer: 3)
            }
        }
    }

    private(set) var player4: GCController? {
        didSet {
            if player4 != oldValue {
                setController(player4, toPlayer: 4)
            }
        }
    }

    var iCadeController: PViCadeController?
    var keyboardController: GCController?
    var hasControllers: Bool {
        return player1 != nil || player2 != nil || player3 != nil || player4 != nil
    }

    static let shared: PVControllerManager = PVControllerManager()

    func listenForICadeControllers(window: UIWindow?, preferredPlayer: Int = -1, completion: iCadeListenCompletion? = nil) {
        iCadeController?.controllerPressedAnyKey = { [unowned self] (_) -> Void in
            var player = 0

            var controllerReplacing: GCController?
            if preferredPlayer == -1 {
                #if os(tvOS)
                    if self.player1 == nil || self.player1?.microGamepad != nil {
                        player = 1
                    } else if self.player2 == nil || self.player2?.microGamepad != nil {
                        player = 2
                    } else if self.player3 == nil || self.player3?.microGamepad != nil {
                        player = 3
                    } else if self.player4 == nil || self.player4?.microGamepad != nil {
                        player = 1
                    } else {
                        completion?()
                        return
                    }
                #else
                    if self.player1 == nil {
                        player = 1
                    } else if self.player2 == nil {
                        player = 2
                    } else if self.player3 == nil {
                        player = 3
                    } else if self.player4 == nil {
                        player = 1
                    } else {
                        completion?()
                        return
                    }
                #endif
            } else {
                player = preferredPlayer

                controllerReplacing = self.allLiveControllers[preferredPlayer]
            }

            self.setController(self.iCadeController, toPlayer: player)
            self.stopListeningForICadeControllers()
            NotificationCenter.default.post(name: .GCControllerDidConnect, object: PVControllerManager.shared.iCadeController)

            if let controllerReplacing = controllerReplacing {
                self.assign(controllerReplacing)
            }

            completion?()
        }
        iCadeController?.reader.listen(to: window)
    }

    func stopListeningForICadeControllers() {
        iCadeController?.controllerPressedAnyKey = nil
        iCadeController?.reader.listen(to: nil)
    }

    override init() {
        super.init()
        
        if #available(iOS 14.0, tvOS 14.0, *) {
            NotificationCenter.default.addObserver(self, selector: #selector(PVControllerManager.handleKeyboardConnect(_:)), name: .GCKeyboardDidConnect, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(PVControllerManager.handleKeyboardDisconnect(_:)), name: .GCKeyboardDidDisconnect, object: nil)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(PVControllerManager.handleControllerDidConnect(_:)), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVControllerManager.handleControllerDidDisconnect(_:)), name: .GCControllerDidDisconnect, object: nil)
        UserDefaults.standard.addObserver(self as NSObject, forKeyPath: "kICadeControllerSettingKey", options: .new, context: nil)
        // automatically assign the first connected controller to player 1
        // prefer gamepad or extendedGamepad over a microGamepad
        assignControllers()
        setupICade()
    }

    func isAssigned(_ controller: GCController) -> Bool {
        return allLiveControllers.contains(where: { (_, existingController) -> Bool in
            controller == existingController
        })
    }

    func index(forController controller: GCController) -> Int? {
        if let (index, _) = allLiveControllers.first(where: { (_, existingController) -> Bool in
            controller == existingController
        }) {
            return index
        } else {
            return nil
        }
    }

    func setupICade() {
        if iCadeController == nil {
            let selectediCadeController = PVSettingsModel.shared.myiCadeControllerSetting
            if selectediCadeController != .disabled {
                iCadeController = selectediCadeController.createController()
                if iCadeController != nil {
                    listenForICadeControllers()
                } else {
                    ELOG("Failed to create iCade controller")
                }
            }
        }
    }

    func resetICadeController() {
        if iCadeController != nil {
            stopListeningForICadeControllers()
            iCadeController = nil
        }

        setupICade()
    }

    @objc func handleControllerDidConnect(_ note: Notification?) {
        guard let controller = note?.object as? GCController else {
            ELOG("Object wasn't a GCController")
            return
        }
        
        // ignore the bogus controller in the simulator
        if isSimulator && (controller.vendorName == nil || controller.vendorName == "Gamepad") {
            return
        }

#if !targetEnvironment(macCatalyst) && canImport(SteamController)
        if let steamController = controller as? SteamController {
            #if os(tvOS)
            // PVEmulatorViewController will set to controller mode if game is running
            steamController.steamControllerMode = .keyboardAndMouse
            #endif
            // combinations for mode toggles
            steamController.steamButtonCombinationHandler = { (controller, button, down) in
                if down {
                    self.handleSteamControllerCombination(controller: controller, button: button)
                }
            }
        }
#endif
        ILOG("Controller connected: \(controller.vendorName ?? "No Vendor")")
        assign(controller)
    }

    @objc func handleControllerDidDisconnect(_ note: Notification?) {
        guard let controller = note?.object as? GCController else {
            ELOG("Object wasn't a GCController")
            return
        }

        ILOG("Controller disconnected: \(controller.vendorName ?? "No Vendor")")

        if controller == player1 {
            player1 = nil
        } else if controller == player2 {
            player2 = nil
        } else if controller == player3 {
            player3 = nil
        } else if controller == player4 {
            player4 = nil
        }

        var assigned = false
        if controller is PViCade8BitdoController || controller is PViCade8BitdoZeroController {
            // For 8Bitdo, we set to listen again for controllers after disconnecting
            // so we can detect when they connect again
            if iCadeController != nil {
                listenForICadeControllers()
            }
        } else {
            // Reassign any controller which we are unassigned
            // (we don't do this for 8Bitdo, instead we listen for them to connect)
            assigned = assignControllers()
        }
        if !assigned {
            NotificationCenter.default.post(name: NSNotification.Name.PVControllerManagerControllerReassigned, object: self)
        }
    }
    
    @available(iOS 14.0, tvOS 14.0, *)
    @objc func handleKeyboardConnect(_ note: Notification?) {
        if let controller = GCKeyboard.coalesced?.createController() {
            keyboardController = controller
            NotificationCenter.default.post(name:.GCControllerDidConnect, object: controller)
        }
    }
    
    @available(iOS 14.0, tvOS 14.0, *)
    @objc func handleKeyboardDisconnect(_ note: Notification?) {
        if let controller = keyboardController {
            keyboardController = nil
            NotificationCenter.default.post(name:.GCControllerDidDisconnect, object:controller)
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "kICadeControllerSettingKey" {
            setupICade()
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    func listenForICadeControllers() {
        listenForICadeControllers(window: nil) { () -> Void in }
    }

#if !targetEnvironment(macCatalyst) && canImport(SteamController)
    func handleSteamControllerCombination(controller: SteamController, button: SteamControllerButton) {
        switch button {
        case .leftTrackpadClick:
            // toggle left trackpad click to input
            controller.steamLeftTrackpadRequiresClick = !controller.steamLeftTrackpadRequiresClick
        case .rightTrackpadClick:
            // toggle right trackpad click to input
            controller.steamRightTrackpadRequiresClick = !controller.steamRightTrackpadRequiresClick
        case .stick:
            // toggle stick mapping between d-pad and left stick
            if controller.steamThumbstickMapping == .leftThumbstick {
                controller.steamThumbstickMapping = .dPad
                controller.steamLeftTrackpadMapping = .leftThumbstick
            } else {
                controller.steamThumbstickMapping = .leftThumbstick
                controller.steamLeftTrackpadMapping = .dPad
            }
        default:
            return
        }
    }
#endif
    // MARK: - Controllers assignment

    func setController(_ controller: GCController?, toPlayer player: Int) {
        if let controller = controller, let currentIndex = index(forController: controller), currentIndex != player {
            setController(nil, toPlayer: currentIndex)
        }

        #if TARGET_OS_TV
            // check if controller is iCade, otherwise crash
            if !((controller is PViCadeController) && controller?.microGamepad) {
                controller?.microGamepad?.allowsRotation = true
                controller?.microGamepad?.reportsAbsoluteDpadValues = true
            }
        #endif
        controller?.playerIndex = GCControllerPlayerIndex(rawValue: player - 1)!
        // TODO: keep an array of players/controllers we support more than 2 players
        if player == 1 {
            player1 = controller
        } else if player == 2 {
            player2 = controller
        } else if player == 3 {
            player3 = controller
        } else if player == 4 {
            player4 = controller
        }

        if let controller = controller {
            ILOG("Controller [\(controller.vendorName ?? "No Vendor")] assigned to player \(player)")
        }
    }

    func controller(forPlayer player: Int) -> GCController? {
        return allLiveControllers[player]
    }
    
    // a filtered and augmented version of CGControllers.controllers()
    func controllers() -> [GCController] {
        var controllers = GCController.controllers()
        if let aController = iCadeController {
            controllers.append(aController)
        }
        else if let aController = keyboardController {
            controllers.append(aController)
        }
        // ignore the bogus controller in the simulator
        if isSimulator {
            controllers = controllers.filter({$0.vendorName != nil})
        }
        return controllers
    }

    @discardableResult
    func assignControllers() -> Bool {
        var assigned = false
        controllers().forEach { controller in
            if !allLiveControllers.contains(where: { (_, existingController) -> Bool in
                controller == existingController
            }) {
                assigned = assigned || assign(controller)
            }
        }

        return assigned
    }

    @discardableResult
    func assign(_ controller: GCController) -> Bool {
        if isAssigned(controller) {
            return false
        }

        ILOG("Assign controller \(controller.vendorName ?? "nil")")
        // Assign the controller to the first player without a controller assigned, or
        // if this is an extended controller, replace the first controller which is not extended (the Siri remote on tvOS).
        for i in 1 ... 4 {
            let previouslyAssignedController: GCController? = self.controller(forPlayer: i)
            let newGamepadNotRemote = !(controller.isRemote || controller.isKeyboard)
            let previousGamepadNotRemote = !((previouslyAssignedController?.isRemote == true) || (previouslyAssignedController?.isKeyboard == true))

            // Skip making duplicate
            if let previouslyAssignedController = previouslyAssignedController, previouslyAssignedController == controller {
                continue
            }

            if previouslyAssignedController == nil || (newGamepadNotRemote && !previousGamepadNotRemote) {
                setController(controller, toPlayer: i)
                // Move the previously assigned controller to another player
                if let previouslyAssignedController = previouslyAssignedController {
                    ILOG("Controller #\(i) \(previouslyAssignedController.vendorName ?? "nil") being reassigned")
                    assign(previouslyAssignedController)
                }
                NotificationCenter.default.post(name: NSNotification.Name.PVControllerManagerControllerReassigned, object: self)
                return true
            }
        }
        return false
    }

#if !targetEnvironment(macCatalyst) && canImport(SteamController)
    func setSteamControllersMode(_ mode: SteamControllerMode) {
        for controller in SteamControllerManager.shared().controllers {
            controller.steamControllerMode = mode
        }
    }
#endif
    
// MARK: - Controller User Interaction (ie use controller to drive UX)

#if os(iOS)
    //
    // make a *cheap* *simple* version of the FocusSystem
    // get controller input and turn it into button presses menu,select,up,down,left,right
    // NOTE we assume no cores or other parts of PV is using valueChangedHandler
    // TODO: what happens if a controller get added/removed while controllerUserInteractionEnabled == true
    //
    private var current_button_state = GCExtendedGamepad.ButtonState()
    
    var controllerUserInteractionEnabled: Bool = false {
        didSet {
            if controllerUserInteractionEnabled {
                controllers().forEach { controller in
                    var current_state = GCExtendedGamepad.ButtonState()
                    controller.extendedGamepad?.valueChangedHandler = { gamepad, element in
                        let state = gamepad.readButtonState()
                        let changed_state = current_state.symmetricDifference(state)
                        let changed_state_pressed = changed_state.intersection(state)
                        
                        for button in changed_state_pressed {
                            // send button press up the responder chain
                            UIApplication.shared.sendAction(#selector(ControllerButtonPress.controllerButtonPress), to: nil, from:button, for: nil)
                        }
                        // remember state so we can only send changes
                        current_state = state
                    }
                }
            }
            else {
                controllers().forEach { controller in
                    controller.extendedGamepad?.valueChangedHandler = nil
                }
            }
        }
    }
#endif
    
}

// MARK: - ControllerButtonPress protocol

@objc protocol ControllerButtonPress {
    func controllerButtonPress(_ type:Any?)
}

// MARK: - Read Controller UX buttons

private extension GCExtendedGamepad {
    
    typealias ButtonState = Set<UIPress.PressType>
    
    func readButtonState() -> ButtonState {
        var state = ButtonState()
        
        if buttonA.isPressed {state.formUnion([.select])}
        if buttonB.isPressed {state.formUnion([.menu])}
        
        for pad in [dpad, leftThumbstick, rightThumbstick] {
            if pad.up.isPressed {state.formUnion([.upArrow])}
            if pad.down.isPressed {state.formUnion([.downArrow])}
            if pad.left.isPressed {state.formUnion([.leftArrow])}
            if pad.right.isPressed {state.formUnion([.rightArrow])}
        }

        return state
    }
}

// MARK: - UIPress.PressType CustomStringConvertible

extension UIPress.PressType : CustomStringConvertible {
    public var description : String {
        switch self {
        case .upArrow:      return "UP"
        case .downArrow:    return "DOWN"
        case .leftArrow:    return "LEFT"
        case .rightArrow:   return "RIGHT"
        case .select:       return "SELECT"
        case .menu:         return "MENU"
        case .playPause:    return "PLAY/PAUSE"
        default:            return "[[\(rawValue)]]"
        }
    }
}


// MARK: - Controller type detection

extension GCController {
    var isRemote: Bool {
        return self.extendedGamepad == nil && self.microGamepad != nil
    }
    var isKeyboard: Bool {
        if #available(iOS 14.0, tvOS 14.0, *) {
            return isSnapshot && vendorName?.contains("Keyboard") == true
        } else {
            return false
        }
    }
}

// MARK: - Keyboard Controller

//
// create a GCController that turns a keyboard into a controller
//
// [ESC:B]
// [TILDE:MENU] [1:OPTIONS]
//
// [TAB:L1]    [Q:X]     [W:UP]   [E:Y]     [R:R1]
//             [A:LEFT]  [S:DOWN] [D:RIGHT] [F:B]    [RETURN:A]
// [LSHIFT:L2]                              [V:R2]                     [UP]
//                       [SPACE:A]                             [LEFT] [DOWN] [RIGHT]
//
@available(iOS 14.0, tvOS 14.0, *)
extension GCKeyboard {
    func createController() -> GCController? {
        guard let keyboard = self.keyboardInput else {return nil}
        
        let controller = GCController.withExtendedGamepad()
        let gamepad = controller.extendedGamepad!
        
        controller.setValue(self.vendorName ?? "Keyboard", forKey: "vendorName")

        keyboard.keyChangedHandler = {(keyboard, button, key, pressed) -> Void in
            //print("\(button) \(key) \(pressed)")
            
            func isPressed(_ code:GCKeyCode) -> Bool {
                return keyboard.button(forKeyCode:code)?.isPressed ?? false
            }
            
            // DPAD
            let dpad_x:Float = isPressed(.rightArrow) ? 1.0 : isPressed(.leftArrow) ? -1.0 : 0.0
            let dpad_y:Float = isPressed(.upArrow)    ? 1.0 : isPressed(.downArrow) ? -1.0 : 0.0
            gamepad.dpad.setValueForXAxis(dpad_x, yAxis:dpad_y)

            // WASD
            let left_x:Float = isPressed(.keyD) ? 1.0 : isPressed(.keyA) ? -1.0 : 0.0
            let left_y:Float = isPressed(.keyW) ? 1.0 : isPressed(.keyS) ? -1.0 : 0.0
            gamepad.leftThumbstick.setValueForXAxis(left_x, yAxis:left_y)

            // ABXY
            gamepad.buttonA.setValue(isPressed(.spacebar) || isPressed(.returnOrEnter) ? 1.0 : 0.0)
            gamepad.buttonB.setValue(isPressed(.keyF) || isPressed(.escape) ? 1.0 : 0.0)
            gamepad.buttonX.setValue(isPressed(.keyQ) ? 1.0 : 0.0)
            gamepad.buttonY.setValue(isPressed(.keyE) ? 1.0 : 0.0)

            // L1, L2
            gamepad.leftShoulder.setValue(isPressed(.tab) ? 1.0 : 0.0)
            gamepad.leftTrigger.setValue(isPressed(.leftShift) ? 1.0 : 0.0)

            // R1, R2
            gamepad.rightShoulder.setValue(isPressed(.keyR) ? 1.0 : 0.0)
            gamepad.rightTrigger.setValue(isPressed(.keyV) ? 1.0 : 0.0)

            // MENU, OPTIONS
            gamepad.buttonMenu.setValue(isPressed(.graveAccentAndTilde) ? 1.0 : 0.0)
            gamepad.buttonOptions?.setValue(isPressed(.one) ? 1.0 : 0.0)
            
            // the system does not call this handler in setValue, so call it with the dpad
            gamepad.valueChangedHandler?(gamepad, gamepad.dpad)
        }
        
        return controller
    }
}
