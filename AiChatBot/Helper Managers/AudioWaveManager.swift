//
//  AudioWaveManager.swift
//  ChatBot
//
//  Created by Simra Syed on 03/10/2025.
//

import AVFoundation
import SwiftUI
import Combine

class AudioRecorder: NSObject, ObservableObject {
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    
    @Published var isRecording = false
    @Published var levels: [CGFloat] = Array(repeating: 0, count: 40)
    
    var lastRecordingURL: URL?

    func requestAndStart() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                if granted {
                    self.startRecording()
                }
                else {
                    print("⚠️ Permission denied")
                }
            }
        }
    }


    private func startRecording() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("temp.m4a")
        lastRecordingURL = url
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.record()
            isRecording = true
            
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                self.recorder?.updateMeters()
                if let power = self.recorder?.averagePower(forChannel: 0) {
                    let level = self.normalize(power: power)
                    DispatchQueue.main.async {
                        self.levels.removeFirst()
                        self.levels.append(level)
                    }
                }
            }
        } catch {
            print("⚠️ Recorder error:", error)
        }
    }
    
    func stop() {
        recorder?.stop()
        isRecording = false
        timer?.invalidate()
        timer = nil
    }
    
    private func normalize(power: Float) -> CGFloat {
        let minDb: Float = -80
        return CGFloat((power - minDb) / -minDb)
    }
}


struct WaveformView: View {
    var levels: [CGFloat]
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(levels.indices, id: \.self) { i in
                Capsule()
                    .fill(Color.gray)
                    .frame(width: 3, height: max(4, levels[i] * 80))
            }
        }
        .animation(.easeOut(duration: 0.1), value: levels)
    }
}
