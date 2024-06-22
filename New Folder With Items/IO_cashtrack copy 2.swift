//
// IO_cashtrack.swift
//
// This file was automatically generated and should not be edited.
//

import CoreML


/// Model Prediction Input Type
@available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
class IO_cashtrackInput : MLFeatureProvider {

    /// Input image as color (kCVPixelFormatType_32BGRA) image buffer, 640 pixels wide by 640 pixels high
    var image: CVPixelBuffer

    /// (optional) IoU threshold override (default: 0.45) as double value
    var iouThreshold: Double

    /// (optional) Confidence threshold override (default: 0.25) as double value
    var confidenceThreshold: Double

    var featureNames: Set<String> {
        get {
            return ["image", "iouThreshold", "confidenceThreshold"]
        }
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        if (featureName == "image") {
            return MLFeatureValue(pixelBuffer: image)
        }
        if (featureName == "iouThreshold") {
            return MLFeatureValue(double: iouThreshold)
        }
        if (featureName == "confidenceThreshold") {
            return MLFeatureValue(double: confidenceThreshold)
        }
        return nil
    }
    
    init(image: CVPixelBuffer, iouThreshold: Double, confidenceThreshold: Double) {
        self.image = image
        self.iouThreshold = iouThreshold
        self.confidenceThreshold = confidenceThreshold
    }

