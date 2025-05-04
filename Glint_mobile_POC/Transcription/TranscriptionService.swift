// Glint_mobile_POC/Glint_mobile_POC/Transcription/TranscriptionService.swift

import Foundation
import Combine
import AVFoundation
import CoreML // Import CoreML for model handling

// Define potential errors for the transcription process
enum TranscriptionError: Error {
    case audioEngineError(Error)
    case modelLoadingError(String)
    case audioProcessingError(String)
    case inferenceError(String)
    case postProcessingError(String)
    case unknown(String)
}

// Service responsible for handling Core ML transcription based on audio input
class TranscriptionService: ObservableObject {

    // MARK: - Published Properties
    @Published var currentTranscript: String = "" // Holds the latest transcript
    @Published var errorMessage: String? = nil // Holds any error messages for the UI
    @Published var isTranscribing: Bool = false // Indicates if transcription is active

    // MARK: - Private Properties
    private let audioEngine: AudioEngine // Reference to the audio source
    private var cancellables = Set<AnyCancellable>() // To store Combine subscriptions

    // Core ML Models
    private var whisperEncoderModel: MLModel?
    private var whisperDecoderModel: MLModel?

    // Tokenizer for converting between text and token IDs
    private var whisperTokenizer: WhisperTokenizer? // Placeholder type

    // TODO: Add properties for Whisper pre/post-processing utilities (tokenizer)
    // TODO: Add state management for transcription segments/chunks

    // MARK: - Initialization
    init(audioEngine: AudioEngine) {
        self.audioEngine = audioEngine
        print("TranscriptionService initialized.")
        
        // Attempt to load models upon initialization
        do {
            try loadModels()
            print("Core ML models loaded successfully.")
            
            // --- Inspect Model Descriptions ---
            if let encoder = whisperEncoderModel {
                print("\n--- Encoder Model Description ---")
                print(encoder.modelDescription)
                print("Inputs:")
                encoder.modelDescription.inputDescriptionsByName.forEach { name, desc in
                    print(" - \(name): \(desc)")
                }
                print("Outputs:")
                encoder.modelDescription.outputDescriptionsByName.forEach { name, desc in
                    print(" - \(name): \(desc)")
                }
                print("---------------------------------")
            } else {
                print("WARNING: Encoder model is nil after loading attempt.")
            }
            
            if let decoder = whisperDecoderModel {
                print("\n--- Decoder Model Description ---")
                print(decoder.modelDescription)
                 print("Inputs:")
                decoder.modelDescription.inputDescriptionsByName.forEach { name, desc in
                    print(" - \(name): \(desc)")
                }
                print("Outputs:")
                decoder.modelDescription.outputDescriptionsByName.forEach { name, desc in
                    print(" - \(name): \(desc)")
                }
                print("---------------------------------")
            } else {
                 print("WARNING: Decoder model is nil after loading attempt.")
            }
            // -------------------------------------

        } catch let error as TranscriptionError {
            print("ERROR: Failed to load Core ML models: \(error)")
            // Set error message for UI feedback
            DispatchQueue.main.async {
                self.errorMessage = "Failed to load transcription models. Error: \(error)"
            }
            // Depending on the app's needs, you might want to handle this more gracefully
            // or prevent transcription from starting.
        } catch {
            print("ERROR: An unexpected error occurred during model loading: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "An unexpected error occurred loading models."
            }
        }

        subscribeToAudioEngine()
    }

    deinit {
        // Cancel subscriptions when the service is deallocated
        cancellables.forEach { $0.cancel() }
        print("TranscriptionService deinitialized.")
    }

    // MARK: - Public Methods

    /// Starts the transcription process (placeholder)
    func startTranscription() {
        print("Starting transcription...")
        // Reset state
        DispatchQueue.main.async {
            self.currentTranscript = ""
            self.errorMessage = nil
            self.isTranscribing = true
        }
        // In a real scenario, you might need to signal the model to start processing
        // For now, it relies on the audio buffer subscription being active
    }

    /// Stops the transcription process (placeholder)
    func stopTranscription() {
        print("Stopping transcription...")
        // Reset state
        DispatchQueue.main.async {
            self.isTranscribing = false
        }
        // In a real scenario, you might need to signal the model to finalize
        // and possibly clear internal buffers/state.
    }


    // MARK: - Private Methods

