import AVFoundation
import CoreMedia
import Darwin
import Flutter
import Network
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let networkStatus = NetworkStatusMonitor()
  private let bluetoothAudioDevices = BluetoothAudioDevicesStreamHandler()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()
    let capabilitiesChannel = FlutterMethodChannel(
      name: "com.chiraitori.pixelplay/device_capabilities",
      binaryMessenger: messenger
    )
    capabilitiesChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "unavailable", message: "Application delegate is unavailable.", details: nil))
        return
      }

      switch call.method {
      case "getCapabilities":
        self.readCapabilities(result: result)
      case "startBluetoothDiscovery":
        // iOS cannot scan nearby classic Bluetooth audio accessories. It can
        // report the connected audio route, which is what we expose here.
        self.bluetoothAudioDevices.emit()
        result(!self.bluetoothAudioDevices.audioDevices().isEmpty)
      case "stopBluetoothDiscovery":
        result(nil)
      case "getBluetoothAudioDevices":
        result(self.bluetoothAudioDevices.audioDevices())
      case "setMediaVolume":
        // iOS deliberately does not permit apps to set system media volume.
        result(self.mediaVolumeResult(status: "unsupported"))
      case "openAudioOutputSettings", "openBluetoothSettings", "openWifiSettings":
        self.openApplicationSettings()
        result(nil)
      case "setRingtone":
        // Third-party iOS apps cannot set system ringtone, alarm, or
        // notification tones.
        result([
          "status": "unsupported",
          "message": "iOS does not allow apps to set system tones.",
        ])
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    FlutterEventChannel(
      name: "com.chiraitori.pixelplay/bluetooth_audio_devices",
      binaryMessenger: messenger
    ).setStreamHandler(bluetoothAudioDevices)

    let audioMetadataChannel = FlutterMethodChannel(
      name: "com.chiraitori.pixelplay/audio_meta",
      binaryMessenger: messenger
    )
    audioMetadataChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "getAudioMeta" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let arguments = call.arguments as? [String: Any]
      guard let uri = arguments?["uri"] as? String, !uri.isEmpty else {
        result(nil)
        return
      }
      guard let self else {
        result(FlutterError(code: "unavailable", message: "Application delegate is unavailable.", details: nil))
        return
      }
      self.readAudioMetadata(uri: uri, result: result)
    }
  }

  private func readCapabilities(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
      let notificationsEnabled: Bool
      switch settings.authorizationStatus {
      case .authorized, .provisional:
        notificationsEnabled = true
      default:
        notificationsEnabled = false
      }
      DispatchQueue.main.async {
        guard let self else {
          result(FlutterError(code: "unavailable", message: "Application delegate is unavailable.", details: nil))
          return
        }
        result(self.capabilities(notificationsEnabled: notificationsEnabled))
      }
    }
  }

  private func capabilities(notificationsEnabled: Bool) -> [String: Any] {
    let audioSession = AVAudioSession.sharedInstance()
    let output = bluetoothAudioDevices.connectedBluetoothOutput()
    let outputSampleRate = audioSession.sampleRate
    let framesPerBuffer = Int((audioSession.ioBufferDuration * outputSampleRate).rounded())
    let volume = mediaVolumeResult(status: nil)
    let osVersion = ProcessInfo.processInfo.operatingSystemVersion

    return [
      "platformName": "iOS",
      "manufacturer": "Apple",
      "model": UIDevice.current.model,
      "sdk": osVersion.majorVersion,
      "release": UIDevice.current.systemVersion,
      "abis": [machineArchitecture()],
      "outputSampleRate": Int(outputSampleRate.rounded()),
      "framesPerBuffer": framesPerBuffer,
      "mediaVolume": volume["mediaVolume"] as Any,
      "mediaVolumeMax": volume["mediaVolumeMax"] as Any,
      "wifiOn": networkStatus.isWiFiConnected,
      "wifiConnected": networkStatus.isWiFiConnected,
      "wifiSsid": NSNull(),
      // iOS does not expose the system-wide Bluetooth switch. A connected
      // output is the reliable audio-specific state available to an app.
      "bluetoothEnabled": output != nil,
      "bluetoothActive": output != nil,
      "bluetoothName": output?["name"] ?? NSNull(),
      "decoderTypes": ["audio/mpeg", "audio/mp4a-latm", "audio/flac", "audio/wav", "audio/aiff"],
      "dynamicColor": false,
      "notificationsEnabled": notificationsEnabled,
      "exactAlarms": false,
      "batteryOptimized": false,
      "automotive": false,
      "watch": false,
      "lowLatencyAudio": audioSession.ioBufferDuration > 0 && audioSession.ioBufferDuration <= 0.01,
      "proAudio": false,
    ]
  }

  private func mediaVolumeResult(status: String?) -> [String: Any] {
    var values: [String: Any] = [
      "mediaVolume": Int((AVAudioSession.sharedInstance().outputVolume * 100).rounded()),
      "mediaVolumeMax": 100,
    ]
    if let status {
      values["status"] = status
    }
    return values
  }

  private func openApplicationSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(url, options: [:])
  }

  private func readAudioMetadata(uri: String, result: @escaping FlutterResult) {
    let url: URL
    if let parsedURL = URL(string: uri), parsedURL.isFileURL {
      url = parsedURL
    } else {
      url = URL(fileURLWithPath: uri)
    }

    Task {
      let asset = AVURLAsset(url: url)
      do {
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
          await MainActor.run { result(nil) }
          return
        }

        let formatDescriptions = try await audioTrack.load(.formatDescriptions)
        let sampleRate = formatDescriptions
          .compactMap { $0.audioStreamBasicDescription?.mSampleRate }
          .first
          .map { Int($0.rounded()) }
        let estimatedDataRate = try await audioTrack.load(.estimatedDataRate)
        let bitrate = estimatedDataRate > 0
          ? Int(estimatedDataRate.rounded())
          : nil
        let metadata: [String: Any] = [
          "mimeType": self.mimeType(for: url) ?? NSNull(),
          "bitrate": bitrate ?? NSNull(),
          "sampleRate": sampleRate ?? NSNull(),
        ]
        await MainActor.run { result(metadata) }
      } catch {
        await MainActor.run { result(nil) }
      }
    }
  }

  private func mimeType(for url: URL) -> String? {
    switch url.pathExtension.lowercased() {
    case "mp3": return "audio/mpeg"
    case "m4a", "m4b", "m4p", "mp4": return "audio/mp4"
    case "aac": return "audio/aac"
    case "flac": return "audio/flac"
    case "wav", "wave": return "audio/wav"
    case "aif", "aiff", "aifc": return "audio/aiff"
    case "alac": return "audio/alac"
    case "amr": return "audio/amr"
    default: return nil
    }
  }

  private func machineArchitecture() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    return withUnsafePointer(to: &systemInfo.machine) { pointer in
      pointer.withMemoryRebound(to: CChar.self, capacity: 1) {
        String(cString: $0)
      }
    }
  }
}

