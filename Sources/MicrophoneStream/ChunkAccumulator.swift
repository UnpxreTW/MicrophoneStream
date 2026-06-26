//
//  MicrophoneStream
//
//  Copyright © 2026 Unpxre (GitHub: UnpxreTW)
//  Licensed under the Apache License 2.0. See LICENSE for details.
//
//  SPDX-License-Identifier: Apache-2.0

import AVFoundation

/// Slices a continuous PCM byte stream into fixed-size chunks and stamps each
/// chunk with a host-time.
///
/// Converted audio buffers do not align to the requested chunk size, so bytes
/// that do not fill a whole chunk are held as residual and prepended to the
/// next input. Each emitted chunk is tagged with a host-time: the timeline is
/// (re)anchored to the real capture time of an incoming buffer whenever the
/// residual is empty, and advanced by exactly one chunk's duration for every
/// chunk emitted within a buffer.
///
/// - Note: Marked `@unchecked Sendable` because instances are only ever touched
///   from the single real-time audio thread that drives the engine tap.
///   ``append(_:hostTime:)`` must not be called concurrently.
final class ChunkAccumulator: @unchecked Sendable {

    private let chunkByteCount: Int
    private let bytesPerFrame: Int
    private let tickStep: UInt64

    private var residual = Data()
    private var nextHostTime: UInt64 = 0

    /// - Parameters:
    ///   - chunkByteCount: Bytes carried by each emitted chunk.
    ///   - bytesPerFrame: Bytes per audio frame in the emitted format.
    ///   - sampleRate: Sample rate of the emitted format, in hertz.
    init(chunkByteCount: Int, bytesPerFrame: Int, sampleRate: Double) {
        let frameBytes = max(bytesPerFrame, 1)
        self.bytesPerFrame = frameBytes
        self.chunkByteCount = max(chunkByteCount, frameBytes)
        let framesPerChunk = Double(self.chunkByteCount / frameBytes)
        let chunkSeconds = sampleRate > 0 ? framesPerChunk / sampleRate : 0
        self.tickStep = AVAudioTime.hostTime(forSeconds: chunkSeconds)
    }

    /// Appends `data` captured at `hostTime` and returns every whole chunk that
    /// is now complete, oldest first. Bytes left over are retained as residual.
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
