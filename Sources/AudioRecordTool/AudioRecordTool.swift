//
//  AudioRecordTool
//
//  Copyright © 2026 Unpxre (GitHub: UnpxreTW)
//  Licensed under the Apache License 2.0. See LICENSE for details.
//
//  SPDX-License-Identifier: Apache-2.0

import os.log
import AVFoundation

@available(iOS 14.0, *)
let logger: Logger = .init(subsystem: "AudioRecoderTool.component", category: "Recoder")

public final class AudioRecordTool {
    
    // MARK: Public Variable
    
    public static var shared = AudioRecordTool()
    /// 在不同機器實體上的麥克風會取得不同的位元率，讀取此值以取得麥克風的位元率
    public var inputSampleRate: Double { inputFormat.sampleRate }
    
    // MARK: Private Variable
    
    private var session: AVAudioSession = .sharedInstance()
    private var engine: AVAudioEngine = .init()
    private var inputFormat: AVAudioFormat { engine.inputNode.inputFormat(forBus: 0) }
    /// 用來取得音訊緩衝區並轉換為目的格式的節點
    private var formatTransducerNode: AVAudioMixerNode = .init()
    /// 在資料流流向輸出節點前將音量調整為零的節點
    /// - note: 資料流向輸出節點前將音量調整為零才不會在揚聲器發出聲音。
    private var setVolumeZeroNode: AVAudioMixerNode = .init()
    
    private var enginePreparing: Bool = false
    private var enginePrepared: Bool = false
    
    // MARK: Lifecycle
    
    private init() {}
    
    deinit {
        if engine.isRunning {
            stopRecord()
        } else {
            setSessionToDefault()
        }
    }
    
    // MARK: Public Function
    
    /// 連接音訊引擎節點並設定資料流與讀取格式
    public func prepareEngine(with dataflow: @escaping (_ data: Data, _ time: UInt64) -> Void) {
        guard !enginePreparing else { return }
        enginePreparing = true
        defer { enginePreparing = false }
        guard !enginePrepared else { return }
        engine.attach(formatTransducerNode)
        engine.attach(setVolumeZeroNode)
        let expectFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: inputSampleRate,
            channels: 1,
            interleaved: true)
        let bufferSize = UInt32(inputSampleRate / 25)
        formatTransducerNode.installTap(
            onBus: 0,
            bufferSize: bufferSize,
            format: expectFormat
        ) { (buffer, time) in
            buffer.frameLength = bufferSize
            guard let data = buffer.int16Data else { return }
            dataflow(data, time.hostTime)
        }
        engine.connect(engine.inputNode, to: formatTransducerNode, format: inputFormat)
        engine.connect(formatTransducerNode, to: setVolumeZeroNode, format: expectFormat)
        engine.connect(setVolumeZeroNode, to: engine.mainMixerNode, format: expectFormat)
        setVolumeZeroNode.volume = 0
        engine.prepare()
        enginePrepared = true
    }
    
    public func unprepareEngine() {
        guard enginePrepared, !engine.isRunning else { return }
        formatTransducerNode.removeTap(onBus: 0)
        engine.detach(formatTransducerNode)
        engine.detach(setVolumeZeroNode)
        enginePrepared = false
    }
    
    public func startRecord() {
        guard !engine.isRunning else { return }
        setSessionToRecoder()
        try? engine.start()
    }
    
    public func stopRecord() {
        guard engine.isRunning else { return }
        if #available(iOS 14.0, *) {
            logger.info("Stoping Engine...")
        }
        engine.stop()
        unprepareEngine()
        engine.reset()
        setSessionToDefault()
        if #available(iOS 14.0, *) {
            logger.info("Stoping Engine Done")
        }
    }
    
    // MARK: Private Function
    
    /// 開始錄音前要把音訊模式轉換為錄音
    private func setSessionToRecoder() {
        if #available(iOS 14.0, *) {
            logger.debug("Start Set Session Category To Recoder")
        }
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .videoRecording,
                options: [.interruptSpokenAudioAndMixWithOthers])
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
        } catch let error {
            if #available(iOS 14.0, *) {
                logger.error("\(error.localizedDescription)")
            }
        }
        if #available(iOS 14.0, *) {
            logger.info("Set Session Category To Recoder Done")
        }
    }
    
    /// 錄音結束後要把音訊模式轉換為預設模式並觸發取消使用音訊裝置通知
    private func setSessionToDefault() {
        if #available(iOS 14.0, *) {
            logger.debug("Start Set Session Category To Default")
        }
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch let error {
            if #available(iOS 14.0, *) {
                logger.error("\(error.localizedDescription)")
            }
        }
        if #available(iOS 14.0, *) {
            logger.info("Set Session Category To Default Done")
        }
    }
}
