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

    // State to track buffer reception
    @State private var receivingBuffers = false
    @State private var bufferCount = 0
    @State private var cancellable: AnyCancellable?
    @State private var setupComplete = false // Track if configure/setup was successful

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
                Text(" • Setup Complete: \(setupComplete ? "Yes" : "No")")
                Text(" • Receiving Buffers: \(receivingBuffers ? "Yes (Count: \(bufferCount))" : "No")")
            }

            // Error Display
            if let error = audioEngine.errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
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

                 Button {
                    Task {
                        do {
                            if audioEngine.permissionStatus == .granted {
                                try audioEngine.configureSession()
                                try audioEngine.setupEngine()
                                setupComplete = true // Mark setup as done
                                print("Configure & Setup Successful")
                            } else {
                                print("Configure/Setup Error: Permission not granted")
                                // Error message is handled internally
                            }
                        } catch {
                            print("Configure/Setup Error: \(error)")
                            setupComplete = false // Reset on error
                            // Error message should be set within AudioEngine methods
                        }
                    }
                 } label: {
                    Label("Configure Session & Setup Engine", systemImage: "gearshape.2.fill")
                 }
                 .buttonStyle(.bordered)
                 .disabled(audioEngine.permissionStatus != .granted || setupComplete) // Disable if not granted or already set up

                HStack {
                    Button {
                        Task {
                            do {
                               try await audioEngine.start()
                            } catch {
                               print("Start Error: \(error)")
                                // Error message should be set within AudioEngine methods
                            }
                        }
                    } label: {
                        Label("Start", systemImage: "play.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(audioEngine.permissionStatus != .granted || !setupComplete || audioEngine.isRunning)

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
        ContentView()
    }
}
