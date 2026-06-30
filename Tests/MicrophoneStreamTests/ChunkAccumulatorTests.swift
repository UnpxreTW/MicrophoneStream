//
//  MicrophoneStreamTests
//
//  Copyright © 2026 Unpxre (GitHub: UnpxreTW)
//  Licensed under the Apache License 2.0. See LICENSE for details.
//
//  SPDX-License-Identifier: Apache-2.0

@testable import MicrophoneStream
import AVFoundation
import Testing

@Suite("chunkAccumulator") private struct ChunkAccumulatorTests {

    @Test private func `吐出完整 chunk 並保留殘餘`() {
        let accumulator = ChunkAccumulator(chunkByteCount: 8, bytesPerFrame: 2, sampleRate: 16_000)

        let first = accumulator.append(Data(count: 20), hostTime: 1_000)
        #expect(first.count == 2)
        #expect((first.map { $0.0.count }) == [8, 8])

        // 帶 4 byte 殘餘；再來 4 byte 湊滿第三個 chunk。
        let second = accumulator.append(Data(count: 4), hostTime: 2_000)
        #expect(second.count == 1)
        #expect(second[0].0.count == 8)
    }

    @Test private func `跨 chunk 保留位元組順序`() {
        let accumulator = ChunkAccumulator(chunkByteCount: 4, bytesPerFrame: 2, sampleRate: 8_000)
        let out = accumulator.append(Data([0, 1, 2, 3, 4, 5, 6, 7]), hostTime: 0)
        #expect(out.count == 2)
        #expect(out[0].0 == Data([0, 1, 2, 3]))
        #expect(out[1].0 == Data([4, 5, 6, 7]))
    }

    @Test private func `緩衝內 host time 依 chunk 時長前進`() {
        let accumulator = ChunkAccumulator(chunkByteCount: 8, bytesPerFrame: 2, sampleRate: 16_000)
        let out = accumulator.append(Data(count: 24), hostTime: 5_000)
        #expect(out.count == 3)

        // 8 bytes / 每 frame 2 bytes = 4 frames；step = 4 / 16000 秒換成 host ticks。
        let step = AVAudioTime.hostTime(forSeconds: 4.0 / 16_000.0)
        #expect(out[0].1 == 5_000)
        #expect(out[1].1 == 5_000 &+ step)
        #expect(out[2].1 == 5_000 &+ step &+ step)
    }

    @Test private func `殘餘為空時 host time 重新錨定`() {
        let accumulator = ChunkAccumulator(chunkByteCount: 8, bytesPerFrame: 2, sampleRate: 16_000)
        let first = accumulator.append(Data(count: 8), hostTime: 100)
        #expect(first.count == 1)          // 殘餘此刻為空
        let second = accumulator.append(Data(count: 8), hostTime: 999)
        #expect(second[0].1 == 999)        // 重新錨定到新緩衝的時間
    }

    @Test private func `不足一個 chunk 的輸入累積到湊滿`() {
        let accumulator = ChunkAccumulator(chunkByteCount: 8, bytesPerFrame: 2, sampleRate: 16_000)
        #expect(accumulator.append(Data(count: 3), hostTime: 0).isEmpty)
        #expect(accumulator.append(Data(count: 3), hostTime: 1).isEmpty)
        let out = accumulator.append(Data(count: 2), hostTime: 2)
        #expect(out.count == 1)
        #expect(out[0].0.count == 8)
    }
}
