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

    // MARK: - Initialization
    init() {
        // Check initial permission status without prompting
        updatePermissionStatus()
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
            self.permissionStatus = .granted
            self.errorMessage = nil // Clear any previous error
        } else {
            print("Microphone permission DENIED by user.")
            self.permissionStatus = .denied
            // Optionally set an error message
            self.errorMessage = "Microphone access was denied. Please enable it in Settings."
        }
    }

    /// Configures the AVAudioSession for recording.
    /// Must be called *after* permission is granted.
    func configureSession() throws {
        print("Configuring AVAudioSession...")
        guard permissionStatus == .granted else {
            print("Cannot configure session: Microphone permission not granted.")
            throw AudioEngineError.permissionDenied
        }

        do {
            // Set the session category, mode, and options.
            // .playAndRecord allows recording and potential future playback.
            // .measurement mode is suitable for signal processing.
            // Options: duckOthers lowers other app volumes, allowBluetoothA2DP enables BT output.
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .allowBluetoothA2DP])

            // Activate the audio session
            try audioSession.setActive(true)
            print("AVAudioSession configured and activated.")
            errorMessage = nil // Clear previous errors

        } catch let error as NSError {
            print("Failed to configure AVAudioSession: \(error.localizedDescription)")
            errorMessage = "Failed to configure audio session: \(error.localizedDescription)"
            // Map the underlying NSError to our custom error type
            throw AudioEngineError.configurationError(error.localizedDescription)
        }
    }

    /// Sets up the AVAudioEngine, installs a tap on the input node.
    /// Must be called *after* session is configured.
    func setupEngine() throws {
        print("Setting up AVAudioEngine...")

        let inputFormat = inputNode.outputFormat(forBus: 0)
        let outputFormat = inputNode.inputFormat(forBus: 0)

        // Check if sample rates match - required by some models like Whisper
        // Whisper expects 16kHz. We might need resampling if the hardware default is different.
        guard inputFormat.sampleRate == outputFormat.sampleRate else {
             // This scenario requires adding an AVAudioMixerNode for format conversion.
             // For simplicity now, we'll throw an error if formats don't match.
             // TODO: Implement resampling if necessary.
             let message = "Input (\(inputFormat.sampleRate)Hz) and output (\(outputFormat.sampleRate)Hz) sample rates do not match. Resampling needed."
             print("ERROR: \(message)")
             errorMessage = message
             throw AudioEngineError.engineSetupError(message)
         }

        print("Audio format: \(inputFormat)")

        // Install the tap on the input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] (buffer, when) in
            // Send the captured buffer to the Combine subject
            self?.audioBufferSubject.send(buffer)
        }

        // Prepare the audio engine (allocates resources)
        audioEngine.prepare()
        print("AVAudioEngine setup complete and tap installed.")
        errorMessage = nil // Clear previous errors

        // Note: We catch errors during the actual start() phase
    }

    /// Starts the audio engine and begins capturing audio buffers.
    /// Ensures permission is granted and session/engine are configured.
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
            errorMessage = "Microphone permission not granted."
            throw AudioEngineError.permissionDenied
        }

        // Note: Assuming configureSession() and setupEngine() were called successfully beforehand.
        // In a production app, you might add state checks here.

        // 4. Start engine
        do {
            try audioEngine.start()
            print("AudioEngine successfully started.")
            // Ensure UI updates are on the main thread
            DispatchQueue.main.async {
                self.errorMessage = nil // Clear previous errors
            }
        } catch let error as NSError {
            print("ERROR: Failed to start AVAudioEngine: \(error.localizedDescription)")
            // Ensure UI updates are on the main thread
            DispatchQueue.main.async {
                self.errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
            }
            throw AudioEngineError.startFailure(error.localizedDescription)
        }
    }

    /// Stops the audio engine and releases resources.
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

        // 2. Remove tap
        // Ensure tap is removed *after* stopping the engine
        inputNode.removeTap(onBus: 0)
        print("Audio tap removed.")

        // 3. Optionally deactivate audio session
        // It's good practice to deactivate the session when not recording.
        do {
            try audioSession.setActive(false)
            print("AVAudioSession deactivated.")
        } catch let error as NSError {
            // Log error but don't throw, as stopping should proceed.
            print("WARNING: Failed to deactivate AVAudioSession: \(error.localizedDescription)")
            // We might not want to show this specific error to the user unless it persists.
            // Ensure UI updates are on the main thread if uncommented
            // DispatchQueue.main.async {
            //     self.errorMessage = "Failed to release audio session: \(error.localizedDescription)"
            // }
        }
    }

    // MARK: - Private Helpers

    /// Updates the internal permission status based on the current session state.
    private func updatePermissionStatus() {
       print("Updating permission status...")
       switch AVAudioSession.sharedInstance().recordPermission {
       case .granted:
           permissionStatus = .granted
           print("Initial permission status: granted")
       case .denied:
           permissionStatus = .denied
           print("Initial permission status: denied")
       case .undetermined:
           permissionStatus = .undetermined
           print("Initial permission status: undetermined")
       @unknown default:
           permissionStatus = .undetermined
           print("Initial permission status: unknown (treating as undetermined)")
       }
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
            // Ensure stop() call and any related UI updates happen on main thread
            DispatchQueue.main.async {
                // Stop the engine when interruption begins
                self.stop()
                // Update UI state if necessary (e.g., show paused state)
                // self.errorMessage = "Recording paused due to interruption." // Example
            }

        case .ended:
            print("Audio session interruption ended.")
            // Ensure UI updates and potential engine restart happen on main thread
            DispatchQueue.main.async {
                // Check if the interruption options indicate we should resume
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        print("Interruption ended with .shouldResume option. Restarting engine.")
                        // Asynchronously attempt to restart the engine
                        Task {
                            do {
                                // Ensure session is configured before starting
                                // Depending on state management, might need to re-run configureSession/setupEngine
                                // For simplicity, assuming they are still valid.
                                try await self.start() // Call start on self
                            } catch {
                                print("ERROR: Failed to restart engine after interruption: \(error.localizedDescription)")
                                // Update UI or state to reflect failure to resume
                                // Ensure this errorMessage update is also on the main thread (already inside DispatchQueue.main.async)
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

// Example Error Enum (define properly)
enum AudioEngineError: Error {
    case permissionDenied
    case configurationError(String)
    case engineSetupError(String)
    case startFailure(String)
} 
