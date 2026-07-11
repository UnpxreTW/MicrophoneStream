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

	/// 最近一次 configure 收到的藍牙輸入旗標；尚未被呼叫過為 `nil`。
	var lastAllowsBluetoothInput: Bool? { lock.withLock { receivedBluetoothInputFlags.last } }

	func configureForRecording(allowingBluetoothInput: Bool) throws {
		lock.withLock {
			configureCalls += 1
			receivedBluetoothInputFlags.append(allowingBluetoothInput)
		}
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

	/// 每次 configure 收到的藍牙輸入旗標，依呼叫順序排列。
	private var receivedBluetoothInputFlags: [Bool] = []

	/// 預先設定的 configure 失敗；`nil` 表示成功。
	private let configureError: Error?
}

// MARK: - MockMicrophonePermission

/// 回報預設授權狀態的假權限控制器，讓 start() 的授權檢查無需真實系統權限即可測試。
struct MockMicrophonePermission: MicrophonePermissionControlling {

	/// 預先設定的授權狀態；`isGranted` 與 `requestPermission()` 皆回報此值。
	let granted: Bool

	var isGranted: Bool { granted }

	func requestPermission() async -> Bool { granted }
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
		let streamer = MicrophoneStreamer(
			configuration: .default,
			session: session,
			permission: MockMicrophonePermission(granted: true)
		)
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
		let streamer = MicrophoneStreamer(
			configuration: .default,
			session: session,
			permission: MockMicrophonePermission(granted: true)
		)
		await streamer.stop()
		#expect(session.deactivateCount == 0)
	}

	/// 權限被拒時 start() 直接擲出 permissionDenied，且完全不碰 session——
	/// 授權檢查在任何 session／engine 動作之前，不等 engine 層的原生錯誤。
	@Test
	private func `start throws permission denied when permission is not granted`() async {
		let session = MockAudioSession()
		let streamer = MicrophoneStreamer(
			configuration: .default,
			session: session,
			permission: MockMicrophonePermission(granted: false)
		)
		do {
			_ = try await streamer.start()
			Issue.record("start() 應該要擲出")
		} catch MicrophoneStreamError.permissionDenied {
			// 預期路徑。
		} catch {
			Issue.record("非預期錯誤：\(error)")
		}
		#expect(session.configureCount == 0)
	}

	/// 權限已授與時 start() 照常往下走——以 session 失敗浮現
	/// sessionConfigurationFailed 證明流程越過了授權檢查（測試不需真實麥克風）。
	@Test
	private func `start proceeds past permission check when permission is granted`() async {
		let session = MockAudioSession(configureError: SessionBoom())
		let streamer = MicrophoneStreamer(
			configuration: .default,
			session: session,
			permission: MockMicrophonePermission(granted: true)
		)
		do {
			_ = try await streamer.start()
			Issue.record("start() 應該要擲出")
		} catch MicrophoneStreamError.sessionConfigurationFailed {
			// 預期路徑：越過授權檢查、進到 session 配置。
		} catch {
			Issue.record("非預期錯誤：\(error)")
		}
		#expect(session.configureCount == 1)
	}

	/// allowsBluetoothInput 開啟時，旗標原封轉送給 session 的 configure。
	/// 以 configure 失敗截斷流程，讓測試停在 session 層、不觸碰真實 engine。
	@Test
	private func `start forwards bluetooth input preference to session`() async {
		let session = MockAudioSession(configureError: SessionBoom())
		let streamer = MicrophoneStreamer(
			configuration: .default,
			allowsBluetoothInput: true,
			session: session,
			permission: MockMicrophonePermission(granted: true)
		)
		_ = try? await streamer.start()
		#expect(session.lastAllowsBluetoothInput == true)
	}

	/// 沒有指定 allowsBluetoothInput 時，session 收到的是預設關閉。
	@Test
	private func `bluetooth input defaults to disabled`() async {
		let session = MockAudioSession(configureError: SessionBoom())
		let streamer = MicrophoneStreamer(
			configuration: .default,
			session: session,
			permission: MockMicrophonePermission(granted: true)
		)
		_ = try? await streamer.start()
		#expect(session.lastAllowsBluetoothInput == false)
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
