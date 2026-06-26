//
//  MicrophoneStream
//
//  Copyright © 2026 Unpxre (GitHub: UnpxreTW)
//  Licensed under the Apache License 2.0. See LICENSE for details.
//
//  SPDX-License-Identifier: Apache-2.0

import AVFoundation

/// Describes the PCM format the microphone stream emits.
///
/// Every field is configurable; the defaults (`16 kHz / mono / signed 16-bit /
/// 40 ms chunks`) suit speech-to-text and intercom downstreams. The captured
/// hardware buffers are converted to this format with `AVAudioConverter`,
/// including sample-rate conversion when ``sampleRate`` differs from the
/// microphone's native rate.
public struct AudioStreamConfiguration: Sendable, Equatable {

    /// Sample type of the emitted PCM (e.g. `.pcmFormatInt16`).
    public var commonFormat: AVAudioCommonFormat

    /// Target output sample rate in hertz. `nil` follows the microphone's
    /// native rate (no resampling).
    public var sampleRate: Double?

    /// Channel count of the emitted PCM. Multi-channel output requires
    /// ``interleaved`` to be `true`.
    public var channelCount: AVAudioChannelCount

    /// Duration of audio carried by each emitted chunk, in seconds.
    public var chunkDuration: TimeInterval

    /// Whether multi-channel samples are interleaved in each emitted chunk.
    /// - Note: Multi-channel output is always emitted interleaved regardless of
    ///   this value (see ``outputFormat(inputSampleRate:)``), because the chunk
    ///   bytes are extracted from a single packed buffer; this flag only takes
    ///   effect for mono.
    public var interleaved: Bool

    public init(
        commonFormat: AVAudioCommonFormat = .pcmFormatInt16,
        sampleRate: Double? = 16_000,
        channelCount: AVAudioChannelCount = 1,
        chunkDuration: TimeInterval = 0.04,
        interleaved: Bool = true
    ) {
        self.commonFormat = commonFormat
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.chunkDuration = chunkDuration
        self.interleaved = interleaved
    }

    /// `16 kHz / mono / signed 16-bit / 40 ms chunks`.
    public static let `default` = AudioStreamConfiguration()

    /// Builds the `AVAudioFormat` emitted by the stream, resolving a `nil`
    /// ``sampleRate`` against the supplied hardware input rate.
    ///
    /// Multi-channel output is forced interleaved so the emitted chunk bytes
    /// (extracted from a single packed buffer) carry every channel rather than
    /// silently dropping all but channel 0.
    func outputFormat(inputSampleRate: Double) -> AVAudioFormat? {
        AVAudioFormat(
            commonFormat: commonFormat,
            sampleRate: sampleRate ?? inputSampleRate,
            channels: channelCount,
            interleaved: channelCount > 1 ? true : interleaved
        )
    }
}
