//
//  MicrophoneStream
//
//  Copyright © 2026 Unpxre (GitHub: UnpxreTW)
//  Licensed under the Apache License 2.0. See LICENSE for details.
//
//  SPDX-License-Identifier: Apache-2.0

import AVFoundation

/// 把連續的 PCM 位元組串流切成定長 chunk，並為每個 chunk 蓋上 host time 時戳。
///
/// 轉換後的音訊緩衝不會對齊請求的 chunk 大小，因此湊不滿一個完整 chunk 的位元組
/// 會留作殘餘、接到下一批輸入前面。每個吐出的 chunk 都標上 host time：殘餘為空時，
/// 時間軸（重新）錨定到進來緩衝的真實擷取時間；緩衝內每吐一個 chunk，便前進剛好
/// 一個 chunk 的時長。
///
/// - Note: 標 `@unchecked Sendable`，因為實例只會被驅動 engine tap 的那條
///   real-time 音訊 thread 觸碰；``append(_:hostTime:)`` 不得並行呼叫。
final class ChunkAccumulator: @unchecked Sendable {

    /// 每個吐出 chunk 的位元組數。
    private let chunkByteCount: Int

    /// 吐出格式中每個音訊 frame 的位元組數。
    private let bytesPerFrame: Int

    /// 每吐一個 chunk，host time 前進的 tick 數。
    private let tickStep: UInt64

    /// 尚未湊滿一個 chunk 的殘餘位元組。
    private var residual = Data()

    /// 下一個吐出 chunk 的 host time。
    private var nextHostTime: UInt64 = 0

    /// - Parameters:
    ///   - chunkByteCount: 每個吐出 chunk 承載的位元組數。
    ///   - bytesPerFrame: 吐出格式中每個音訊 frame 的位元組數。
    ///   - sampleRate: 吐出格式的取樣率（Hz）。
    init(chunkByteCount: Int, bytesPerFrame: Int, sampleRate: Double) {
        let frameBytes = max(bytesPerFrame, 1)
        self.bytesPerFrame = frameBytes
        self.chunkByteCount = max(chunkByteCount, frameBytes)
        let framesPerChunk = Double(self.chunkByteCount / frameBytes)
        let chunkSeconds = sampleRate > 0 ? framesPerChunk / sampleRate : 0
        self.tickStep = AVAudioTime.hostTime(forSeconds: chunkSeconds)
    }

    /// 接入在 `hostTime` 擷取到的 `data`，回傳此刻所有湊滿的完整 chunk，最舊的在前。
    /// 剩下的位元組留作殘餘。
    func append(_ data: Data, hostTime: UInt64) -> [(Data, UInt64)] {
        if residual.isEmpty {
            nextHostTime = hostTime
        }
        residual.append(data)

        var chunks: [(Data, UInt64)] = []
        while residual.count >= chunkByteCount {
            let chunk = Data(residual.prefix(chunkByteCount))
            chunks.append((chunk, nextHostTime))
            residual.removeFirst(chunkByteCount)
            nextHostTime = nextHostTime &+ tickStep
        }
        return chunks
    }
}
