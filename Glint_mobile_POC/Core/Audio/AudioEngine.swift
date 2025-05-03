// Glint_mobile_POC/Core/Audio/AudioEngine.swift

import Foundation
import AVFoundation
import Combine // To publish audio buffers

// Enum to represent microphone permission status
enum MicrophonePermissionStatus {
    case undetermined
    case granted
    case denied
}

// Main class to handle audio capture
class AudioEngine: ObservableObject {

    // MARK: - Published Properties
    @Published var permissionStatus: MicrophonePermissionStatus = .undetermined
    @Published var errorMessage: String? = nil // To report errors

    // MARK: - Public Properties
    // Publisher for raw audio buffers
    let audioBufferSubject = PassthroughSubject<AVAudioPCMBuffer, Error>()

    // Computed property to expose engine running state
    var isRunning: Bool {
        audioEngine.isRunning
    }

    // MARK: - Private Properties
    private let audioEngine = AVAudioEngine()
    private let audioSession = AVAudioSession.sharedInstance()
    private var inputNode: AVAudioInputNode { audioEngine.inputNode } // Convenience accessor
    private var isTapInstalled = false // Track tap state

    // MARK: - Initialization
    init() {
        // Check initial permission status without prompting
        // Call the main-actor isolated function from a Task
        Task {
            await updatePermissionStatus()
        }
        // Configure session interruption handling
        setupInterruptionObserver()
        // Configure route change handling (optional)
        // setupRouteChangeObserver()
    }

    // MARK: - Public Methods

    /// Requests microphone permission from the user. Updates `permissionStatus`.
    @MainActor // Ensure UI-related property updates happen on the main thread
    func requestPermission() async {
        print("Requesting microphone permission...")
        let granted = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        if granted {
            print("Microphone permission GRANTED by user.")
            DispatchQueue.main.async {
                self.permissionStatus = .granted
                self.errorMessage = nil // Clear any previous error
            }
        } else {
            print("Microphone permission DENIED by user.")
            DispatchQueue.main.async {
                self.permissionStatus = .denied
                // Optionally set an error message
                self.errorMessage = "Microphone access was denied. Please enable it in Settings."
            }
        }
    }

