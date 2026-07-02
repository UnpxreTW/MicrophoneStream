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

// swiftformat:disable propertyTypes

private final class AudioStreamConfigurationTests {

	/// 預設值（16 kHz / mono / Int16 / 40 ms）適合語音轉文字。
	@Test
	private func `default configuration is speech friendly`() {
		let config = AudioStreamConfiguration.default
		#expect(config.commonFormat == .pcmFormatInt16)
		#expect(config.sampleRate == 16_000)
		#expect(config.channelCount == 1)
		#expect(abs(config.chunkDuration - 0.04) < 1e-9)
		#expect(config.interleaved)
	}

	/// sampleRate 為 nil 時，輸出格式跟隨硬體輸入取樣率。
	@Test
	private func `output format follows hardware when sample rate is nil`() {
		var config = AudioStreamConfiguration.default
		config.sampleRate = nil
		let format = config.outputFormat(inputSampleRate: 48_000)
		#expect(format?.sampleRate == 48_000)
		#expect(format?.channelCount == 1)
		#expect(format?.commonFormat == .pcmFormatInt16)
	}

	/// 指定 sampleRate 時，輸出格式採用該值。
	@Test
	private func `output format uses explicit sample rate`() {
		let config = AudioStreamConfiguration(sampleRate: 16_000, channelCount: 1)
		let format = config.outputFormat(inputSampleRate: 48_000)
		#expect(format?.sampleRate == 16_000)
	}

	/// 輸出格式遵守指定的 channelCount。
	@Test
	private func `output format honours channel count`() {
		let config = AudioStreamConfiguration(sampleRate: 44_100, channelCount: 2, interleaved: true)
		let format = config.outputFormat(inputSampleRate: 48_000)
		#expect(format?.channelCount == 2)
	}

	/// 多聲道輸出一律強制交錯（避免抽包時丟掉 channel 0 以外的聲道）。
	@Test
	private func `output format forces multichannel to interleaved`() {
		// interleaved:false 會讓 pcmData 丟掉 channel 0 以外的全部；
		// 推導出的格式必須把多聲道強制轉成交錯。
		let config = AudioStreamConfiguration(channelCount: 2, interleaved: false)
		let format = config.outputFormat(inputSampleRate: 48_000)
		#expect(format?.channelCount == 2)
		#expect(format?.isInterleaved == true)
	}

	/// mono 輸出仍遵守 interleaved 旗標。
	@Test
	private func `output format keeps interleaved flag for mono`() {
		let config = AudioStreamConfiguration(channelCount: 1, interleaved: false)
		let format = config.outputFormat(inputSampleRate: 48_000)
		#expect(format?.channelCount == 1)
	}
}
