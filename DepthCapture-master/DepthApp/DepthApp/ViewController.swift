//
//  ViewController.swift
//  DepthApp
//
//  Created by Juha Eskonen on 13/03/2019.
//  Copyright © 2019 Juha Eskonen. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureFileOutputRecordingDelegate, AVCaptureDepthDataOutputDelegate, AVCapturePhotoCaptureDelegate{
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
    }
    
    let captureSession = AVCaptureSession()
    let sessionOutput = AVCapturePhotoOutput()
    let movieOutput = AVCaptureMovieFileOutput()
    var previewLayer = AVCaptureVideoPreviewLayer()
    let dataOutputQueue = DispatchQueue(label: "data queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    var isRecording = false
    
    private let depthDataOutput = AVCaptureDepthDataOutput()
    //private let dataOutputQueue = DispatchQueue(label: "dataOutputQueue")
    private let depthCapture = DepthCapture()
    
    private var outputSynchronizer: AVCaptureDataOutputSynchronizer?
    
    @IBOutlet var cameraView: UIView!
    
    override func viewWillAppear(_ animated: Bool) {
        if let device = AVCaptureDevice.default(.builtInDualCamera,
                                                for: .video, position: .back) {
                
            do {
                
                let input = try AVCaptureDeviceInput(device: device )
                
                if captureSession.canAddInput(input){
                    captureSession.sessionPreset = AVCaptureSession.Preset.photo
                    captureSession.addInput(input)
                    
                    if captureSession.canAddOutput(sessionOutput){
                        
                        captureSession.addOutput(sessionOutput)
                        
                        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
                        previewLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
                        cameraView.layer.addSublayer(previewLayer)
                        
                        previewLayer.position = CGPoint(x: self.cameraView.frame.width / 2, y: self.cameraView.frame.height / 2)
                        previewLayer.bounds = cameraView.frame
                    }
                    
                    // Add depth output
                    guard captureSession.canAddOutput(depthDataOutput) else { fatalError() }
                    captureSession.addOutput(depthDataOutput)
                    
                    if let connection = depthDataOutput.connection(with: .depthData) {
                        connection.isEnabled = true
                        depthDataOutput.isFilteringEnabled = false
                        depthDataOutput.setDelegate(self, callbackQueue: dataOutputQueue)
                    } else {
                        print("No AVCaptureConnection")
                    }
                    
                    depthCapture.prepareForRecording()
                    
                    // TODO: Do we need to synchronize the video and depth outputs?
                    //outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [sessionOutput, depthDataOutput])
//                    if sessionOutput.isDepthDataDeliverySupported {
//                        sessionOutput.isDepthDataDeliveryEnabled = true
//                        depthDataOutput.connection(with: .depthData)!.isEnabled = true
//                        depthDataOutput.isFilteringEnabled = true
//                        outputSynchronizer? = AVCaptureDataOutputSynchronizer(dataOutputs: [sessionOutput, depthDataOutput])
//                        outputSynchronizer?.setDelegate(self, queue: self.dataOutputQueue)
//                    }
                    sessionOutput.isDepthDataDeliveryEnabled = true
                    //depthDataOutput.isFilteringEnabled = true
                    captureSession.addOutput(movieOutput)

                    captureSession.startRunning()
                }
                
            } catch {
                print("Error")
            }
        }
    }
    
    func startRecording(){
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let fileUrl = paths[0].appendingPathComponent("output.mov")
        movieOutput.startRecording(to: fileUrl, recordingDelegate: self)
        print(fileUrl.absoluteString)
        print("Recording started")
        self.isRecording = true
        
    }
    
    func stopRecording(){
        movieOutput.stopRecording()
        print("Stopped recording!")
        self.isRecording = false
        do {
            try depthCapture.finishRecording(success: { (url: URL) -> Void in
                print(url.absoluteString)
            })
        } catch {
            print("Error while finishing depth capture.")
        }
        
    }
    
    @IBAction func startPressed(_ sender: Any) {
        startRecording()
    }
    
    @IBAction func stopPressed(_ sender: Any) {
        stopRecording()
    }
    
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        // Write depth data to a file
        if(self.isRecording) {
            let ddm = depthData.depthDataMap
            depthCapture.addPixelBuffers(pixelBuffer: ddm)
        }
    }
    
    @IBAction func takePhoto(_ sender: Any) {
        let capturePhotoOutput = self.sessionOutput
        capturePhotoOutput.isHighResolutionCaptureEnabled = true
        capturePhotoOutput.isDualCameraDualPhotoDeliveryEnabled = true
        
        // Get an instance of AVCapturePhotoSettings class
        let photoSettings = AVCapturePhotoSettings()
        
        // Set photo settings for our need
        photoSettings.isAutoStillImageStabilizationEnabled = true
        //photoSettings.isHighResolutionPhotoEnabled = true
        photoSettings.flashMode = .auto
        photoSettings.isDepthDataDeliveryEnabled = true
        // Call capturePhoto method by passing our photo settings and a delegate implementing AVCapturePhotoCaptureDelegate
        capturePhotoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
    func getDocumentsDirectory() throws -> URL {
         return try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {

        //## Convert Disparity to Depth ##
        guard let photoDepthData = photo.depthData else {
            print("Fail to get photo.depthData")
            return
        }
        
        let photoData = photo.fileDataRepresentation();
        let image=UIImage.init(data: photoData!)
        
        let path: String = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let url = URL(fileURLWithPath: path).appendingPathComponent("Photo.png")
        try! image!.pngData()?.write(to: url, options: .atomic)
        
        let depthData = photoDepthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        let depthDataMap = depthData.depthDataMap //AVDepthData -> CVPixelBuffer

        //## Data Analysis ##

        // Useful data
        let width = CVPixelBufferGetWidth(depthDataMap) //768 on an iPhone 7+
        let height = CVPixelBufferGetHeight(depthDataMap) //576 on an iPhone 7+
        
        print("w = \(width) depth = \(height)")
        //CVPixelBufferLockBaseAddress(depthDataMap, CVPixelBufferLockFlags(rawValue: 0))
        let data = readBuffer(pixelBuffer: depthDataMap)
        // Convert the base address to a safe pointer of the appropriate type
        let floatBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(depthDataMap), to: UnsafeMutablePointer<Float32>.self)

        print(data)
        var arr2 = Array<Float32>(repeating: 0, count: data.count/MemoryLayout<Float32>.stride)
        _ = arr2.withUnsafeMutableBytes { data.copyBytes(to: $0) }
        let dict = ["data":arr2]
        guard let pathDirectory = try? getDocumentsDirectory() else{return}
        try? FileManager().createDirectory(at: pathDirectory, withIntermediateDirectories: true)
        let filePath = pathDirectory.appendingPathComponent("Data.json")
        
        if JSONSerialization.isValidJSONObject(dict) { // True
            do {
                let rawData = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
                try rawData.write(to: filePath, options: .atomic)
                //try rawData.writeToFile("newdata.json", options: .DataWritingAtomic)

                //var jsonData = NSData(contentsOfFile: "newdata.json")
                //var jsonDict = try JSONSerialization.JSONObjectWithData(jsonData!, options: .MutableContainers)
                // -> ["stringValue": "JSON", "arrayValue": [0, 1, 2, 3, 4, 5], "numericalValue": 1]

            } catch {
                print("Error: \(error)")
            }
        }
        else{
            print("Not Valid JSON")
        }
        // Read the data (returns value of type Float)
        // Accessible values : (width-1) * (height-1) = 767 * 575

        //let distanceAtXYPoint = floatBuffer[Int(x * y)]
    }
    
    func readBuffer(pixelBuffer:CVPixelBuffer) -> NSData{
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
        let height = CVPixelBufferGetHeight(pixelBuffer);
        let size = bytesPerRow * height;
        //let data = NSData.dataWithBytes_length_(objc.wrap(baseAddress), objc.wrap(size));
        let data = NSData.init(bytes: baseAddress, length: size)
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        return data
    }
}
