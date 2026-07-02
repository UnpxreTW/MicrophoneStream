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

// MARK: - MockAudioSession

// swiftformat:disable propertyTypes

/// 記錄 session 轉換、並可預先設定為失敗，讓 streamer 的 session 處理無需真實
/// 音訊硬體即可測試。
final class MockAudioSession: AudioSessionControlling, @unchecked Sendable {

	init(configureError: Error? = nil) {
		self.configureError = configureError
	}

	/// `configureForRecording()` 被呼叫的次數。
	var configureCount: Int { lock.withLock { configureCalls } }

	/// `deactivate()` 被呼叫的次數。
	var deactivateCount: Int { lock.withLock { deactivateCalls } }

	func configureForRecording() throws {
		lock.withLock { configureCalls += 1 }
		if let configureError { throw configureError }
	}

	func deactivate() throws {
		lock.withLock { deactivateCalls += 1 }
	}

	/// 保護計數器的鎖；呼叫端可能跨執行緒觸碰。
	private let lock = NSLock()

	/// `configureForRecording()` 呼叫計數。
	private var configureCalls = 0

	/// `deactivate()` 呼叫計數。
	private var deactivateCalls = 0

	/// 預先設定的 configure 失敗；`nil` 表示成功。
	private let configureError: Error?

}

// MARK: - SessionBoom

struct SessionBoom: Error {}

// MARK: - MicrophoneStreamerTests

private final class MicrophoneStreamerTests {

	/// session 在任何 engine 動作前就先配置，session 失敗須以
	/// sessionConfigurationFailed 浮現（而非例如 formatUnavailable），證明此順序。
	@Test
	private func `start throws session configuration failed when session fails`() async {
		let session = MockAudioSession(configureError: SessionBoom())
		let streamer = MicrophoneStreamer(configuration: .default, session: session)
		do {
			_ = try await streamer.start()
			Issue.record("start() 應該要擲出")
		} catch MicrophoneStreamError.sessionConfigurationFailed {
			// 預期路徑。
		} catch {
			Issue.record("非預期錯誤：\(error)")
		}
		let count = session.configureCount
		#expect(count == 1)
	}

	/// 沒有東西在跑時，guard 短路掉 teardown、不多呼叫 deactivate。
	@Test
	private func `stop when idle is safe and does not deactivate`() async {
		let session = MockAudioSession()
		let streamer = MicrophoneStreamer(configuration: .default, session: session)
		await streamer.stop()
		#expect(session.deactivateCount == 0)
	}

	/// 不靠麥克風、用合成輸入緩衝驅動 `StreamProducer`，端到端走一遍轉換路徑
	/// （重新取樣 + 改格式）。
	@Test
	private func `stream producer resamples and reformats`() throws {
		let inputFormat = try #require(AVAudioFormat(
			commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 1, interleaved: false
		))
		let outputFormat = try #require(AVAudioFormat(
			commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true
		))
		let converter = try #require(AVAudioConverter(from: inputFormat, to: outputFormat))
		final class Collected: @unchecked Sendable {
			let lock = NSLock()
			var bytes = 0
			func add(_ n: Int) {
				lock.withLock { bytes += n }
			}
		}
		let collected = Collected()
		let producer = StreamProducer(converter: converter, outputFormat: outputFormat) { buffer, _ in
			if let data = buffer.pcmData { collected.add(data.count) }
		}
		let input = try #require(AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: 4800))
		input.frameLength = 4800
		let samples = try #require(input.floatChannelData?[0])
		for index in 0 ..< 4800 {
			samples[index] = sinf(2 * .pi * 440 * Float(index) / 48_000)
		}
		producer.process(input, hostTime: 0)
		let total = collected.bytes
		#expect(total > 0, "降取樣輸出不該為空")
		#expect(total % 2 == 0, "Int16 輸出必須是整數個 frame")
	}
}
