////
////  MLcapture.swift
////  FilmForensics
////
////  Created by Almahdi Morris on 23/6/24.
////  MLcapture
//import SwiftUI
//import Combine
//import AVFoundation
//import Vision
//import CoreML
//import ScreenCaptureKit
//
////@main
////struct ScreenCaptureMLApp: App {
////  var body: some Scene {
////    WindowGroup {
////      MLcaptureMainView()
////    }
////  }
////}
//
//struct MLcaptureMainView: View {
//  @StateObject private var viewModel = ScreenCaptureViewModel()
//  
//  var body: some View {
//    TabView {
//      NavigationSplitView {
//        MLcaptureSidebarView(viewModel: viewModel)
//      } detail: {
//        MLcaptureCaptureView(viewModel: viewModel)
//      }
//      .tabItem {
//        Label("MainView", systemImage: "1.square.fill")
//      }
//    }
//  }
//}
//
//struct MLcaptureSidebarView: View {
//  @ObservedObject var viewModel: ScreenCaptureViewModel
//  
//  var body: some View {
//    ScrollViewReader { proxy in
//      ScrollView {
//        LazyVStack {
//          ForEach(viewModel.capturedSegments, id: \.self) { segment in
//            Text("Segment \(segment)")
//          }
//        }
//      }
//      .frame(maxWidth: .infinity)
//    }
//    .padding()
//    .background(Color.gray.opacity(0.1))
//    .frame(minWidth: 150)
//    .overlay(
//      VStack {
//        Spacer()
//        HStack {
//          Button("Add Video") {
//            viewModel.addVideo()
//          }
//          Button("Clear All") {
//            viewModel.clearAll()
//          }
//        }
//        .padding()
//      }
//    )
//  }
//}
//
//struct MLcaptureCaptureView: View {
//  @ObservedObject var viewModel: ScreenCaptureViewModel
//  
//  var body: some View {
//    VStack {
//      if let capturedImage = viewModel.capturedImage {
//        Image(nsImage: capturedImage)
//          .resizable()
//          .scaledToFit()
//      } else {
//        Text("Waiting for capture to start")
//          .foregroundColor(.gray)
//      }
//      
//      HStack {
//        Button("Capture") {
//          viewModel.startCapture()
//        }
//        .padding()
//        
//        Button("Save") {
//          viewModel.saveCapture()
//        }
//        .padding()
//      }
//    }
//    .padding()
//    .background(Color.black.opacity(0.7))
//    .foregroundColor(.white)
//    .frame(maxWidth: .infinity, maxHeight: .infinity)
//  }
//}
//
//class ScreenCaptureViewModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
//  @Published var capturedSegments: [String] = []
//  @Published var capturedImage: NSImage? = nil
//  
//  private var captureSession: AVCaptureSession?
//  private var videoOutput: AVCaptureVideoDataOutput?
//  private var captureProcessor: MLcaptureCaptureProcessor?
//  private let model = try! VNCoreMLModel(for: IO_cashtrack().model)
//  
//  func startCapture() {
//    captureSession = AVCaptureSession()
//    captureSession?.sessionPreset = .high
//    
//    guard let screen = NSScreen.main else { return }
//    let displayId = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID
//    
//    let input = AVCaptureScreenInput(displayID: displayId)
//    captureSession?.addInput(input!)
//    
//    videoOutput = AVCaptureVideoDataOutput()
//    videoOutput?.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
//    captureSession?.addOutput(videoOutput!)
//    
//    captureProcessor = MLcaptureCaptureProcessor(viewModel: self, model: model)
//    captureSession?.startRunning()
//  }
//  
//  func saveCapture() {
//    // Save the current capture to disk
//  }
//  
//  func addVideo() {
//    // Add video functionality
//  }
//  
//  func clearAll() {
//    capturedSegments.removeAll()
//    capturedImage = nil
//  }
//  
//  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//    guard let captureProcessor = captureProcessor else { return }
//    captureProcessor.processBuffer(sampleBuffer)
//  }
//}
//
//class MLcaptureCaptureProcessor {
//  private let viewModel: ScreenCaptureViewModel
//  private let model: VNCoreMLModel
//  
//  init(viewModel: ScreenCaptureViewModel, model: VNCoreMLModel) {
//    self.viewModel = viewModel
//    self.model = model
//  }
//  
//  func processBuffer(_ sampleBuffer: CMSampleBuffer) {
//    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
//    
//    let request = VNCoreMLRequest(model: model) { request, error in
//      if let results = request.results as? [VNRecognizedObjectObservation] {
//        self.handleResults(results, from: pixelBuffer)
//      }
//    }
//    
//    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
//    try? handler.perform([request])
//  }
//  
//  private func handleResults(_ results: [VNRecognizedObjectObservation], from pixelBuffer: CVPixelBuffer) {
//    DispatchQueue.main.async {
//      // Process the results and update the view model
//      self.viewModel.capturedImage = self.createImage(from: pixelBuffer)
//    }
//  }
//  
//  private func createImage(from pixelBuffer: CVPixelBuffer) -> NSImage? {
//    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
//    let context = CIContext(options: nil)
//    guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
//    return NSImage(cgImage: cgImage, size: NSSize(width: ciImage.extent.width, height: ciImage.extent.height))
//  }
//}