    /// Sets up the subscription to the AudioEngine's buffer publisher.
    private func subscribeToAudioEngine() {
        print("Subscribing to AudioEngine buffer subject...")
        audioEngine.audioBufferSubject
            .sink(receiveCompletion: { [weak self] completion in
                // Handle completion (e.g., stream finished or error)
                DispatchQueue.main.async {
                    switch completion {
                    case .finished:
                        print("AudioEngine stream finished.")
                        // Optionally finalize transcription if needed
                        self?.isTranscribing = false
                    case .failure(let error):
                        print("ERROR: AudioEngine stream failed: \(error.localizedDescription)")
                        self?.errorMessage = "Audio stream error: \(error.localizedDescription)"
                        self?.isTranscribing = false
                        // Handle specific AudioEngine errors if necessary
                    }
                }
            }, receiveValue: { [weak self] buffer in
                // Process the received audio buffer
                // print("Received audio buffer, processing... (Sample count: \(buffer.frameLength))") // DEBUG: Can be noisy
                guard let self = self, self.isTranscribing else { return }

                // Process the buffer
                do {
                    let inputFeatures = try self.preprocessAudio(buffer: buffer)
                    
                    // Run inference
                    let tokenIDs = try self.runInference(audioFeatures: inputFeatures)
                    
                    // Post-process token IDs to text
                    let transcriptSegment = self.postprocessTokens(tokens: tokenIDs)
                    
                    // Update the published transcript on the main thread
                    DispatchQueue.main.async {
                       // TODO: Implement proper transcript accumulation (handling partial vs final)
                       self.currentTranscript = transcriptSegment // Replace for now
                       print("Updated transcript: \(transcriptSegment)")
                    }

                } catch let error as TranscriptionError {
                    print("ERROR: Transcription processing failed: \(error)")
                    DispatchQueue.main.async {
                         // Optionally display more specific error details
                        self.errorMessage = "Transcription failed: \(error)"
                        self.isTranscribing = false // Stop transcription on error
                    }
                } catch {
                    print("ERROR: Unexpected error during transcription processing: \(error)")
                    DispatchQueue.main.async {
                        self.errorMessage = "An unexpected error occurred during transcription."
                        self.isTranscribing = false // Stop transcription on error
                    }
                }
            })
            .store(in: &cancellables) // Store the subscription
        print("Subscription to AudioEngine established.")
    }

    /// Loads the Whisper Core ML encoder and decoder models from the bundle.
    /// Throws a `TranscriptionError.modelLoadingError` if models cannot be found or loaded.
    private func loadModels() throws {
        print("Attempting to load Core ML models...")

        // Configuration for model loading (can be customized, e.g., for CPU/GPU/ANE)
        let config = MLModelConfiguration()
        // config.computeUnits = .cpuAndGPU // Example: Explicitly set compute units

        // Construct URLs for the compiled model packages in the app bundle
        guard let encoderURL = Bundle.main.url(forResource: "coreml-encoder-base.en", withExtension: "mlmodelc"),
              let decoderURL = Bundle.main.url(forResource: "coreml-decoder-base.en", withExtension: "mlmodelc") else {
            let errorMsg = "Could not find compiled Core ML model package(s) (mlmodelc) in the bundle."
            print("ERROR: \(errorMsg)")
            throw TranscriptionError.modelLoadingError(errorMsg)
        }

        print("Found model URLs:")
        print("- Encoder: \(encoderURL.path)")
        print("- Decoder: \(decoderURL.path)")
        
        // Load the models
        do {
            print("Loading Encoder model...")
            whisperEncoderModel = try MLModel(contentsOf: encoderURL, configuration: config)
            print("Encoder model loaded.")
            
            print("Loading Decoder model...")
            whisperDecoderModel = try MLModel(contentsOf: decoderURL, configuration: config)
            print("Decoder model loaded.")
            
        } catch {
            let errorMsg = "Failed to load MLModel(s): \(error.localizedDescription)"
            print("ERROR: \(errorMsg)")
            // Clear potentially partially loaded models
            whisperEncoderModel = nil
            whisperDecoderModel = nil
            throw TranscriptionError.modelLoadingError(errorMsg)
        }
        
        // Check if models were actually loaded (should be redundant due to try/catch, but good practice)
        guard whisperEncoderModel != nil, whisperDecoderModel != nil else {
             let errorMsg = "Model loading completed but models are unexpectedly nil."
             print("ERROR: \(errorMsg)")
             throw TranscriptionError.modelLoadingError(errorMsg)
        }
        
        print("Both Encoder and Decoder models loaded successfully.")
    }