private final class NetworkStatusMonitor {
  private let monitor = NWPathMonitor()
  private let queue = DispatchQueue(label: "com.chiraitori.pixelplay.network-status")
  private(set) var isWiFiConnected = false

  init() {
    monitor.pathUpdateHandler = { [weak self] path in
      self?.isWiFiConnected = path.status == .satisfied && path.usesInterfaceType(.wifi)
    }
    monitor.start(queue: queue)
  }

  deinit {
    monitor.cancel()
  }
}

private final class BluetoothAudioDevicesStreamHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var routeChangeObserver: NSObjectProtocol?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    routeChangeObserver = NotificationCenter.default.addObserver(
      forName: AVAudioSession.routeChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.emit()
    }
    emit()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    if let routeChangeObserver {
      NotificationCenter.default.removeObserver(routeChangeObserver)
      self.routeChangeObserver = nil
    }
    return nil
  }

  func emit() {
    eventSink?(audioDevices())
  }

  func audioDevices() -> [[String: Any]] {
    AVAudioSession.sharedInstance().currentRoute.outputs.compactMap { output in
      guard isBluetooth(output.portType) else { return nil }
      let name = output.portName.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !name.isEmpty else { return nil }
      return [
        "id": output.uid,
        "name": name,
        "address": NSNull(),
        "isConnected": true,
        "batteryPercent": NSNull(),
      ]
    }
  }

  func connectedBluetoothOutput() -> [String: Any]? {
    audioDevices().first
  }

  private func isBluetooth(_ portType: AVAudioSession.Port) -> Bool {
    switch portType {
    case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
      return true
    default:
      return false
    }
  }
}
