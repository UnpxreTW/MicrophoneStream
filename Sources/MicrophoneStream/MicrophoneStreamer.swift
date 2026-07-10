//
//  MicrophoneStream
//
//  Copyright © 2026 Unpxre (GitHub: UnpxreTW)
//  Licensed under the Apache License 2.0. See LICENSE for details.
//
//  SPDX-License-Identifier: Apache-2.0

import AVFoundation
import os.log

/// 模組內部診斷日誌。
private let logger: Logger = .init(subsystem: "MicrophoneStream", category: "MicrophoneStreamer")

// MARK: - MicrophoneStreamer

/// 把即時麥克風音訊以原始 PCM chunk 串流出來。
///
/// 麥克風直接 tap 在 engine 的 input node 上，以 `AVAudioConverter` 轉成設定的格式；
/// 沒有任何輸出路由，因此不會播放出聲。``start()`` 交回一條 `(Data, UInt64)` 配對的
/// `AsyncStream`——一個 chunk 的 PCM 位元組、以及其首個取樣的 host time——餵給
/// 語音轉文字、雙向對講、或任何想要原始串流的 consumer。
///
/// ```swift
/// let streamer = MicrophoneStreamer()
/// for await (pcm, hostTime) in try await streamer.start() {
///     // 轉送 `pcm`（預設：16 kHz / mono / Int16，每 chunk 40 ms）
/// }
/// ```
///
/// 每個實例擁有一個 engine；每次擷取 session 建一個 streamer。
public actor MicrophoneStreamer {

	// MARK: Public

	/// 麥克風目前的原生取樣率（Hz）。
	public var inputSampleRate: Double {
		engine.inputNode.outputFormat(forBus: 0).sampleRate
	}

	/// 向系統請求麥克風使用權限；尚未決定時跳出系統對話框，回傳最終是否授與。
	///
	/// ``start()`` 不代為請求——未授權（含尚未決定）時直接擲出
	/// ``MicrophoneStreamError/permissionDenied``，因此第一次擷取前先呼叫此方法。
	/// 掛在型別而非實例上：權限是整個 process 共用的系統狀態、不屬於任一 streamer，
	/// 呼叫端也應在建立 streamer 之前就能請求。
	public static func requestPermission() async -> Bool {
		await PlatformMicrophonePermission().requestPermission()
	}

	/// 啟動擷取，回傳一條 `(pcmChunk, hostTime)` 配對的串流。
	///
	/// 當 ``stop()`` 被呼叫、或回傳的串流被取消時，串流結束。已在執行中又呼叫
	/// `start()` 會先停掉前一輪（其串流隨之結束）。
	///
	/// - Throws: 麥克風權限未授與時擲出 ``MicrophoneStreamError/permissionDenied``，
	///   不往下碰 session 與 engine——與其等 engine 層吐晦澀的原生錯誤，不如在入口
	///   就把原因講明。「尚未決定」同樣直接擲出、不代為觸發權限請求（那會在
	///   `start()` 內卡一個系統對話框）：先呼叫 ``requestPermission()``。其後若
	///   session、輸入格式、轉換器或 engine 無法備妥，擲出對應的
	///   ``MicrophoneStreamError``。
	public func start() throws -> AsyncStream<(Data, UInt64)> {
		guard permission.isGranted else { throw MicrophoneStreamError.permissionDenied }
		stop()
		let runGeneration = claimGeneration()
		let (stream, continuation) = AsyncStream<(Data, UInt64)>.makeStream()
		do {
			try beginStreaming(preferredFormat: nil) { outputFormat in
				let bytesPerFrame: Int = .init(outputFormat.streamDescription.pointee.mBytesPerFrame)
				let framesPerChunk = max(Int((outputFormat.sampleRate * self.configuration.chunkDuration).rounded()), 1)
				let accumulator: ChunkAccumulator = .init(
					chunkByteCount: framesPerChunk * bytesPerFrame,
					bytesPerFrame: bytesPerFrame,
					sampleRate: outputFormat.sampleRate
				)
				return { buffer, hostTime in
					guard let data = buffer.pcmData else { return }
					for chunk in accumulator.append(data, hostTime: hostTime) {
						continuation.yield(chunk)
					}
				}
			}
		} catch {
			continuation.finish()
			throw error
		}
		activeContinuation = continuation
		continuation.onTermination = { [weak self] _ in
			Task { await self?.stop(generation: runGeneration) }
		}
		return stream
	}

	/// 停止擷取、拆除 engine，並結束作用中的串流。
	public func stop() {
		teardown()
	}

	/// 建立一個以指定格式吐出 PCM 的 streamer。
	///
	/// - Parameters:
	///   - configuration: 串流輸出的 PCM 格式設定。
	///   - allowsBluetoothInput: 是否允許藍牙 HFP 裝置（耳機麥克風）作為錄音輸入。
	///     走 HFP 收音會把整條藍牙連線降到電話級窄頻 codec、音質明顯劣化，
	///     因此預設關閉，只在確實要用藍牙耳機收音時開啟。僅 iOS 生效；macOS 沒有
	///     `AVAudioSession`，輸入路由由系統的輸入裝置選擇決定，此旗標為 no-op。
	public init(configuration: AudioStreamConfiguration = .default, allowsBluetoothInput: Bool = false) {
		self.init(
			configuration: configuration,
			allowsBluetoothInput: allowsBluetoothInput,
			session: PlatformAudioSession(),
			permission: PlatformMicrophonePermission()
		)
	}

	// MARK: Lifecycle

	/// 測試接縫：注入自訂的 session 控制器與權限控制器。
	init(
		configuration: AudioStreamConfiguration = .default,
		allowsBluetoothInput: Bool = false,
		session: AudioSessionControlling,
		permission: MicrophonePermissionControlling
	) {
		self.configuration = configuration
		self.allowsBluetoothInput = allowsBluetoothInput
		self.session = session
		self.permission = permission
	}

	deinit {
		engine.stop()
		if sessionActive {
			try? session.deactivate()
		}
	}

	// MARK: Internal

	/// 以 run generation 為鍵的拆除：若有較新的一輪在執行則為 no-op。
	func stop(generation: UInt64) {
		guard generation == self.generation else { return }
		teardown()
	}

	/// 認領並回傳下一個 run generation。
	func claimGeneration() -> UInt64 {
		generation &+= 1
		return generation
	}

	/// engine／converter／tap 的共用建置。解析輸出格式（先取 `preferredFormat`，
	/// 否則以設定對上即時的輸入取樣率推導），安裝 tap，啟動 engine。`makeSink`
	/// 工廠收到解析後的輸出格式、回傳逐緩衝的 sink。session 啟用後若有任何失敗，
	/// 會先停用 session 再擲出。
	@discardableResult
	func beginStreaming(
		preferredFormat: AVAudioFormat?,
		makeSink: (AVAudioFormat) -> (@Sendable (AVAudioPCMBuffer, UInt64) -> Void)
	) throws -> AVAudioFormat {
		do {
			try session.configureForRecording(allowingBluetoothInput: allowsBluetoothInput)
		} catch {
			throw MicrophoneStreamError.sessionConfigurationFailed(underlying: error)
		}
		sessionActive = true
		do {
			let input = engine.inputNode
			let inputFormat = input.outputFormat(forBus: 0)
			guard inputFormat.sampleRate > 0 else {
				throw MicrophoneStreamError.formatUnavailable
			}
			let outputFormat: AVAudioFormat
			if let preferredFormat {
				outputFormat = preferredFormat
			} else if let derived = configuration.outputFormat(inputSampleRate: inputFormat.sampleRate) {
				outputFormat = derived
			} else {
				throw MicrophoneStreamError.formatUnavailable
			}
			guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
				throw MicrophoneStreamError.converterUnavailable
			}
			let producer: StreamProducer = .init(
				converter: converter,
				outputFormat: outputFormat,
				sink: makeSink(outputFormat)
			)
			self.producer = producer
			let tapBufferSize: AVAudioFrameCount = .init(max(inputFormat.sampleRate * configuration.chunkDuration, 1))
			input.removeTap(onBus: 0)
			input.installTap(onBus: 0, bufferSize: tapBufferSize, format: inputFormat) { buffer, when in
				producer.process(buffer, hostTime: when.hostTime)
			}
			engine.prepare()
			do {
				try engine.start()
			} catch {
				throw MicrophoneStreamError.engineStartFailed(underlying: error)
			}
			return outputFormat
		} catch {
			engine.inputNode.removeTap(onBus: 0)
			producer = nil
			deactivateSession()
			throw error
		}
	}

	// MARK: Private

	/// 串流輸出格式設定。
	private let configuration: AudioStreamConfiguration

	/// 是否允許藍牙 HFP 輸入；配置 session 時原封轉送
	/// （代價與平台差異見 ``init(configuration:allowsBluetoothInput:)``）。
	private let allowsBluetoothInput: Bool

	/// 平台音訊 session 控制；測試經此接縫注入替身。
	private let session: AudioSessionControlling

	/// 平台麥克風權限查詢；測試經此接縫注入假授權狀態。
	private let permission: MicrophonePermissionControlling

	/// 擷取麥克風的 engine；每個 streamer 實例獨佔一個。
	///
	/// 標 `nonisolated(unsafe)`：`AVAudioEngine` 非 Sendable，`deinit`（nonisolated）
	/// 需要在最後一個參考消失時停掉它——此時已無任何並行觸碰，實際安全；
	/// 其餘存取皆在 actor 隔離內。
	nonisolated(unsafe) private let engine: AVAudioEngine = .init()

	/// 目前一輪的轉換供應鏈；未在擷取時為 nil。
	private var producer: StreamProducer?

	/// 作用中串流的 continuation；teardown 時 finish 並清空。
	private var activeContinuation: AsyncStream<(Data, UInt64)>.Continuation?

	/// 單調遞增的 run id。每輪擷取各認領一個；以過期 generation
	/// 為鍵的拆除請求會被忽略，因此遲來的串流取消無法拆掉較新的一輪。
	private var generation: UInt64 = 0

	/// 追蹤 `session.configureForRecording()` 是否已成功、且尚未由 `deactivate()`
	/// 平衡掉，讓錯誤路徑與 `deinit` 能釋放 session。
	private var sessionActive = false

	private func teardown() {
		guard producer != nil || engine.isRunning || sessionActive else { return }
		logger.info("Stopping microphone stream")
		engine.inputNode.removeTap(onBus: 0)
		engine.stop()
		engine.reset()
		producer = nil
		deactivateSession()
		activeContinuation?.finish()
		activeContinuation = nil
	}

	private func deactivateSession() {
		guard sessionActive else { return }
		do {
			try session.deactivate()
		} catch {
			logger.error("Audio session deactivation failed: \(error.localizedDescription, privacy: .public)")
		}
		sessionActive = false
	}
}