    /// Prepares the audio buffer for the Whisper Core ML model.
    /// This involves converting the buffer to the expected format (e.g., 16kHz mono Float32)
    /// and packaging it as an MLMultiArray.
    /// - Parameter buffer: The AVAudioPCMBuffer received from the audio engine.
    /// - Returns: An MLMultiArray ready for the encoder model.
    /// - Throws: `TranscriptionError.audioProcessingError` if conversion fails.
    private func preprocessAudio(buffer: AVAudioPCMBuffer) throws -> MLMultiArray {
        // TODO: Determine the exact expected sample rate, format, and shape from the model description.
        //       Whisper typically expects 16kHz mono Float32 audio.
        let targetSampleRate = 16000.0
        let expectedInputLength = Int(targetSampleRate * 30) // Whisper processes 30s chunks

        print("Preprocessing buffer (Sample Rate: \(buffer.format.sampleRate), Channels: \(buffer.format.channelCount), Length: \(buffer.frameLength))...")

        // 1. Ensure audio is in the correct format (e.g., Float32)
        guard let floatData = buffer.floatChannelData else {
            throw TranscriptionError.audioProcessingError("Failed to get float channel data from buffer.")
        }
        
        // 2. Handle sample rate conversion if necessary
        // TODO: Implement resampling if buffer.format.sampleRate != targetSampleRate using AVAudioConverter.
        if buffer.format.sampleRate != targetSampleRate {
            print("WARNING: Sample rate mismatch (\(buffer.format.sampleRate) vs \(targetSampleRate)). Resampling needed but not implemented yet.")
             throw TranscriptionError.audioProcessingError("Sample rate conversion not implemented yet.")
            // Placeholder: For now, we'll throw an error if resampling is needed.
        }

        // 3. Handle channel conversion (mono)
        // TODO: Implement mixing down to mono if buffer.format.channelCount > 1
        if buffer.format.channelCount > 1 {
             print("WARNING: Multi-channel audio (\(buffer.format.channelCount)) detected. Mono conversion needed but not implemented yet.")
             throw TranscriptionError.audioProcessingError("Mono conversion not implemented yet.")
             // Placeholder: For now, we'll assume mono or throw.
        }
        
        // 4. Extract audio samples (assuming mono Float32 at correct sample rate for now)
        let channelData = floatData[0]
        let frameLength = Int(buffer.frameLength)
        let samples = UnsafeBufferPointer(start: channelData, count: frameLength)
        var audioSamples = [Float](samples)

        // 5. Pad or truncate audio to the expected input length (e.g., 30 seconds)
        // TODO: Implement proper handling for accumulating audio across multiple buffers
        //       until a full 30-second chunk is available.
        // For this initial step, we'll just pad/truncate the current buffer crudely.
        if audioSamples.count < expectedInputLength {
            // Pad with zeros
            audioSamples.append(contentsOf: [Float](repeating: 0.0, count: expectedInputLength - audioSamples.count))
            print("Padded audio samples to \(expectedInputLength)")
        } else if audioSamples.count > expectedInputLength {
            // Truncate
            audioSamples = Array(audioSamples.prefix(expectedInputLength))
            print("Truncated audio samples to \(expectedInputLength)")
        }

        // 6. Convert samples to MLMultiArray
        // The shape will depend on the specific model input requirements.
        // Often [1, channels, sequence_length] or similar.
        // Assuming [1, 1, expectedInputLength] for now.
        let shape: [NSNumber] = [1, 1, NSNumber(value: expectedInputLength)]
        guard let multiArray = try? MLMultiArray(shape: shape, dataType: .float32) else {
            throw TranscriptionError.audioProcessingError("Failed to create MLMultiArray for audio features.")
        }

        // Fill the MLMultiArray with sample data
        let ptr = multiArray.dataPointer.bindMemory(to: Float32.self, capacity: expectedInputLength)
        for i in 0..<expectedInputLength {
            ptr[i] = audioSamples[i]
        }
        
        print("Successfully created MLMultiArray for model input.")
        return multiArray
    }

