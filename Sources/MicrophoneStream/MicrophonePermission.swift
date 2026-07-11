//
//  MicrophoneStream
//
//  Copyright © 2026 Unpxre (GitHub: UnpxreTW)
//  Licensed under the Apache License 2.0. See LICENSE for details.
//
//  SPDX-License-Identifier: Apache-2.0

import AVFoundation

// MARK: - MicrophonePermissionControlling

/// 抽象化麥克風權限的查詢與請求，讓 streamer 的授權檢查無需真實系統權限狀態即可測試，
/// 也吸收 iOS 與 macOS 權限 API 的平台差異。
protocol MicrophonePermissionControlling: Sendable {

	/// 麥克風權限目前是否已授與。
	///
	/// 「尚未決定」（還沒問過使用者）與「被拒絕」都回 `false`——對 streamer 而言
	/// 兩者一樣不能開始擷取，呼叫端該先走 ``requestPermission()``。
	var isGranted: Bool { get }

	/// 向系統請求麥克風權限；尚未決定時跳出系統對話框，回傳最終是否授與。
	func requestPermission() async -> Bool
}

#if os(iOS)

/// iOS 上的麥克風權限控制：iOS 17 起走 `AVAudioApplication`、之前退回
/// `AVAudioSession` 的錄音權限 API——兩者查的是同一份系統麥克風權限。
struct PlatformMicrophonePermission: MicrophonePermissionControlling {

	var isGranted: Bool {
		if #available(iOS 17, *) {
			return AVAudioApplication.shared.recordPermission == .granted
		} else {
			return AVAudioSession.sharedInstance().recordPermission == .granted
		}
	}

	func requestPermission() async -> Bool {
		if #available(iOS 17, *) {
			return await AVAudioApplication.requestRecordPermission()
		} else {
			return await withCheckedContinuation { continuation in
				AVAudioSession.sharedInstance().requestRecordPermission { granted in
					continuation.resume(returning: granted)
				}
			}
		}
	}
}

#else

/// macOS 等沒有 `AVAudioSession` 的平台上的麥克風權限控制：改走 `AVCaptureDevice`
/// 的音訊裝置授權——與 `AVAudioEngine` 的麥克風擷取共用同一份系統權限。
struct PlatformMicrophonePermission: MicrophonePermissionControlling {

	var isGranted: Bool {
		AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
	}

	func requestPermission() async -> Bool {
		await AVCaptureDevice.requestAccess(for: .audio)
	}
}

#endif
