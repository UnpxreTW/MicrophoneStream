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

// swiftformat:disable propertyTypes

private final class ChunkAccumulatorTests {

	/// 吐出所有湊滿的完整 chunk；不足一整包的位元組留作殘餘（residual）、帶到下一批補滿。
	@Test
	private func `append emits whole chunks and carries residual`() {
		let accumulator = ChunkAccumulator(chunkByteCount: 8, bytesPerFrame: 2, sampleRate: 16_000)

		let first = accumulator.append(Data(count: 20), hostTime: 1000)
		#expect(first.count == 2)
		#expect((first.map(\.0.count)) == [8, 8])

		// 帶 4 byte 殘餘；再來 4 byte 湊滿第三個 chunk。
		let second = accumulator.append(Data(count: 4), hostTime: 2000)
		#expect(second.count == 1)
		#expect(second[0].0.count == 8)
	}

	/// 跨 chunk 邊界時位元組順序不亂。
	@Test
	private func `append preserves byte order across chunks`() {
		let accumulator = ChunkAccumulator(chunkByteCount: 4, bytesPerFrame: 2, sampleRate: 8000)
		let out = accumulator.append(Data([0, 1, 2, 3, 4, 5, 6, 7]), hostTime: 0)
		#expect(out.count == 2)
		#expect(out[0].0 == Data([0, 1, 2, 3]))
		#expect(out[1].0 == Data([4, 5, 6, 7]))
	}

	/// 同一批緩衝內連續吐出的 chunk，host time 依 chunk 時長逐一前進。
	@Test
	private func `append advances host time by chunk duration within a buffer`() {
		let accumulator = ChunkAccumulator(chunkByteCount: 8, bytesPerFrame: 2, sampleRate: 16_000)
		let out = accumulator.append(Data(count: 24), hostTime: 5000)
		#expect(out.count == 3)

		// 8 bytes / 每 frame 2 bytes = 4 frames；step = 4 / 16000 秒換成 host ticks。
		let step = AVAudioTime.hostTime(forSeconds: 4.0 / 16_000.0)
		#expect(out[0].1 == 5000)
		#expect(out[1].1 == 5000 &+ step)
		#expect(out[2].1 == 5000 &+ step &+ step)
	}

	/// 殘餘為空時，host time 重新錨定到新進緩衝的擷取時間。
	@Test
	private func `append re-anchors host time when residual is empty`() {
		let accumulator = ChunkAccumulator(chunkByteCount: 8, bytesPerFrame: 2, sampleRate: 16_000)
		let first = accumulator.append(Data(count: 8), hostTime: 100)
		#expect(first.count == 1) // 殘餘此刻為空
		let second = accumulator.append(Data(count: 8), hostTime: 999)
		#expect(second[0].1 == 999) // 重新錨定到新緩衝的時間
	}

	/// 不足一個 chunk 的輸入持續累積，直到湊滿才吐出。
	@Test
	private func `append accumulates sub-chunk input until complete`() {
		let accumulator = ChunkAccumulator(chunkByteCount: 8, bytesPerFrame: 2, sampleRate: 16_000)
		#expect(accumulator.append(Data(count: 3), hostTime: 0).isEmpty)
		#expect(accumulator.append(Data(count: 3), hostTime: 1).isEmpty)
		let out = accumulator.append(Data(count: 2), hostTime: 2)
		#expect(out.count == 1)
		#expect(out[0].0.count == 8)
	}
}
