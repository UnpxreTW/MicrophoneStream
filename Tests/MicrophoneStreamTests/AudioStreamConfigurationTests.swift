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

final class AudioStreamConfigurationTests: XCTestCase {

    func testDefaultsAreSpeechFriendly() {
        let config = AudioStreamConfiguration.default
        XCTAssertEqual(config.commonFormat, .pcmFormatInt16)
        XCTAssertEqual(config.sampleRate, 16_000)
        XCTAssertEqual(config.channelCount, 1)
        XCTAssertEqual(config.chunkDuration, 0.04, accuracy: 1e-9)
        XCTAssertTrue(config.interleaved)
    }

    func testOutputFormatFollowsHardwareWhenSampleRateNil() {
        var config = AudioStreamConfiguration.default
        config.sampleRate = nil
        let format = config.outputFormat(inputSampleRate: 48_000)
        XCTAssertEqual(format?.sampleRate, 48_000)
        XCTAssertEqual(format?.channelCount, 1)
        XCTAssertEqual(format?.commonFormat, .pcmFormatInt16)
    }

    func testOutputFormatUsesExplicitSampleRate() {
        let config = AudioStreamConfiguration(sampleRate: 16_000, channelCount: 1)
        let format = config.outputFormat(inputSampleRate: 48_000)
        XCTAssertEqual(format?.sampleRate, 16_000)
    }

    func testOutputFormatHonoursChannelCount() {
        let config = AudioStreamConfiguration(sampleRate: 44_100, channelCount: 2, interleaved: true)
        let format = config.outputFormat(inputSampleRate: 48_000)
        XCTAssertEqual(format?.channelCount, 2)
    }

    func testMultichannelOutputIsForcedInterleaved() {
        // interleaved:false would make pcmData drop all but channel 0; the
        // derived format must coerce multi-channel to interleaved.
        let config = AudioStreamConfiguration(channelCount: 2, interleaved: false)
        let format = config.outputFormat(inputSampleRate: 48_000)
        XCTAssertEqual(format?.channelCount, 2)
        XCTAssertEqual(format?.isInterleaved, true)
    }

    func testMonoStillHonoursInterleavedFlag() {
        let config = AudioStreamConfiguration(channelCount: 1, interleaved: false)
        let format = config.outputFormat(inputSampleRate: 48_000)
        XCTAssertEqual(format?.channelCount, 1)
    }
}
