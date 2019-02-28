
import AVFoundation
import MediaPlayer

class Alarm {
    let audioSession = AVAudioSession.sharedInstance()
    var player: AVAudioPlayer?
    let volumeView = MPVolumeView(frame: CGRect(x: -CGFloat.greatestFiniteMagnitude, y: 0.0, width: 0.0, height: 0.0))
    var isActive = false

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(volumeDidChange(_:)), name: .volumeDidChange, object: nil)

        // Ensure audio plays even if in silent mode
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
        } catch {
            print("Setting category to AVAudioSessionCategoryPlayback failed", error.localizedDescription)
        }

        let fileURL = Bundle.main.path(forResource: "alarm", ofType: "mp3")
        do {
            player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: fileURL!))
        } catch let error {
            print("Can't play the audio file failed with an error \(error.localizedDescription)")
        }
        player?.numberOfLoops = -1
    }

    func start() {
        guard !isActive else { return }

        volumeView.setVolume(1.0)

        do {
            try audioSession.setActive(true, options: [])
        } catch {
            print("Failed to activate audio session", error.localizedDescription)
        }

        player?.play()
        startVibrating()

        isActive = true
    }


    func stop() {
        guard isActive else { return }

        print("Stopping alarm")

        stopVibrating()
        player?.stop()

        do {
            try audioSession.setActive(false, options: [])
        } catch {
            print("Failed to deactivate audio session", error.localizedDescription)
        }

        isActive = false
    }

    @objc private func volumeDidChange(_ notification:Notification) {
        // Stop the alarm when volume button pressed
        // Note: that this only works if the volume is turned below 1.0. Otherwise, setting the volume to 1.0 when
        // starting the alarm wil also trigger this volume press.
        if let volume = notification.userInfo?["AVSystemController_AudioVolumeNotificationParameter"] as? Float {
            print("output volume", volume, audioSession.outputVolume, notification)

            if isActive && volume < 1.0 {
                print("Stopping alarm with volume button")
                self.stop()
            }
        }
    }

    func startVibrating() {
        // Vibrate once
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))

        // Repeatedly vibrate after first one finishes
        AudioServicesAddSystemSoundCompletion(SystemSoundID(kSystemSoundID_Vibrate), nil, nil, { (_:SystemSoundID, _:UnsafeMutableRawPointer?) -> Void in

            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200), execute: {
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            })

        }, nil)
    }

    func stopVibrating() {
        AudioServicesRemoveSystemSoundCompletion(kSystemSoundID_Vibrate)
    }
}
