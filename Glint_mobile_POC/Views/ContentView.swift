//
//  ContentView.swift
//  Glint_mobile_POC
//
//  Created by Tomoyuki Kano on 5/2/25.
//

import SwiftUI
import Combine // Needed for .onReceive

struct ContentView: View {
    // Instantiate the AudioEngine using @StateObject
    @StateObject private var audioEngine = AudioEngine()
    // Instantiate TranscriptionService, passing the audioEngine instance
    @StateObject private var transcriptionService: TranscriptionService

    // State to track buffer reception (from AudioEngine directly for now)
    @State private var receivingBuffers = false
    @State private var bufferCount = 0
    @State private var cancellable: AnyCancellable?
    // Track if configureSession was successful
    @State private var isSessionConfigured = false

    // Custom initializer to pass audioEngine to transcriptionService
    init() {
        let engine = AudioEngine()
        _audioEngine = StateObject(wrappedValue: engine)
        _transcriptionService = StateObject(wrappedValue: TranscriptionService(audioEngine: engine))
        print("ContentView initialized with new AudioEngine and TranscriptionService.")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("AudioEngine Test")
                .font(.title)
                .frame(maxWidth: .infinity, alignment: .center)

            Divider()

            // Status Section
            VStack(alignment: .leading) {
                Text("Status:").font(.headline)
                Text(" • Permission: \(audioEngine.permissionStatus)")
                Text(" • Engine Running: \(audioEngine.isRunning ? "Yes" : "No")")
                // Updated state variable name
                Text(" • Session Configured: \(isSessionConfigured ? "Yes" : "No")")
                Text(" • Receiving Buffers: \(receivingBuffers ? "Yes (Count: \(bufferCount))" : "No")")
                // Add TranscriptionService status
                Text(" • Transcribing: \(transcriptionService.isTranscribing ? "Yes" : "No")")
                // Display placeholder transcript
                Text(" • Transcript: \(transcriptionService.currentTranscript)")
                    .lineLimit(3) // Limit lines displayed
            }

            // Error Display
            if let audioError = audioEngine.errorMessage {
                Text("Audio Error: \(audioError)")
                    .foregroundColor(.red)
                    .padding(.vertical, 5)
            }
            if let transcriptionError = transcriptionService.errorMessage {
                Text("Transcription Error: \(transcriptionError)")
                    .foregroundColor(.orange) // Use a different color? 
                    .padding(.vertical, 5)
            }

            Divider()

            // Controls Section
            VStack(spacing: 10) {
                 Button {
                     Task {
                         await audioEngine.requestPermission()
                     }
                 } label: {
                     Label("Request Mic Permission", systemImage: "mic.badge.plus")
                 }
                 .buttonStyle(.bordered)
                 .disabled(audioEngine.permissionStatus != .undetermined)

                 // Renamed button slightly for clarity
                 Button {
                    Task {
                        do {
                            if audioEngine.permissionStatus == .granted {
                                // Only configure the session here
                                try audioEngine.configureSession() 
                                // Removed setupEngine call
                                isSessionConfigured = true // Mark configuration as done
                                print("Configure Session Successful")
                            } else {
                                print("Configure Session Error: Permission not granted")
                                // Error message is handled internally by configureSession
                            }
                        } catch {
                            print("Configure Session Error: \(error)")
                            isSessionConfigured = false // Reset on error
                            // Error message should be set within AudioEngine methods
                        }
                    }
                 } label: {
                    // Renamed label slightly
                    Label("Configure Session", systemImage: "gearshape.fill") 
                 }
                 .buttonStyle(.bordered)
                  // Updated disabled logic
                 .disabled(audioEngine.permissionStatus != .granted || isSessionConfigured)

                HStack {
                    Button {
                        Task {
                            do {
                               // Correctly call the async throws start method
                               try await audioEngine.start() 
                            } catch {
                               print("Start Error: \(error.localizedDescription)")
                                // Error message should be set within AudioEngine's start method
                            }
                        }
                    } label: {
                        Label("Start", systemImage: "play.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                     // Updated disabled logic
                    .disabled(audioEngine.permissionStatus != .granted || !isSessionConfigured || audioEngine.isRunning)

                    Button {
                        audioEngine.stop()
                        // Also reset buffer state when stopping manually
                        receivingBuffers = false
                        bufferCount = 0
                    } label: {
                        Label("Stop", systemImage: "stop.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(!audioEngine.isRunning)
                }
                .frame(maxWidth: .infinity)
                
                // Add Transcription Controls (Placeholder)
                HStack {
                     Button {
                         // Start both engine and transcription logic
                         Task {
                            do {
                                try await audioEngine.start()
                                // Only start transcription if engine started successfully
                                if audioEngine.isRunning {
                                     transcriptionService.startTranscription()
                                }
                            } catch {
                                print("Start Error: \(error.localizedDescription)")
                            }
                         }
                     } label: {
                         Label("Start Recording", systemImage: "record.circle.fill")
                     }
                     .buttonStyle(.borderedProminent)
                     .tint(.blue) 
                     .disabled(audioEngine.permissionStatus != .granted || !isSessionConfigured || audioEngine.isRunning)
                     
                      Button {
                         // Stop both
                         audioEngine.stop()
                         transcriptionService.stopTranscription()
                         receivingBuffers = false
                         bufferCount = 0
                     } label: {
                         Label("Stop Recording", systemImage: "stop.circle.fill")
                     }
                     .buttonStyle(.borderedProminent)
                     .tint(.purple)
                     .disabled(!audioEngine.isRunning)
                }
                .frame(maxWidth: .infinity)
            }

            Spacer() // Push content to top
        }
        .padding()
        .onAppear(perform: setupBufferSubscription) // Subscribe on appear
        .onDisappear { // Unsubscribe on disappear
            cancellable?.cancel()
            // Ensure engine is stopped if view disappears
            if audioEngine.isRunning {
                audioEngine.stop()
            }
        }
    }

    // Function to setup the subscription
    private func setupBufferSubscription() {
        // Reset state on appear
        receivingBuffers = false
        bufferCount = 0

        cancellable = audioEngine.audioBufferSubject
            .receive(on: DispatchQueue.main) // Update state on main thread
            .sink(receiveCompletion: { completion in
                print("Buffer subject completed: \(completion)")
                self.receivingBuffers = false // Reset on completion/error
                self.bufferCount = 0
            }, receiveValue: { buffer in
                if !self.receivingBuffers { // Only print first time
                     print("Receiving audio buffers...")
                }
                self.receivingBuffers = true
                self.bufferCount += 1
                // Avoid printing buffer details unless debugging - it's very noisy
                // print("Received buffer: \(buffer.frameLength) frames at \(buffer.format.sampleRate) Hz")
            })
         print("Buffer subscription active.")
    }
}

// Helper extension to make permissionStatus printable (improves UI Text)
extension MicrophonePermissionStatus: CustomStringConvertible {
    var description: String {
        switch self {
        case .undetermined: return "Undetermined"
        case .granted: return "Granted"
        case .denied: return "Denied"
        }
    }
}

// Preview Provider
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        // Need to adjust preview provider if init changes significantly,
        // but for now, the default init might still work visually.
        ContentView()
    }
}
