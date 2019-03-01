// Copyright (c) 2018 SiddharthPaneri
// License: MIT
// https://github.com/siddharth-paneri/Resizable-Geofence

import UIKit
import UIKit.UIGestureRecognizerSubclass

typealias RecognizerEvent = (Set<UITouch>, UIEvent) -> Void


class GeofenceGestureRecognizer: UIGestureRecognizer {

    var touchesBeganCallback : (Set<UITouch>, UIEvent)->Void = {_,_ in }
    var touchesMovedCallback : RecognizerEvent = {_,_ in }
    var touchesEndedCallback : RecognizerEvent = {_,_ in }
    
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        self.touchesBeganCallback(touches, event)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        self.touchesMovedCallback(touches, event)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        self.touchesEndedCallback(touches, event)
    }
    
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
    }
    
    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
}
