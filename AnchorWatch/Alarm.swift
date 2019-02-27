import AVFoundation
import MediaPlayer

class Alarm {
    var player: AVAudioPlayer?
    let volumeView = MPVolumeView(frame: CGRect(x: -CGFloat.greatestFiniteMagnitude, y: 0.0, width: 0.0, height: 0.0))

    init() {
        // Ensure audio plays even if in silent mode
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers, .defaultToSpeaker])
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
        volumeView.setVolume(1.0)
    }

    func start() {
        volumeView.setVolume(1.0)
        player?.play()
    }


    func stop() {
        player?.stop()
    }
}
