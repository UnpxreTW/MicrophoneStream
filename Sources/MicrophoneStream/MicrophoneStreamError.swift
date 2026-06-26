//
//  MicrophoneStream
//
//  Copyright © 2026 Unpxre (GitHub: UnpxreTW)
//  Licensed under the Apache License 2.0. See LICENSE for details.
//
//  SPDX-License-Identifier: Apache-2.0

import Foundation

/// Errors thrown while starting a microphone stream.
///
/// Set-up failures surface here instead of being swallowed; transient
/// conversion failures on the real-time audio thread are logged and skipped
/// rather than thrown, because a chunk drop must not tear down the stream.
public enum MicrophoneStreamError: Error {

    /// The audio session could not be configured for recording.
    case sessionConfigurationFailed(underlying: Error)

    /// The microphone's input format was unavailable or invalid (e.g. a zero
    /// sample rate before the session became active).
    case formatUnavailable

    /// No converter could be created between the input and the requested
    /// output format.
    case converterUnavailable

    /// The audio engine failed to start.
    case engineStartFailed(underlying: Error)
}
