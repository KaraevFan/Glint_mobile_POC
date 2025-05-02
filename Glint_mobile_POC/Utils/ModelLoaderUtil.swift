import Foundation
import CoreML

struct ModelLoaderUtil {

    static func verifyModels() {
        print("Attempting to load Core ML models...")

        // Attempt to load the Encoder model
        do {
            let encoderConfig = MLModelConfiguration()
            // Explicitly set compute units for simulator compatibility
            encoderConfig.computeUnits = .cpuOnly
            let _ = try coreml_encoder_base_en(configuration: encoderConfig)
            print("✅ Successfully loaded Encoder model (coreml_encoder_base_en) using CPU.")
        } catch {
            print("❌ Failed to load Encoder model: \(error.localizedDescription)")
        }

        // Attempt to load the Decoder model
        do {
            let decoderConfig = MLModelConfiguration()
            // Explicitly set compute units for simulator compatibility
            decoderConfig.computeUnits = .cpuOnly
            let _ = try coreml_decoder_base_en(configuration: decoderConfig)
            print("✅ Successfully loaded Decoder model (coreml_decoder_base_en) using CPU.")
        } catch {
            print("❌ Failed to load Decoder model: \(error.localizedDescription)")
        }

        print("Model loading verification complete.")
    }
} 