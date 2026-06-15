//
//  AudioRecordTool
//
//  Copyright © 2026 Unpxre (GitHub: UnpxreTW)
//  Licensed under the Apache License 2.0. See LICENSE for details.
//
//  SPDX-License-Identifier: Apache-2.0

import AVFoundation

extension AVAudioPCMBuffer {

    /// 轉換為 Data 時的資料長度
    /// - Note: 為 Frame 長度乘上每個 Frame 的 Bit 數。
    private var dataLength: Int { Int(frameLength * format.streamDescription.pointee.mBytesPerFrame) }

    /// 從 AVAudioPCMBuffer 取出 Int16 格式資料轉換為 Data。
    var int16Data: Data? {
        guard let pointer = UnsafeBufferPointer(start: int16ChannelData, count: 1).first else { return nil }
        return Data(bytes: pointer, count: dataLength)
    }

    /// 從 AVAudioPCMBuffer 取出 Int32 格式資料轉換為 Data。
    var int32Data: Data? {
        guard let pointer = UnsafeBufferPointer(start: int32ChannelData, count: 1).first else { return nil }
        return Data(bytes: pointer, count: dataLength)
    }

    /// 從 AVAudioPCMBuffer 取出 Float32 格式資料轉換為 Data。
    var float32Data: Data? {
        guard let pointer = UnsafeBufferPointer(start: floatChannelData, count: 1).first else { return nil }
        return Data(bytes: pointer, count: dataLength)
    }
}