    /// Runs the Whisper encoder and decoder models to generate token IDs from audio features.
    /// - Parameter audioFeatures: The `MLMultiArray` containing preprocessed audio data.
    /// - Returns: An array of predicted token IDs representing the transcript.
    /// - Throws: `TranscriptionError.inferenceError` if models are not loaded or prediction fails.
    private func runInference(audioFeatures: MLMultiArray) throws -> [Int] {
        guard let encoder = whisperEncoderModel, let decoder = whisperDecoderModel else {
            throw TranscriptionError.inferenceError("Core ML models not loaded.")
        }

        print("Running inference...")
        let startTime = Date()

        // 1. Create Encoder Input
        //    Requires knowing the exact input name defined in the Core ML model.
        let encoderInputName = "logmel_data" // ACTUAL name from model description
        guard let encoderInputProvider = try? MLDictionaryFeatureProvider(dictionary: [encoderInputName: audioFeatures]) else {
            throw TranscriptionError.inferenceError("Failed to create encoder input provider.")
        }
        
        // 2. Run Encoder Model
        print("Running encoder model...")
        let encoderOutputFeatures: MLFeatureProvider
        do {
             encoderOutputFeatures = try encoder.prediction(from: encoderInputProvider)
             print("Encoder model finished.")
        } catch {
            throw TranscriptionError.inferenceError("Encoder prediction failed: \(error.localizedDescription)")
        }

        // 3. Prepare for Decoder
        //    Extract encoder output (e.g., 'encoder_output' or similar name)
        //    Initialize the sequence of predicted tokens with a start-of-transcript token
        
        let encoderOutputName = "output" // ACTUAL name from model description
        guard let encoderOutput = encoderOutputFeatures.featureValue(for: encoderOutputName)?.multiArrayValue else {
             throw TranscriptionError.inferenceError("Failed to get encoder output from features.")
        }

        // TODO: Determine the actual start-of-transcript token ID for Whisper
        let startTokenID = 50257 // Placeholder
        // TODO: Determine the end-of-transcript token ID for Whisper
        let endTokenID = 50256   // Placeholder
        // TODO: Determine max sequence length if applicable
        let maxSequenceLength = 448 // Placeholder

        var predictedTokenIDs: [Int] = [startTokenID]
        // var decoderState: MLMultiArray? = nil // REMOVED - Model description shows no state

        print("Starting decoder loop...")
        // 4. Run Decoder Loop (Autoregressive decoding)
        for i in 0..<maxSequenceLength {
            // Prepare decoder input
            // Needs encoder output, current token sequence, and potentially state
            // Input names like "token_input", "encoder_output", "decoder_state" are placeholders
            let tokenInputName = "token_data" // ACTUAL name from model description
            let decoderAudioInputName = "audio_data" // ACTUAL name from model description
            // let decoderStateInputName: String? = "decoder_state_in" // REMOVED - No state
            // let decoderStateOutputName: String? = "decoder_state_out" // REMOVED - No state
            let logitsOutputName = "cast_112" // ACTUAL name from model description

            // Convert current token sequence to MLMultiArray
            // Shape [Batch, SequenceLength] -> [1, N]
            let currentTokensShape: [NSNumber] = [1, NSNumber(value: predictedTokenIDs.count)]
            guard let currentTokensMultiArray = try? MLMultiArray(shape: currentTokensShape, dataType: .int32) else {
                throw TranscriptionError.inferenceError("Failed to create MLMultiArray for decoder token input.")
            }
            let tokenPtr = currentTokensMultiArray.dataPointer.bindMemory(to: Int32.self, capacity: predictedTokenIDs.count)
            for (index, token) in predictedTokenIDs.enumerated() {
                tokenPtr[index] = Int32(token)
            }

            var decoderInputDict: [String: Any] = [
                tokenInputName: currentTokensMultiArray,
                decoderAudioInputName: encoderOutput // Pass encoder output using actual name
            ]
            
            // REMOVED State Handling Logic
            // // Include state if used by the model
            // if let state = decoderState {
            //      guard let stateInputName = decoderStateInputName else { // Now this check makes sense
            //          throw TranscriptionError.inferenceError("Decoder state input name is required but missing.")
            //      }
            //     decoderInputDict[stateInputName] = state
            // }
            
            guard let decoderInputProvider = try? MLDictionaryFeatureProvider(dictionary: decoderInputDict) else {
                throw TranscriptionError.inferenceError("Failed to create decoder input provider for step \(i).")
            }

            // Run decoder prediction
            let decoderOutputFeatures: MLFeatureProvider
            do {
                decoderOutputFeatures = try decoder.prediction(from: decoderInputProvider)
            } catch {
                 throw TranscriptionError.inferenceError("Decoder prediction failed at step \(i): \(error.localizedDescription)")
            }

            // Extract predicted logits
             guard let logits = decoderOutputFeatures.featureValue(for: logitsOutputName)?.multiArrayValue else {
                 throw TranscriptionError.inferenceError("Failed to get logits from decoder output at step \(i).")
             }
             
            // Extract updated state if applicable
             // REMOVED State Handling Logic
             // if let stateOutputName = decoderStateOutputName { // Now this check makes sense
             //    decoderState = decoderOutputFeatures.featureValue(for: stateOutputName)?.multiArrayValue
             // }

            // Find the token ID with the highest probability (argmax)
            // TODO: Implement more sophisticated sampling if needed (e.g., beam search, temperature sampling)
            let (nextTokenID, _) = argmax(logits)
            
            // Append the predicted token
            predictedTokenIDs.append(nextTokenID)
            // print("Decoder step \(i): Predicted token \(nextTokenID)") // DEBUG

            // Check for end-of-sequence token
            if nextTokenID == endTokenID {
                print("End-of-sequence token reached at step \(i).")
                break
            }
        }
        
        print("Decoder loop finished. Total tokens: \(predictedTokenIDs.count)")

        let endTime = Date()
        print("Inference completed in \(endTime.timeIntervalSince(startTime)) seconds.")

        // 5. Return the sequence of token IDs (excluding start token potentially)
        // return Array(predictedTokenIDs.dropFirst()) // Option: Exclude start token
         return predictedTokenIDs // Option: Include start token for context
    }
    
