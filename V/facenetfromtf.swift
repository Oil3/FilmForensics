//
// facenetfromtf.swift
//
// This file was automatically generated and should not be edited.
//

import CoreML


/// Model Prediction Input Type
@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
class facenetfromtfInput : MLFeatureProvider {

    /// input__0 as color (kCVPixelFormatType_32BGRA) image buffer, 160 pixels wide by 160 pixels high
    var input__0: CVPixelBuffer

    var featureNames: Set<String> {
        get {
            return ["input__0"]
        }
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        if (featureName == "input__0") {
            return MLFeatureValue(pixelBuffer: input__0)
        }
        return nil
    }
    
    init(input__0: CVPixelBuffer) {
        self.input__0 = input__0
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    convenience init(input__0With input__0: CGImage) throws {
        self.init(input__0: try MLFeatureValue(cgImage: input__0, pixelsWide: 160, pixelsHigh: 160, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!)
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    convenience init(input__0At input__0: URL) throws {
        self.init(input__0: try MLFeatureValue(imageAt: input__0, pixelsWide: 160, pixelsHigh: 160, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!)
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func setInput__0(with input__0: CGImage) throws  {
        self.input__0 = try MLFeatureValue(cgImage: input__0, pixelsWide: 160, pixelsHigh: 160, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func setInput__0(with input__0: URL) throws  {
        self.input__0 = try MLFeatureValue(imageAt: input__0, pixelsWide: 160, pixelsHigh: 160, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!
    }

}


/// Model Prediction Output Type
@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
class facenetfromtfOutput : MLFeatureProvider {

    /// Source provided by CoreML
    private let provider : MLFeatureProvider

    /// embeddings__0 as 128 element vector of doubles
    var embeddings__0: MLMultiArray {
        return self.provider.featureValue(for: "embeddings__0")!.multiArrayValue!
    }

    /// embeddings__0 as 128 element vector of doubles
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    var embeddings__0ShapedArray: MLShapedArray<Double> {
        return MLShapedArray<Double>(self.embeddings__0)
    }

    var featureNames: Set<String> {
        return self.provider.featureNames
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        return self.provider.featureValue(for: featureName)
    }

    init(embeddings__0: MLMultiArray) {
        self.provider = try! MLDictionaryFeatureProvider(dictionary: ["embeddings__0" : MLFeatureValue(multiArray: embeddings__0)])
    }

    init(features: MLFeatureProvider) {
        self.provider = features
    }
}


/// Class for model loading and prediction
@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
class facenetfromtf {
    let model: MLModel

    /// URL of model assuming it was installed in the same bundle as this class
    class var urlOfModelInThisBundle : URL {
        let bundle = Bundle(for: self)
        return bundle.url(forResource: "facenetfromtf", withExtension:"mlmodelc")!
    }

    /**
        Construct facenetfromtf instance with an existing MLModel object.

        Usually the application does not use this initializer unless it makes a subclass of facenetfromtf.
        Such application may want to use `MLModel(contentsOfURL:configuration:)` and `facenetfromtf.urlOfModelInThisBundle` to create a MLModel object to pass-in.

        - parameters:
          - model: MLModel object
    */
    init(model: MLModel) {
        self.model = model
    }

    /**
        Construct facenetfromtf instance by automatically loading the model from the app's bundle.
    */
    @available(*, deprecated, message: "Use init(configuration:) instead and handle errors appropriately.")
    convenience init() {
        try! self.init(contentsOf: type(of:self).urlOfModelInThisBundle)
    }

    /**
        Construct a model with configuration

        - parameters:
           - configuration: the desired model configuration

        - throws: an NSError object that describes the problem
    */
    @available(macOS 10.14, iOS 12.0, tvOS 12.0, watchOS 5.0, *)
    convenience init(configuration: MLModelConfiguration) throws {
        try self.init(contentsOf: type(of:self).urlOfModelInThisBundle, configuration: configuration)
    }

    /**
        Construct facenetfromtf instance with explicit path to mlmodelc file
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
    @available(macOS 10.14, iOS 12.0, tvOS 12.0, watchOS 5.0, *)
    convenience init(contentsOf modelURL: URL, configuration: MLModelConfiguration) throws {
        try self.init(model: MLModel(contentsOf: modelURL, configuration: configuration))
    }

    /**
        Construct facenetfromtf instance asynchronously with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - configuration: the desired model configuration
          - handler: the completion handler to be called when the model loading completes successfully or unsuccessfully
    */
    @available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
    class func load(configuration: MLModelConfiguration = MLModelConfiguration(), completionHandler handler: @escaping (Swift.Result<facenetfromtf, Error>) -> Void) {
        return self.load(contentsOf: self.urlOfModelInThisBundle, configuration: configuration, completionHandler: handler)
    }

    /**
        Construct facenetfromtf instance asynchronously with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - configuration: the desired model configuration
    */
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    class func load(configuration: MLModelConfiguration = MLModelConfiguration()) async throws -> facenetfromtf {
        return try await self.load(contentsOf: self.urlOfModelInThisBundle, configuration: configuration)
    }

    /**
        Construct facenetfromtf instance asynchronously with URL of the .mlmodelc directory with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - modelURL: the URL to the model
          - configuration: the desired model configuration
          - handler: the completion handler to be called when the model loading completes successfully or unsuccessfully
    */
    @available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
    class func load(contentsOf modelURL: URL, configuration: MLModelConfiguration = MLModelConfiguration(), completionHandler handler: @escaping (Swift.Result<facenetfromtf, Error>) -> Void) {
        MLModel.load(contentsOf: modelURL, configuration: configuration) { result in
            switch result {
            case .failure(let error):
                handler(.failure(error))
            case .success(let model):
                handler(.success(facenetfromtf(model: model)))
            }
        }
    }

    /**
        Construct facenetfromtf instance asynchronously with URL of the .mlmodelc directory with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - modelURL: the URL to the model
          - configuration: the desired model configuration
    */
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    class func load(contentsOf modelURL: URL, configuration: MLModelConfiguration = MLModelConfiguration()) async throws -> facenetfromtf {
        let model = try await MLModel.load(contentsOf: modelURL, configuration: configuration)
        return facenetfromtf(model: model)
    }

    /**
        Make a prediction using the structured interface

        - parameters:
           - input: the input to the prediction as facenetfromtfInput

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as facenetfromtfOutput
    */
    func prediction(input: facenetfromtfInput) throws -> facenetfromtfOutput {
        return try self.prediction(input: input, options: MLPredictionOptions())
    }

    /**
        Make a prediction using the structured interface

        - parameters:
           - input: the input to the prediction as facenetfromtfInput
           - options: prediction options 

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as facenetfromtfOutput
    */
    func prediction(input: facenetfromtfInput, options: MLPredictionOptions) throws -> facenetfromtfOutput {
        let outFeatures = try model.prediction(from: input, options:options)
        return facenetfromtfOutput(features: outFeatures)
    }

    /**
        Make an asynchronous prediction using the structured interface

        - parameters:
           - input: the input to the prediction as facenetfromtfInput
           - options: prediction options 

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as facenetfromtfOutput
    */
    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
    func prediction(input: facenetfromtfInput, options: MLPredictionOptions = MLPredictionOptions()) async throws -> facenetfromtfOutput {
        let outFeatures = try await model.prediction(from: input, options:options)
        return facenetfromtfOutput(features: outFeatures)
    }

    /**
        Make a prediction using the convenience interface

        - parameters:
            - input__0 as color (kCVPixelFormatType_32BGRA) image buffer, 160 pixels wide by 160 pixels high

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as facenetfromtfOutput
    */
    func prediction(input__0: CVPixelBuffer) throws -> facenetfromtfOutput {
        let input_ = facenetfromtfInput(input__0: input__0)
        return try self.prediction(input: input_)
    }

    /**
        Make a batch prediction using the structured interface

        - parameters:
           - inputs: the inputs to the prediction as [facenetfromtfInput]
           - options: prediction options 

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as [facenetfromtfOutput]
    */
    @available(macOS 10.14, iOS 12.0, tvOS 12.0, watchOS 5.0, *)
    func predictions(inputs: [facenetfromtfInput], options: MLPredictionOptions = MLPredictionOptions()) throws -> [facenetfromtfOutput] {
        let batchIn = MLArrayBatchProvider(array: inputs)
        let batchOut = try model.predictions(from: batchIn, options: options)
        var results : [facenetfromtfOutput] = []
        results.reserveCapacity(inputs.count)
        for i in 0..<batchOut.count {
            let outProvider = batchOut.features(at: i)
            let result =  facenetfromtfOutput(features: outProvider)
            results.append(result)
        }
        return results
    }
}
