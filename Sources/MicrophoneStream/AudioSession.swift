//
//  MicrophoneStream
//
//  Copyright © 2026 Unpxre (GitHub: UnpxreTW)
//  Licensed under the Apache License 2.0. See LICENSE for details.
//
//  SPDX-License-Identifier: Apache-2.0

import AVFoundation

// MARK: - AudioSessionControlling

/// 抽象化平台音訊 session，讓 streamer 的 session 轉換無需真實硬體即可測試，
/// 也讓非 iOS host（沒有 `AVAudioSession`）能乾淨編譯。
protocol AudioSessionControlling: Sendable {

	/// 以可錄音的 category 啟用 session。
	///
	/// - Parameter allowingBluetoothInput: 是否把藍牙 HFP 裝置納入可用的錄音輸入
	///   （音質代價見 ``MicrophoneStreamer/init(configuration:allowsBluetoothInput:)``）。
	func configureForRecording(allowingBluetoothInput: Bool) throws

	/// 讓 session 回到預設的非作用狀態。
	func deactivate() throws
}

#if os(iOS)

/// iOS 上以 `AVAudioSession` 為底的 session 控制。
struct PlatformAudioSession: AudioSessionControlling {

	func configureForRecording(allowingBluetoothInput: Bool) throws {
		let session: AVAudioSession = .sharedInstance()
		var options: AVAudioSession.CategoryOptions = [.interruptSpokenAudioAndMixWithOthers]
		if allowingBluetoothInput {
			options.insert(.allowBluetoothHFP)
		}
		try session.setCategory(.playAndRecord, mode: .videoRecording, options: options)
		try session.setPreferredIOBufferDuration(0.005)
		try session.setActive(true)
	}

	func deactivate() throws {
		let session: AVAudioSession = .sharedInstance()
		try session.setCategory(.playAndRecord, mode: .default)
		try session.setActive(false, options: .notifyOthersOnDeactivation)
	}
}

#else

/// 給沒有 `AVAudioSession` 的平台（例如 macOS）的 no-op session 控制——這些平台上
/// `AVAudioEngine` 不需 session 即可擷取麥克風；藍牙輸入與否由系統的輸入裝置選擇
/// 決定，`allowingBluetoothInput` 在此無事可做。
struct PlatformAudioSession: AudioSessionControlling {

	func configureForRecording(allowingBluetoothInput _: Bool) throws {}

	func deactivate() throws {}
}

#endif
