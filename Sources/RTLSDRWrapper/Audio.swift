//
//  Untitled.swift
//  RTLSDRWrapper
//
//  Created by Connor Gibbons  on 4/21/25.
//
import AVFoundation

func createAudioPCMBuffer(samples: [Float], sampleRate: Double) -> AVAudioPCMBuffer? {
    let frameCount = AVAudioFrameCount(int: samples.count)
    let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
        return nil
    }
    
    buffer.frameLength = frameCount
    let channelData = buffer.floatChannelData![0]
    for (index, sample) in samples.enumerated() {
        channelData[index] = sample
    }
    
    return buffer
}

public class AudioPlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    
    init() {
        engine.attach(player)
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        engine.connect(player, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
            print("AVAudioEngine started.")
        } catch {
            print("Engine failed to start: \(error)")
        }
    }

    func play(samples: [Float], sampleRate: Double = 48000.0) {
        guard let buffer = createAudioPCMBuffer(samples: samples, sampleRate: sampleRate) else {
            print("Failed to create buffer")
            return
        }

        player.scheduleBuffer(buffer, at: nil, options: .interrupts) {
            print("Playback completed")
        }
        
        print("Starting playback...")
        player.play()
    }

    func stop() {
        player.stop()
        engine.stop()
    }
}


func writeAndPlaySineWAV() {
    let sampleRate = 48000
    let duration = 1.0
    let samples = (0..<sampleRate).map { i in
        sin(2.0 * .pi * 440.0 * Double(i) / Double(sampleRate))
    }

    let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)!
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
    buffer.frameLength = AVAudioFrameCount(samples.count)
    let channelData = buffer.floatChannelData![0]
    for (i, s) in samples.enumerated() {
        channelData[i] = Float(s)
    }

    let path = URL(fileURLWithPath: "/Users/connorgibbons/Desktop/test.wav")
    let settings: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: sampleRate,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 32,
        AVLinearPCMIsFloatKey: true,
        AVLinearPCMIsBigEndianKey: false
    ]

    do {
        let file = try AVAudioFile(forWriting: path, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        try file.write(from: buffer)
        print("Wrote test.wav to Desktop")

        // Try playing it with AVAudioPlayer
        let player = try AVAudioPlayer(contentsOf: path)
        player.prepareToPlay()
        player.play()
        print("Trying to play test.wav with AVAudioPlayer")
    } catch {
        print("WAV write/playback error: \(error)")
    }
}
