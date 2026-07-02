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
private let logger: Logger = .init(subsystem: "MicrophoneStream", category: "StreamProducer")

// MARK: - StreamProducer

/// 在 real-time 音訊 thread 上把麥克風原始 tap 緩衝轉成設定的輸出格式，再轉送給
/// sink。
///
/// 每次呼叫都配置一塊全新的輸出緩衝，讓下游（例如 `SpeechAnalyzer`）能保留它、
/// 而不會與下一次轉換別名共用。converter 實例則跨呼叫重用，以攜帶取樣率轉換所需的
/// 內部狀態。
///
/// - Note: 標 `@unchecked Sendable`，因為 ``process(_:hostTime:)`` 只會從 engine
///   的 tap thread 序列化地被呼叫。
final class StreamProducer: @unchecked Sendable {

	init(
		converter: AVAudioConverter,
		outputFormat: AVAudioFormat,
		sink: @escaping @Sendable (AVAudioPCMBuffer, UInt64) -> Void
	) {
		self.converter = converter
		self.outputFormat = outputFormat
		self.sink = sink
	}

	func process(_ inputBuffer: AVAudioPCMBuffer, hostTime: UInt64) {
		let inputRate = inputBuffer.format.sampleRate
		guard inputRate > 0 else { return }
		let ratio = outputFormat.sampleRate / inputRate
		// 多留的 slack 涵蓋 converter 的內部延遲與進位。
		let capacity = AVAudioFrameCount((Double(inputBuffer.frameLength) * ratio).rounded(.up)) + 1024
		guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
			return
		}
		var didFeed = false
		var conversionError: NSError?
		let status = converter.convert(to: outputBuffer, error: &conversionError) { _, inputStatus in
			if didFeed {
				inputStatus.pointee = .noDataNow
				return nil
			}
			didFeed = true
			inputStatus.pointee = .haveData
			return inputBuffer
		}
		switch status {
		case .haveData, .inputRanDry:
			if outputBuffer.frameLength > 0 {
				sink(outputBuffer, hostTime)
			}
		case .error:
			if let conversionError {
				logger.error("PCM conversion failed: \(conversionError.localizedDescription, privacy: .public)")
			}
		case .endOfStream:
			break
		@unknown default:
			break
		}
	}

	/// 跨呼叫重用的格式轉換器；攜帶取樣率轉換所需的內部狀態。
	private let converter: AVAudioConverter

	/// 轉換的目標輸出格式。
	private let outputFormat: AVAudioFormat

	/// 逐緩衝回呼；收轉換完成的輸出緩衝與其 host time。
	private let sink: @Sendable (AVAudioPCMBuffer, UInt64) -> Void

}
