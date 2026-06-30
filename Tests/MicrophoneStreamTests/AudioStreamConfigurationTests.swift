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

@Suite("audioStreamConfiguration") private struct AudioStreamConfigurationTests {

    @Test private func `預設值對語音友善`() {
        let config = AudioStreamConfiguration.default
        #expect(config.commonFormat == .pcmFormatInt16)
        #expect(config.sampleRate == 16_000)
        #expect(config.channelCount == 1)
        #expect(abs(config.chunkDuration - 0.04) < 1e-9)
        #expect(config.interleaved)
    }

    @Test private func `sampleRate 為 nil 時輸出格式跟隨硬體`() {
        var config = AudioStreamConfiguration.default
        config.sampleRate = nil
        let format = config.outputFormat(inputSampleRate: 48_000)
        #expect(format?.sampleRate == 48_000)
        #expect(format?.channelCount == 1)
        #expect(format?.commonFormat == .pcmFormatInt16)
    }

    @Test private func `指定 sampleRate 時輸出格式採用之`() {
        let config = AudioStreamConfiguration(sampleRate: 16_000, channelCount: 1)
        let format = config.outputFormat(inputSampleRate: 48_000)
        #expect(format?.sampleRate == 16_000)
    }

    @Test private func `輸出格式遵守 channelCount`() {
        let config = AudioStreamConfiguration(sampleRate: 44_100, channelCount: 2, interleaved: true)
        let format = config.outputFormat(inputSampleRate: 48_000)
        #expect(format?.channelCount == 2)
    }

    @Test private func `多聲道輸出強制交錯`() {
        // interleaved:false 會讓 pcmData 丟掉 channel 0 以外的全部；
        // 推導出的格式必須把多聲道強制轉成交錯。
        let config = AudioStreamConfiguration(channelCount: 2, interleaved: false)
        let format = config.outputFormat(inputSampleRate: 48_000)
        #expect(format?.channelCount == 2)
        #expect(format?.isInterleaved == true)
    }

    @Test private func `mono 仍遵守 interleaved 旗標`() {
        let config = AudioStreamConfiguration(channelCount: 1, interleaved: false)
        let format = config.outputFormat(inputSampleRate: 48_000)
        #expect(format?.channelCount == 1)
    }
}
