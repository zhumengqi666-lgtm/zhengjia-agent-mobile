import AVFoundation
import Capacitor
import Speech

@objc(AgentSpeechPlugin)
final class AgentSpeechPlugin: CAPPlugin, CAPBridgedPlugin {
    let identifier = "AgentSpeechPlugin"
    let jsName = "AgentSpeech"
    let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "prepare", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "start", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stop", returnType: CAPPluginReturnPromise)
    ]

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var latestTranscript = ""
    private var stopping = false

    @objc func prepare(_ call: CAPPluginCall) {
        requestAccess { granted, message in
            if granted {
                call.resolve()
            } else {
                call.reject(message)
            }
        }
    }

    @objc func start(_ call: CAPPluginCall) {
        let locale = call.getString("locale") ?? "zh-CN"
        requestAccess { [weak self] granted, message in
            guard let self else { return call.reject("语音识别组件不可用") }
            guard granted else { return call.reject(message) }
            self.startRecognition(locale: locale, call: call)
        }
    }

    @objc func stop(_ call: CAPPluginCall) {
        stopRecognition(emitFinal: true)
        call.resolve()
    }

    private func requestAccess(completion: @escaping (Bool, String) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async { completion(false, "请在系统设置中允许语音识别权限") }
                return
            }

            let audioSession = AVAudioSession.sharedInstance()
            switch audioSession.recordPermission {
            case .granted:
                DispatchQueue.main.async { completion(true, "") }
            case .denied:
                DispatchQueue.main.async { completion(false, "请在系统设置中允许麦克风权限") }
            case .undetermined:
                audioSession.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        completion(granted, granted ? "" : "请在系统设置中允许麦克风权限")
                    }
                }
            @unknown default:
                DispatchQueue.main.async { completion(false, "无法确认麦克风权限") }
            }
        }
    }

    private func startRecognition(locale: String, call: CAPPluginCall) {
        stopRecognition(emitFinal: false)
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)), recognizer.isAvailable else {
            call.reject("当前设备的语音识别服务暂不可用")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(iOS 16.0, *) { request.addsPunctuation = true }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                call.reject("麦克风没有返回有效音频")
                return
            }

            latestTranscript = ""
            stopping = false
            recognitionRequest = request
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                DispatchQueue.main.async {
                    if let result {
                        self.latestTranscript = result.bestTranscription.formattedString
                        self.notifyListeners("transcript", data: [
                            "text": self.latestTranscript,
                            "final": result.isFinal
                        ])
                    }
                    if let error, !self.stopping {
                        self.notifyListeners("speechError", data: ["message": error.localizedDescription])
                        self.stopRecognition(emitFinal: false)
                    }
                }
            }

            audioEngine.prepare()
            try audioEngine.start()
            call.resolve()
        } catch {
            stopRecognition(emitFinal: false)
            call.reject("语音识别启动失败：\(error.localizedDescription)")
        }
    }

    private func stopRecognition(emitFinal: Bool) {
        stopping = true
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        if emitFinal, !latestTranscript.isEmpty {
            notifyListeners("transcript", data: ["text": latestTranscript, "final": true])
        }
        latestTranscript = ""
    }
}