    /// Helper function to find the index (token ID) with the maximum value in the last dimension of an MLMultiArray.
    /// Assumes logits are in the last dimension.
    private func argmax(_ multiArray: MLMultiArray) -> (Int, Float) {
        // Determine the size of the last dimension (vocabulary size)
        let dimensions = multiArray.shape.map { $0.intValue }
        guard let vocabSize = dimensions.last else { return (0, 0.0) } // Or handle error
        
        // Calculate the offset to the start of the relevant data
        // Assumes shape like [batch, sequence, vocab_size] or similar, needs last element
        let elementCount = multiArray.count
        let offset = max(0, elementCount - vocabSize) // Start index of the last dimension's data
        
        let ptr = multiArray.dataPointer.bindMemory(to: Float32.self, capacity: elementCount)
        
        var maxValue: Float = -Float.infinity
        var maxIndex: Int = 0
        
        for i in 0..<vocabSize {
            let value = ptr[offset + i]
            if value > maxValue {
                maxValue = value
                maxIndex = i
            }
        }
        return (maxIndex, maxValue)
    }

    /// Converts an array of token IDs into a readable string using the Whisper tokenizer.
    /// - Parameter tokens: An array of integer token IDs predicted by the decoder.
    /// - Returns: The decoded transcript string.
    private func postprocessTokens(tokens: [Int]) -> String {
        guard let tokenizer = whisperTokenizer else {
            print("ERROR: Tokenizer not available for post-processing.")
            // In a real app, you might want to throw or handle this differently
            return "[Error: Tokenizer missing]"
        }
        
        print("Post-processing \(tokens.count) tokens...")
        
        // TODO: Implement the actual decoding using the tokenizer
        //       This might involve filtering special tokens (start, end, timestamps, etc.)
        //       and handling language detection if applicable.
        
        // Placeholder implementation:
        let decodedText = tokenizer.decode(tokens: tokens) // Assuming tokenizer has a decode method
        
        print("Decoded text segment: \(decodedText)")
        return decodedText
    }
    
    // Placeholder for the actual Whisper Tokenizer implementation
    // This would likely involve loading vocabulary files and implementing BPE logic.
    private struct WhisperTokenizer {
        // TODO: Load vocab/merges files
        // TODO: Implement encode/decode logic
        
        func decode(tokens: [Int]) -> String {
            // Very basic placeholder
            return tokens.map { "[\($0)]" }.joined(separator: " ") // Just show token IDs for now
        }
    }
} 