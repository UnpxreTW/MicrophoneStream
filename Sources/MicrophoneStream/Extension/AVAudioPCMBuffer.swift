//
//  MicrophoneStream
//
//  Copyright © 2020 Unpxre (GitHub: UnpxreTW)
//  Licensed under the Apache License 2.0. See LICENSE for details.
//
//  SPDX-License-Identifier: Apache-2.0

import AVFoundation

extension AVAudioPCMBuffer {

	/// 此緩衝中有效音訊的位元組長度。
	/// - Note: frame 長度乘以每 frame 位元組數。
	private var dataLength: Int { Int(frameLength * format.streamDescription.pointee.mBytesPerFrame) }

	/// 此緩衝取樣型別的原始位元組，不支援的格式回 `nil`。多聲道緩衝必須是交錯排列。
	var pcmData: Data? {
		switch format.commonFormat {
		case .pcmFormatInt16: int16Data
		case .pcmFormatInt32: int32Data
		case .pcmFormatFloat32: float32Data
		default: nil
		}
	}

	/// 把 `Int16` 取樣抽成 `Data`。
	var int16Data: Data? {
		guard let pointer = UnsafeBufferPointer(start: int16ChannelData, count: 1).first else { return nil }
		return Data(bytes: pointer, count: dataLength)
	}

	/// 把 `Int32` 取樣抽成 `Data`。
	var int32Data: Data? {
		guard let pointer = UnsafeBufferPointer(start: int32ChannelData, count: 1).first else { return nil }
		return Data(bytes: pointer, count: dataLength)
	}

	/// 把 `Float32` 取樣抽成 `Data`。
	var float32Data: Data? {
		guard let pointer = UnsafeBufferPointer(start: floatChannelData, count: 1).first else { return nil }
		return Data(bytes: pointer, count: dataLength)
	}
}
