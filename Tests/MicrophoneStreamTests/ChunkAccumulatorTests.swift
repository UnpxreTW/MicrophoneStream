//
//  MicrophoneStreamTests
//
//  Copyright © 2026 Unpxre (GitHub: UnpxreTW)
//  Licensed under the Apache License 2.0. See LICENSE for details.
//
//  SPDX-License-Identifier: Apache-2.0

import AVFoundation
import XCTest
@testable import MicrophoneStream

final class ChunkAccumulatorTests: XCTestCase {

    func testEmitsWholeChunksAndCarriesResidual() {
        let accumulator = ChunkAccumulator(chunkByteCount: 8, bytesPerFrame: 2, sampleRate: 16_000)

        let first = accumulator.append(Data(count: 20), hostTime: 1_000)
        XCTAssertEqual(first.count, 2)
        XCTAssertEqual(first.map { $0.0.count }, [8, 8])

        // 4 residual bytes carried; 4 more complete a third chunk.
        let second = accumulator.append(Data(count: 4), hostTime: 2_000)
        XCTAssertEqual(second.count, 1)
        XCTAssertEqual(second[0].0.count, 8)
    }

    func testPreservesByteOrderAcrossChunks() {
        let accumulator = ChunkAccumulator(chunkByteCount: 4, bytesPerFrame: 2, sampleRate: 8_000)
        let out = accumulator.append(Data([0, 1, 2, 3, 4, 5, 6, 7]), hostTime: 0)
        XCTAssertEqual(out.count, 2)
        XCTAssertEqual(out[0].0, Data([0, 1, 2, 3]))
        XCTAssertEqual(out[1].0, Data([4, 5, 6, 7]))
    }

    func testHostTimeAdvancesByChunkDurationWithinBuffer() {
        let accumulator = ChunkAccumulator(chunkByteCount: 8, bytesPerFrame: 2, sampleRate: 16_000)
        let out = accumulator.append(Data(count: 24), hostTime: 5_000)
        XCTAssertEqual(out.count, 3)

        // 8 bytes / 2 bytes-per-frame = 4 frames; step = 4 / 16000 s in host ticks.
        let step = AVAudioTime.hostTime(forSeconds: 4.0 / 16_000.0)
        XCTAssertEqual(out[0].1, 5_000)
        XCTAssertEqual(out[1].1, 5_000 &+ step)
        XCTAssertEqual(out[2].1, 5_000 &+ step &+ step)
    }

    func testReanchorsHostTimeWhenResidualEmpty() {
        let accumulator = ChunkAccumulator(chunkByteCount: 8, bytesPerFrame: 2, sampleRate: 16_000)
        let first = accumulator.append(Data(count: 8), hostTime: 100)
        XCTAssertEqual(first.count, 1)          // residual now empty
        let second = accumulator.append(Data(count: 8), hostTime: 999)
        XCTAssertEqual(second[0].1, 999)        // re-anchored to the new buffer's time
    }

    func testSubChunkInputAccumulatesUntilComplete() {
        let accumulator = ChunkAccumulator(chunkByteCount: 8, bytesPerFrame: 2, sampleRate: 16_000)
        XCTAssertTrue(accumulator.append(Data(count: 3), hostTime: 0).isEmpty)
        XCTAssertTrue(accumulator.append(Data(count: 3), hostTime: 1).isEmpty)
        let out = accumulator.append(Data(count: 2), hostTime: 2)
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].0.count, 8)
    }
}
