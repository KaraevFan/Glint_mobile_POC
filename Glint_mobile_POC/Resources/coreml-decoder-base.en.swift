//
// coreml_decoder_base_en.swift
//
// This file was automatically generated and should not be edited.
//

import CoreML


/// Model Prediction Input Type
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *)
class coreml_decoder_base_enInput : MLFeatureProvider {

    /// token_data as 1 by 1 matrix of 32-bit integers
    var token_data: MLMultiArray

    /// audio_data as 1 × 1500 × 512 3-dimensional array of floats
    var audio_data: MLMultiArray

    var featureNames: Set<String> { ["token_data", "audio_data"] }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        if featureName == "token_data" {
            return MLFeatureValue(multiArray: token_data)
        }
        if featureName == "audio_data" {
            return MLFeatureValue(multiArray: audio_data)
        }
        return nil
    }

    init(token_data: MLMultiArray, audio_data: MLMultiArray) {
        self.token_data = token_data
        self.audio_data = audio_data
    }

    convenience init(token_data: MLShapedArray<Int32>, audio_data: MLShapedArray<Float>) {
        self.init(token_data: MLMultiArray(token_data), audio_data: MLMultiArray(audio_data))
    }

}


/// Model Prediction Output Type
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *)
class coreml_decoder_base_enOutput : MLFeatureProvider {

    /// Source provided by CoreML
    private let provider : MLFeatureProvider

    /// cast_112 as 1 × 1 × 51864 3-dimensional array of floats
    var cast_112: MLMultiArray {
        provider.featureValue(for: "cast_112")!.multiArrayValue!
    }

    /// cast_112 as 1 × 1 × 51864 3-dimensional array of floats
    var cast_112ShapedArray: MLShapedArray<Float> {
        MLShapedArray<Float>(cast_112)
    }

    var featureNames: Set<String> {
        provider.featureNames
    }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        provider.featureValue(for: featureName)
    }

    init(cast_112: MLMultiArray) {
        self.provider = try! MLDictionaryFeatureProvider(dictionary: ["cast_112" : MLFeatureValue(multiArray: cast_112)])
    }

    init(features: MLFeatureProvider) {
        self.provider = features
    }
}


/// Class for model loading and prediction
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *)
class coreml_decoder_base_en {
    let model: MLModel

    /// URL of model assuming it was installed in the same bundle as this class
    class var urlOfModelInThisBundle : URL {
        let bundle = Bundle(for: self)
        return bundle.url(forResource: "coreml-decoder-base.en", withExtension:"mlmodelc")!
    }

    /**
        Construct coreml_decoder_base_en instance with an existing MLModel object.

        Usually the application does not use this initializer unless it makes a subclass of coreml_decoder_base_en.
        Such application may want to use `MLModel(contentsOfURL:configuration:)` and `coreml_decoder_base_en.urlOfModelInThisBundle` to create a MLModel object to pass-in.

        - parameters:
          - model: MLModel object
    */
    init(model: MLModel) {
        self.model = model
    }

    /**
        Construct a model with configuration

        - parameters:
           - configuration: the desired model configuration

        - throws: an NSError object that describes the problem
    */
    convenience init(configuration: MLModelConfiguration = MLModelConfiguration()) throws {
        try self.init(contentsOf: type(of:self).urlOfModelInThisBundle, configuration: configuration)
    }

    /**
        Construct coreml_decoder_base_en instance with explicit path to mlmodelc file
        - parameters:
           - modelURL: the file url of the model

        - throws: an NSError object that describes the problem
    */
    convenience init(contentsOf modelURL: URL) throws {
        try self.init(model: MLModel(contentsOf: modelURL))
    }

    /**
        Construct a model with URL of the .mlmodelc directory and configuration

        - parameters:
           - modelURL: the file url of the model
           - configuration: the desired model configuration

        - throws: an NSError object that describes the problem
    */
    convenience init(contentsOf modelURL: URL, configuration: MLModelConfiguration) throws {
        try self.init(model: MLModel(contentsOf: modelURL, configuration: configuration))
    }

    /**
        Construct coreml_decoder_base_en instance asynchronously with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - configuration: the desired model configuration
          - handler: the completion handler to be called when the model loading completes successfully or unsuccessfully
    */
    class func load(configuration: MLModelConfiguration = MLModelConfiguration(), completionHandler handler: @escaping (Swift.Result<coreml_decoder_base_en, Error>) -> Void) {
        load(contentsOf: self.urlOfModelInThisBundle, configuration: configuration, completionHandler: handler)
    }

    /**
        Construct coreml_decoder_base_en instance asynchronously with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - configuration: the desired model configuration
    */
    class func load(configuration: MLModelConfiguration = MLModelConfiguration()) async throws -> coreml_decoder_base_en {
        try await load(contentsOf: self.urlOfModelInThisBundle, configuration: configuration)
    }

