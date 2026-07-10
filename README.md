# MicrophoneStream

即時擷取麥克風的裸 PCM 音訊流，以 Swift `AsyncStream` 餵給下游——語音轉文字（STT）、雙向對講等即時場景。

這不是「錄音存檔」工具：它不寫檔、不播放，只把麥克風緩衝區即時轉成你指定格式的 PCM 封包（預設 16 kHz / mono / Int16、每包 40 ms），並附上每包首個 sample 的 host-time 時戳。

## 安裝

Swift Package Manager：

```swift
.package(url: "https://github.com/UnpxreTW/MicrophoneStream.git", from: "2.0.0")
```

## 使用

```swift
import MicrophoneStream

let streamer = MicrophoneStreamer()
for await (pcm, hostTime) in try await streamer.start() {
    // pcm: Data（一包 PCM bytes）
    // hostTime: UInt64（該包首個 sample 的 host-time）
    send(pcm)
}
```

停止擷取呼叫 `await streamer.stop()`；消費端結束 `for await`（cancel stream）也會自動收尾。

### 麥克風權限

`start()` 不代為請求權限：未授權（含使用者尚未決定）直接擲出 `MicrophoneStreamError.permissionDenied`、不往下碰 engine。第一次擷取前先請求：

```swift
guard await MicrophoneStreamer.requestPermission() else {
    // 被拒：引導使用者到系統設定開啟麥克風權限
    return
}
```

### 藍牙耳機收音

```swift
let streamer = MicrophoneStreamer(allowsBluetoothInput: true)
```

允許藍牙 HFP 裝置（耳機麥克風）作為錄音輸入。走 HFP 收音會把整條藍牙連線降到電話級窄頻 codec、音質明顯劣化，因此預設關閉。僅 iOS 生效；macOS 沒有 `AVAudioSession`，輸入路由由系統的輸入裝置選擇決定。

### 自訂格式

```swift
let configuration = AudioStreamConfiguration(
    commonFormat: .pcmFormatInt16,
    sampleRate: 16_000,    // nil = 跟隨麥克風硬體取樣率（不重新取樣）
    channelCount: 1,
    chunkDuration: 0.04,   // 每包秒數
    interleaved: true)
let streamer = MicrophoneStreamer(configuration: configuration)
```

擷取到的硬體緩衝會以 `AVAudioConverter` 轉成上述格式，必要時包含重新取樣（如硬體 48 kHz → 16 kHz）。

## 需求

- iOS 14.0+（套件亦可在 macOS 11+ 建置，session 管理為 iOS 專屬、macOS 上略過）
- 於 `Info.plist` 宣告 `NSMicrophoneUsageDescription`
- Swift 6 工具鏈

## 授權

Apache-2.0。見 [LICENSE](LICENSE) 與 [NOTICE](NOTICE)。
