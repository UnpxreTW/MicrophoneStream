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
	func configureForRecording() throws

	/// 讓 session 回到預設的非作用狀態。
	func deactivate() throws
}

#if os(iOS)
/// iOS 上以 `AVAudioSession` 為底的 session 控制。
struct PlatformAudioSession: AudioSessionControlling {

	func configureForRecording() throws {
		let session: AVAudioSession = .sharedInstance()
		try session.setCategory(
			.playAndRecord,
			mode: .videoRecording,
			options: [.interruptSpokenAudioAndMixWithOthers]
		)
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
/// `AVAudioEngine` 不需 session 即可擷取麥克風。
struct PlatformAudioSession: AudioSessionControlling {
	func configureForRecording() throws {}
	func deactivate() throws {}
}
#endif