    /**
        Construct coreml_decoder_base_en instance asynchronously with URL of the .mlmodelc directory with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - modelURL: the URL to the model
          - configuration: the desired model configuration
          - handler: the completion handler to be called when the model loading completes successfully or unsuccessfully
    */
    class func load(contentsOf modelURL: URL, configuration: MLModelConfiguration = MLModelConfiguration(), completionHandler handler: @escaping (Swift.Result<coreml_decoder_base_en, Error>) -> Void) {
        MLModel.load(contentsOf: modelURL, configuration: configuration) { result in
            switch result {
            case .failure(let error):
                handler(.failure(error))
            case .success(let model):
                handler(.success(coreml_decoder_base_en(model: model)))
            }
        }
    }

    /**
        Construct coreml_decoder_base_en instance asynchronously with URL of the .mlmodelc directory with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - modelURL: the URL to the model
          - configuration: the desired model configuration
    */
    class func load(contentsOf modelURL: URL, configuration: MLModelConfiguration = MLModelConfiguration()) async throws -> coreml_decoder_base_en {
        let model = try await MLModel.load(contentsOf: modelURL, configuration: configuration)
        return coreml_decoder_base_en(model: model)
    }

    /**
        Make a prediction using the structured interface

        It uses the default function if the model has multiple functions.

        - parameters:
           - input: the input to the prediction as coreml_decoder_base_enInput

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as coreml_decoder_base_enOutput
    */
    func prediction(input: coreml_decoder_base_enInput) throws -> coreml_decoder_base_enOutput {
        try prediction(input: input, options: MLPredictionOptions())
    }

    /**
        Make a prediction using the structured interface

        It uses the default function if the model has multiple functions.

        - parameters:
           - input: the input to the prediction as coreml_decoder_base_enInput
           - options: prediction options

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as coreml_decoder_base_enOutput
    */
    func prediction(input: coreml_decoder_base_enInput, options: MLPredictionOptions) throws -> coreml_decoder_base_enOutput {
        let outFeatures = try model.prediction(from: input, options: options)
        return coreml_decoder_base_enOutput(features: outFeatures)
    }

    /**
        Make an asynchronous prediction using the structured interface

        It uses the default function if the model has multiple functions.

        - parameters:
           - input: the input to the prediction as coreml_decoder_base_enInput
           - options: prediction options

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as coreml_decoder_base_enOutput
    */
    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    func prediction(input: coreml_decoder_base_enInput, options: MLPredictionOptions = MLPredictionOptions()) async throws -> coreml_decoder_base_enOutput {
        let outFeatures = try await model.prediction(from: input, options: options)
        return coreml_decoder_base_enOutput(features: outFeatures)
    }

    /**
        Make a prediction using the convenience interface

        It uses the default function if the model has multiple functions.

        - parameters:
            - token_data: 1 by 1 matrix of 32-bit integers
            - audio_data: 1 × 1500 × 512 3-dimensional array of floats

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as coreml_decoder_base_enOutput
    */
    func prediction(token_data: MLMultiArray, audio_data: MLMultiArray) throws -> coreml_decoder_base_enOutput {
        let input_ = coreml_decoder_base_enInput(token_data: token_data, audio_data: audio_data)
        return try prediction(input: input_)
    }

    /**
        Make a prediction using the convenience interface

        It uses the default function if the model has multiple functions.

        - parameters:
            - token_data: 1 by 1 matrix of 32-bit integers
            - audio_data: 1 × 1500 × 512 3-dimensional array of floats

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as coreml_decoder_base_enOutput
    */

    func prediction(token_data: MLShapedArray<Int32>, audio_data: MLShapedArray<Float>) throws -> coreml_decoder_base_enOutput {
        let input_ = coreml_decoder_base_enInput(token_data: token_data, audio_data: audio_data)
        return try prediction(input: input_)
    }

    /**
        Make a batch prediction using the structured interface

        It uses the default function if the model has multiple functions.

        - parameters:
           - inputs: the inputs to the prediction as [coreml_decoder_base_enInput]
           - options: prediction options

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as [coreml_decoder_base_enOutput]
    */
    func predictions(inputs: [coreml_decoder_base_enInput], options: MLPredictionOptions = MLPredictionOptions()) throws -> [coreml_decoder_base_enOutput] {
        let batchIn = MLArrayBatchProvider(array: inputs)
        let batchOut = try model.predictions(from: batchIn, options: options)
        var results : [coreml_decoder_base_enOutput] = []
        results.reserveCapacity(inputs.count)
        for i in 0..<batchOut.count {
            let outProvider = batchOut.features(at: i)
            let result =  coreml_decoder_base_enOutput(features: outProvider)
            results.append(result)
        }
        return results
    }
}
