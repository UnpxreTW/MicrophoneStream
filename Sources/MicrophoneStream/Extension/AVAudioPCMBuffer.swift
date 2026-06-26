//
//  MicrophoneStream
//
//  Copyright © 2026 Unpxre (GitHub: UnpxreTW)
//  Licensed under the Apache License 2.0. See LICENSE for details.
//
//  SPDX-License-Identifier: Apache-2.0

import AVFoundation

extension AVAudioPCMBuffer {

    /// Byte length of the valid audio in this buffer.
    /// - Note: Frame length multiplied by the bytes per frame.
    private var dataLength: Int { Int(frameLength * format.streamDescription.pointee.mBytesPerFrame) }

    /// Raw bytes for the buffer's sample type, or `nil` for an unsupported
    /// format. Multi-channel buffers must be interleaved.
    var pcmData: Data? {
        switch format.commonFormat {
        case .pcmFormatInt16: return int16Data
        case .pcmFormatInt32: return int32Data
        case .pcmFormatFloat32: return float32Data
        default: return nil
        }
    }

    /// Extracts `Int16` samples as `Data`.
    var int16Data: Data? {
        guard let pointer = UnsafeBufferPointer(start: int16ChannelData, count: 1).first else { return nil }
        return Data(bytes: pointer, count: dataLength)
    }

    /// Extracts `Int32` samples as `Data`.
    var int32Data: Data? {
        guard let pointer = UnsafeBufferPointer(start: int32ChannelData, count: 1).first else { return nil }
        return Data(bytes: pointer, count: dataLength)
    }

    /// Extracts `Float32` samples as `Data`.
    var float32Data: Data? {
        guard let pointer = UnsafeBufferPointer(start: floatChannelData, count: 1).first else { return nil }
        return Data(bytes: pointer, count: dataLength)
    }
}
