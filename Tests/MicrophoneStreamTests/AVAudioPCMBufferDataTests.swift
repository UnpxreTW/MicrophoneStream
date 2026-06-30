//
//  MicrophoneStreamTests
//
//  Copyright © 2026 Unpxre (GitHub: UnpxreTW)
//  Licensed under the Apache License 2.0. See LICENSE for details.
//
//  SPDX-License-Identifier: Apache-2.0

@testable import MicrophoneStream
import AVFoundation
import Testing

@Suite("avAudioPCMBufferData") private struct AVAudioPCMBufferDataTests {

    @Test private func `Int16 取出的長度與內容正確`() {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4)!
        buffer.frameLength = 4
        let samples = buffer.int16ChannelData![0]
        let values: [Int16] = [1, -2, 3, -4]
        for (index, value) in values.enumerated() { samples[index] = value }

        let data = buffer.pcmData
        #expect(data?.count == 4 * MemoryLayout<Int16>.size)
        let expected = values.withUnsafeBytes { Data($0) }
        #expect(data == expected)
    }

    @Test private func `Float32 取出的長度正確`() {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: true)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8)!
        buffer.frameLength = 8
        for index in 0..<8 { buffer.floatChannelData![0][index] = Float(index) }

        #expect(buffer.pcmData?.count == 8 * MemoryLayout<Float>.size)
    }

    @Test private func `Int32 取出的長度正確`() {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatInt32, sampleRate: 16_000, channels: 1, interleaved: true)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 5)!
        buffer.frameLength = 5
        for index in 0..<5 { buffer.int32ChannelData![0][index] = Int32(index) }

        #expect(buffer.pcmData?.count == 5 * MemoryLayout<Int32>.size)
    }

    @Test private func `位元組長度跟隨 frameLength 而非 capacity`() {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 100)!
        buffer.frameLength = 10
        #expect(buffer.pcmData?.count == 10 * MemoryLayout<Int16>.size)
    }
}
