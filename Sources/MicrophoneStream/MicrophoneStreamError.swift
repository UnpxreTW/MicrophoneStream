//
//  MicrophoneStream
//
//  Copyright © 2026 Unpxre (GitHub: UnpxreTW)
//  Licensed under the Apache License 2.0. See LICENSE for details.
//
//  SPDX-License-Identifier: Apache-2.0

import Foundation

/// 啟動麥克風串流時擲出的錯誤。
///
/// set-up 階段的失敗在此浮現、不被吞掉；real-time 音訊 thread 上的暫態轉換失敗
/// 則記 log 後略過、而非擲出——掉一個 chunk 不該把整條串流拆掉。
public enum MicrophoneStreamError: Error {

	/// 音訊 session 無法配置成可錄音。
	case sessionConfigurationFailed(underlying: Error)

	/// 麥克風的輸入格式不可用或無效（例如 session 尚未啟用前取樣率為零）。
	case formatUnavailable

	/// 無法在輸入格式與請求的輸出格式之間建出轉換器。
	case converterUnavailable

	/// 音訊 engine 啟動失敗。
	case engineStartFailed(underlying: Error)
}