    convenience init(imageWith image: CGImage, iouThreshold: Double, confidenceThreshold: Double) throws {
        self.init(image: try MLFeatureValue(cgImage: image, pixelsWide: 640, pixelsHigh: 640, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!, iouThreshold: iouThreshold, confidenceThreshold: confidenceThreshold)
    }

    convenience init(imageAt image: URL, iouThreshold: Double, confidenceThreshold: Double) throws {
        self.init(image: try MLFeatureValue(imageAt: image, pixelsWide: 640, pixelsHigh: 640, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!, iouThreshold: iouThreshold, confidenceThreshold: confidenceThreshold)
    }

    func setImage(with image: CGImage) throws  {
        self.image = try MLFeatureValue(cgImage: image, pixelsWide: 640, pixelsHigh: 640, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!
    }

    func setImage(with image: URL) throws  {
        self.image = try MLFeatureValue(imageAt: image, pixelsWide: 640, pixelsHigh: 640, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!
    }

}


/// Model Prediction Output Type
@available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
class IO_cashtrackOutput : MLFeatureProvider {

    /// Source provided by CoreML
    private let provider : MLFeatureProvider

    /// Boxes × Class confidence (see user-defined metadata "classes") as multidimensional array of floats
    var confidence: MLMultiArray {
        return self.provider.featureValue(for: "confidence")!.multiArrayValue!
    }

    /// Boxes × Class confidence (see user-defined metadata "classes") as multidimensional array of floats
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    var confidenceShapedArray: MLShapedArray<Float> {
        return MLShapedArray<Float>(self.confidence)
    }

    /// Boxes × [x, y, width, height] (relative to image size) as multidimensional array of floats
    var coordinates: MLMultiArray {
        return self.provider.featureValue(for: "coordinates")!.multiArrayValue!
    }

    /// Boxes × [x, y, width, height] (relative to image size) as multidimensional array of floats
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    var coordinatesShapedArray: MLShapedArray<Float> {
        return MLShapedArray<Float>(self.coordinates)
    }

    var featureNames: Set<String> {
        return self.provider.featureNames
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        return self.provider.featureValue(for: featureName)
    }

    init(confidence: MLMultiArray, coordinates: MLMultiArray) {
        self.provider = try! MLDictionaryFeatureProvider(dictionary: ["confidence" : MLFeatureValue(multiArray: confidence), "coordinates" : MLFeatureValue(multiArray: coordinates)])
    }

    init(features: MLFeatureProvider) {
        self.provider = features
    }
}


/// Class for model loading and prediction
@available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
class IO_cashtrack {
    let model: MLModel

    /// URL of model assuming it was installed in the same bundle as this class
    class var urlOfModelInThisBundle : URL {
        let bundle = Bundle(for: self)
        return bundle.url(forResource: "IO_cashtrack", withExtension:"mlmodelc")!
    }

    /**
        Construct IO_cashtrack instance with an existing MLModel object.

        Usually the application does not use this initializer unless it makes a subclass of IO_cashtrack.
        Such application may want to use `MLModel(contentsOfURL:configuration:)` and `IO_cashtrack.urlOfModelInThisBundle` to create a MLModel object to pass-in.

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
        Construct IO_cashtrack instance with explicit path to mlmodelc file
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
        Construct IO_cashtrack instance asynchronously with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - configuration: the desired model configuration
          - handler: the completion handler to be called when the model loading completes successfully or unsuccessfully
    */
    class func load(configuration: MLModelConfiguration = MLModelConfiguration(), completionHandler handler: @escaping (Swift.Result<IO_cashtrack, Error>) -> Void) {
        return self.load(contentsOf: self.urlOfModelInThisBundle, configuration: configuration, completionHandler: handler)
    }

    /**
        Construct IO_cashtrack instance asynchronously with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - configuration: the desired model configuration
    */
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    class func load(configuration: MLModelConfiguration = MLModelConfiguration()) async throws -> IO_cashtrack {
        return try await self.load(contentsOf: self.urlOfModelInThisBundle, configuration: configuration)
    }

    /**
        Construct IO_cashtrack instance asynchronously with URL of the .mlmodelc directory with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - modelURL: the URL to the model
          - configuration: the desired model configuration
          - handler: the completion handler to be called when the model loading completes successfully or unsuccessfully
    */
    class func load(contentsOf modelURL: URL, configuration: MLModelConfiguration = MLModelConfiguration(), completionHandler handler: @escaping (Swift.Result<IO_cashtrack, Error>) -> Void) {
        MLModel.load(contentsOf: modelURL, configuration: configuration) { result in
            switch result {
            case .failure(let error):
                handler(.failure(error))
            case .success(let model):
                handler(.success(IO_cashtrack(model: model)))
            }
        }
    }

    /**
        Construct IO_cashtrack instance asynchronously with URL of the .mlmodelc directory with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - modelURL: the URL to the model
          - configuration: the desired model configuration
    */
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    class func load(contentsOf modelURL: URL, configuration: MLModelConfiguration = MLModelConfiguration()) async throws -> IO_cashtrack {
        let model = try await MLModel.load(contentsOf: modelURL, configuration: configuration)
        return IO_cashtrack(model: model)
    }

    /**
        Make a prediction using the structured interface

        - parameters:
           - input: the input to the prediction as IO_cashtrackInput

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as IO_cashtrackOutput
    */
    func prediction(input: IO_cashtrackInput) throws -> IO_cashtrackOutput {
        return try self.prediction(input: input, options: MLPredictionOptions())
    }

    /**
        Make a prediction using the structured interface

        - parameters:
           - input: the input to the prediction as IO_cashtrackInput
           - options: prediction options 

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as IO_cashtrackOutput
    */
    func prediction(input: IO_cashtrackInput, options: MLPredictionOptions) throws -> IO_cashtrackOutput {
        let outFeatures = try model.prediction(from: input, options:options)
        return IO_cashtrackOutput(features: outFeatures)
    }

    /**
        Make an asynchronous prediction using the structured interface

        - parameters:
           - input: the input to the prediction as IO_cashtrackInput
           - options: prediction options 

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as IO_cashtrackOutput
    */
    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
    func prediction(input: IO_cashtrackInput, options: MLPredictionOptions = MLPredictionOptions()) async throws -> IO_cashtrackOutput {
        let outFeatures = try await model.prediction(from: input, options:options)
        return IO_cashtrackOutput(features: outFeatures)
    }

    /**
        Make a prediction using the convenience interface

        - parameters:
            - image: Input image as color (kCVPixelFormatType_32BGRA) image buffer, 640 pixels wide by 640 pixels high
            - iouThreshold: (optional) IoU threshold override (default: 0.45) as double value
            - confidenceThreshold: (optional) Confidence threshold override (default: 0.25) as double value

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as IO_cashtrackOutput
    */
    func prediction(image: CVPixelBuffer, iouThreshold: Double, confidenceThreshold: Double) throws -> IO_cashtrackOutput {
        let input_ = IO_cashtrackInput(image: image, iouThreshold: iouThreshold, confidenceThreshold: confidenceThreshold)
        return try self.prediction(input: input_)
    }

    /**
        Make a batch prediction using the structured interface

        - parameters:
           - inputs: the inputs to the prediction as [IO_cashtrackInput]
           - options: prediction options 

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as [IO_cashtrackOutput]
    */
    func predictions(inputs: [IO_cashtrackInput], options: MLPredictionOptions = MLPredictionOptions()) throws -> [IO_cashtrackOutput] {
        let batchIn = MLArrayBatchProvider(array: inputs)
        let batchOut = try model.predictions(from: batchIn, options: options)
        var results : [IO_cashtrackOutput] = []
        results.reserveCapacity(inputs.count)
        for i in 0..<batchOut.count {
            let outProvider = batchOut.features(at: i)
            let result =  IO_cashtrackOutput(features: outProvider)
            results.append(result)
        }
        return results
    }
}
