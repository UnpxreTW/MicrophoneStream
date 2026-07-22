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

	/// generation token 是單調遞增的 run id：每輪 `start()` 經 `claimGeneration()`
	/// 各自認領一個，`stop(generation:)` 用它判斷收尾請求是否已過期（見型別內文件）。
	/// 這裡直接驗證計數本身的單調遞增與不重複——完整的並發競態場景（遲到的
	/// `onTermination` 取消企圖拆掉已經在跑的新一輪）見下方設計筆記，本測試不含。
	@Test
	private func `claimGeneration increments monotonically and never repeats`() async {
		let streamer = MicrophoneStreamer(
			configuration: .default,
			session: MockAudioSession(),
			permission: MockMicrophonePermission(granted: true)
		)
		let first = await streamer.claimGeneration()
		let second = await streamer.claimGeneration()
		let third = await streamer.claimGeneration()
		#expect(first < second)
		#expect(second < third)
		#expect(Set([first, second, third]).count == 3)
	}
}

// MARK: - 設計筆記：generation token／onTermination 完整並發競態場景

// 上面的測試涵蓋了 generation 計數本身的正確性（單調遞增、不重複），但沒有涵蓋
// 型別文件描述的完整競態：「舊一輪的消費端取消晚到，透過 `onTermination` 誤拆掉
// 剛啟動的新一輪」。這條路徑目前無法在不觸碰真實麥克風硬體的情況下決定性重現，
// 原因是 `beginStreaming(preferredFormat:makeSink:)` 在 session 配置成功後會
// 直接讀 `engine.inputNode.outputFormat(forBus:)`；`engine` 是具體的
// `AVAudioEngine`、沒有像 `AudioSessionControlling` 那樣的協定接縫可注入假格式。
// CI 環境若沒有可用的輸入裝置，這條路徑會在拿到 sample rate 前就以
// `formatUnavailable` 短路，永遠走不到 `activeContinuation` 與 `onTermination`
// 掛勾的那一步——本檔其餘測試也是因此才一律用 `MockAudioSession(configureError:)`
// 讓流程停在 session 層、不繼續碰 engine。
//
// 這個限制也排除了一個表面上很誘人的捷徑：直接呼叫 `stop(generation:)` 帶一個
// 過期的 generation、斷言 `MockAudioSession.deactivateCount` 仍是 0。這樣寫出的
// 測試看起來驗證了「過期 generation 被擋下」，但其實驗證不了——`teardown()`
// 本身有一道獨立的 idle guard（`producer != nil || engine.isRunning ||
// sessionActive`），沒有真正 start 過的 streamer 呼叫 `stop(generation:)`
// 不論帶哪個 generation 都會被這道 guard 擋掉、根本不會走到
// `deactivateSession()`。也就是說，就算把 generation 比對整段拿掉，這樣的測試
// 一樣會綠燈——它量不出 generation 保護機制本身有沒有作用，只是重複驗證了
// idle guard。要讓這個斷言真正有鑑別力，必須先讓 session 真正進入 active 狀態
// （即真正 start 成功過一次），這又繞回上一段的硬體依賴問題。
//
// 若之後要讓這條競態可決定性測試，需要先把 engine 的 input format／tap 安裝
// 抽成類似 `AudioSessionControlling` 的協定接縫，測試才能在不碰硬體的前提下
// 讓 `start()` 走到成功路徑、拿到真正的 `runGeneration`，再依序：
//   1. 呼叫 `start()` 成功一次，記下第一輪的 `runGeneration`。
//   2. 再次呼叫 `start()`（模擬新一輪開始），記下第二輪的 `runGeneration`。
//   3. 手動用第一輪的 generation 呼叫 `stop(generation:)`，驗證第二輪的
//      session／engine 狀態不受影響（no-op）。
//   4. 用第二輪的 generation 呼叫 `stop(generation:)`，驗證這次才真正 teardown。
// 這項重構不在本次最小處置範圍內，留待後續評估。
