//
//  MicrophoneStream
//
//  Copyright © 2026 Unpxre (GitHub: UnpxreTW)
//  Licensed under the Apache License 2.0. See LICENSE for details.
//
//  SPDX-License-Identifier: Apache-2.0

import AVFoundation

/// 描述麥克風串流吐出的 PCM 格式。
///
/// 每個欄位皆可配置；預設值（`16 kHz / mono / signed 16-bit / 40 ms chunks`）
/// 適合語音轉文字（speech-to-text）與對講等下游。擷取到的硬體緩衝以 `AVAudioConverter`
/// 轉成此格式，當 ``sampleRate`` 與麥克風原生取樣率不同時一併做取樣率轉換。
public struct AudioStreamConfiguration: Sendable, Equatable {

	/// `16 kHz / mono / signed 16-bit / 40 ms chunks`.
	public static let `default`: AudioStreamConfiguration = .init()

	/// 吐出 PCM 的取樣型別（例如 `.pcmFormatInt16`）。
	public var commonFormat: AVAudioCommonFormat

	/// 目標輸出取樣率（Hz）。`nil` 跟隨麥克風原生取樣率（不重新取樣）。
	public var sampleRate: Double?

	/// 吐出 PCM 的聲道數。多聲道輸出要求 ``interleaved`` 為 `true`。
	public var channelCount: AVAudioChannelCount

	/// 每個吐出 chunk 承載的音訊時長（秒）。
	public var chunkDuration: TimeInterval

	/// 多聲道取樣是否在每個吐出 chunk 中交錯排列。
	/// - Note: 不論此值為何，多聲道輸出一律以交錯排列吐出
	///   （見 ``outputFormat(inputSampleRate:)``）——chunk 位元組是從單一打包緩衝
	///   抽出的，此旗標只對 mono 生效。
	public var interleaved: Bool

	public init(
		commonFormat: AVAudioCommonFormat = .pcmFormatInt16,
		sampleRate: Double? = 16_000,
		channelCount: AVAudioChannelCount = 1,
		chunkDuration: TimeInterval = 0.04,
		interleaved: Bool = true
	) {
		self.commonFormat = commonFormat
		self.sampleRate = sampleRate
		self.channelCount = channelCount
		self.chunkDuration = chunkDuration
		self.interleaved = interleaved
	}

	/// 建出串流吐出的 `AVAudioFormat`，並以傳入的硬體輸入取樣率解析 `nil` 的
	/// ``sampleRate``。
	///
	/// 多聲道輸出強制交錯，讓吐出的 chunk 位元組（從單一打包緩衝抽出）承載每一個聲道，
	/// 而非默默丟掉 channel 0 以外的全部。
	func outputFormat(inputSampleRate: Double) -> AVAudioFormat? {
		AVAudioFormat(
			commonFormat: commonFormat,
			sampleRate: sampleRate ?? inputSampleRate,
			channels: channelCount,
			interleaved: channelCount > 1 ? true : interleaved
		)
	}
}