    /// Configures the AVAudioSession for recording.
    /// Must be called *after* permission is granted.
    /// Does NOT activate the session.
    func configureSession() throws {
        print("Configuring AVAudioSession...")
        guard permissionStatus == .granted else {
            print("Cannot configure session: Microphone permission not granted.")
            throw AudioEngineError.permissionDenied
        }

        do {
            // Set the session category, mode, and options.
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .allowBluetoothA2DP])
            print("AVAudioSession category and mode configured.")
            // Activation happens in start()
            DispatchQueue.main.async { self.errorMessage = nil }

        } catch let error as NSError {
            print("Failed to configure AVAudioSession: \(error.localizedDescription)")
            let message = "Failed to configure audio session: \(error.localizedDescription)"
            DispatchQueue.main.async { self.errorMessage = message }
            throw AudioEngineError.configurationError(message)
        }
    }

    /// Starts the audio engine: activates session, prepares engine, installs tap, starts engine.
    /// Ensures permission is granted and session is configured.
    func start() async throws {
        print("Attempting to start AudioEngine...")

        // Prevent starting if already running
        guard !audioEngine.isRunning else {
            print("AudioEngine is already running.")
            return
        }

        // 1. Check permission status
        guard permissionStatus == .granted else {
            print("ERROR: Attempted to start AudioEngine without permission.")
            let message = "Microphone permission not granted."
            DispatchQueue.main.async { self.errorMessage = message }
            throw AudioEngineError.permissionDenied
        }

        // Note: Assuming configureSession() was called successfully beforehand.

        // 2. Activate Session, Prepare Engine, Install Tap
        do {
            // Ensure the session is active before preparing/starting.
            print("Activating audio session...")
            try audioSession.setActive(true)
            print("Audio session activated.")

            // Prepare engine and install tap
            try self.prepareAndInstallTap()

            // 3. Start the engine
            print("Starting engine...")
            try audioEngine.start()
            print("AudioEngine successfully started.")
            DispatchQueue.main.async {
                self.errorMessage = nil // Clear previous errors
            }
        } catch let error as NSError {
            print("ERROR: Failed to start AVAudioEngine: \(error.localizedDescription)")
            let message = "Failed to start audio engine: \(error.localizedDescription)"
            // Attempt to clean up if start failed
            self.stop() // Call stop to ensure resources are released
            DispatchQueue.main.async {
                self.errorMessage = message
            }
            throw AudioEngineError.startFailure(message)
        }
    }

    /// Stops the audio engine, removes tap, and deactivates session.
    func stop() {
        print("Attempting to stop AudioEngine...")

        // Stop only if the engine is running
        guard audioEngine.isRunning else {
            print("AudioEngine is not running.")
            return
        }

        // 1. Stop engine
        audioEngine.stop()
        print("AudioEngine stopped.")

        // 2. Remove tap if installed
        if isTapInstalled {
            inputNode.removeTap(onBus: 0)
            isTapInstalled = false
            print("Audio tap removed.")
        }

        // 3. Deactivate audio session
        do {
            try audioSession.setActive(false)
            print("AVAudioSession deactivated.")
        } catch let error as NSError {
            // Log error but don't necessarily show to user
            print("WARNING: Failed to deactivate AVAudioSession: \(error.localizedDescription)")
        }
        // Clear error on successful stop
        DispatchQueue.main.async { self.errorMessage = nil }
    }

    // MARK: - Private Helpers

    /// Prepares the audio engine and installs the audio tap.
    private func prepareAndInstallTap() throws {
        print("Preparing engine and installing tap...")

        let inputFormat = inputNode.outputFormat(forBus: 0)
        let outputFormat = inputNode.inputFormat(forBus: 0)

        // Check sample rates
        guard inputFormat.sampleRate == outputFormat.sampleRate else {
            let message = "Input (\(inputFormat.sampleRate)Hz) and output (\(outputFormat.sampleRate)Hz) sample rates do not match. Resampling needed."
            print("ERROR: \(message)")
            DispatchQueue.main.async { self.errorMessage = message }
            throw AudioEngineError.engineSetupError(message)
        }
        print("Audio format: \(inputFormat)")

        // Install the tap
        // Avoid installing tap if already present (though removeTap in stop should prevent this)
        if !isTapInstalled {
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] (buffer, when) in
                // Send the captured buffer to the Combine subject
                // Note: Subscriber must handle main thread dispatch if updating UI directly
                self?.audioBufferSubject.send(buffer)
            }
            isTapInstalled = true
            print("Audio tap installed.")
        }

        // Prepare the audio engine
        audioEngine.prepare()
        print("AVAudioEngine prepared.")
    }

    /// Updates the internal permission status based on the current session state.
    @MainActor
    private func updatePermissionStatus() {
        print("Updating permission status...")
        let currentStatus: MicrophonePermissionStatus
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            currentStatus = .granted
            print("Initial permission status: granted")
        case .denied:
            currentStatus = .denied
            print("Initial permission status: denied")
        case .undetermined:
            currentStatus = .undetermined
            print("Initial permission status: undetermined")
        @unknown default:
            currentStatus = .undetermined
            print("Initial permission status: unknown (treating as undetermined)")
        }
        // Update @Published property on main thread
        self.permissionStatus = currentStatus
    }

    /// Sets up an observer for AVAudioSession interruptions (e.g., phone calls).
    private func setupInterruptionObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: audioSession // Observe interruptions for our session
        )
        print("Interruption observer set up.")
    }

    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            print("Interruption notification received with invalid user info.")
            return
        }

        switch type {
        case .began:
            print("Audio session interruption began. Stopping engine.")
            // Ensure stop() call happens on main thread as it updates UI state
            DispatchQueue.main.async {
                self.stop()
                self.errorMessage = "Recording paused due to interruption."
            }

        case .ended:
            print("Audio session interruption ended.")
            // Ensure UI updates and potential engine restart happen on main thread
            DispatchQueue.main.async {
                self.errorMessage = nil // Clear interruption message
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        print("Interruption ended with .shouldResume option. Attempting restart...")
                        Task {
                            do {
                                try await self.start()
                            } catch {
                                print("ERROR: Failed to restart engine after interruption: \(error.localizedDescription)")
                                self.errorMessage = "Failed to resume recording after interruption."
                            }
                        }
                    } else {
                        print("Interruption ended without .shouldResume option.")
                    }
                } else {
                    print("Interruption ended without options info.")
                }
            }
        @unknown default:
            print("Unknown interruption type received.")
        }
    }

    // Optional: Handle route changes (headphones plugged/unplugged)
    // private func setupRouteChangeObserver() { ... }
}

// Custom Error Enum
enum AudioEngineError: Error, LocalizedError {
    case permissionDenied
    case configurationError(String)
    case engineSetupError(String)
    case startFailure(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Microphone permission was denied."
        case .configurationError(let msg): return "Audio session configuration failed: \(msg)"
        case .engineSetupError(let msg): return "Audio engine setup failed: \(msg)"
        case .startFailure(let msg): return "Failed to start audio engine: \(msg)"
        }
    }
}

