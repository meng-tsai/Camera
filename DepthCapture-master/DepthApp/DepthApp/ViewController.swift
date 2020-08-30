//
//  ViewController.swift
//  DepthApp
//
//  Created by Juha Eskonen on 13/03/2019.
//  Copyright © 2019 Juha Eskonen. All rights reserved.
//

import UIKit
import AVFoundation

extension UIImage {
    func resized(toWidth width: CGFloat) -> UIImage? {
        let canvasSize = CGSize(width: width, height: CGFloat(ceil(width/size.width * size.height)))
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: canvasSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

class ViewController: UIViewController, AVCaptureFileOutputRecordingDelegate, AVCaptureDepthDataOutputDelegate, AVCapturePhotoCaptureDelegate{
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
    }
    
    let captureSession = AVCaptureSession()
    let sessionOutput = AVCapturePhotoOutput()
    let movieOutput = AVCaptureMovieFileOutput()
    var previewLayer = AVCaptureVideoPreviewLayer()
    let dataOutputQueue = DispatchQueue(label: "data queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    var isRecording = false
    var picNum = 0000001
    var focused = false
    var recording = false
    var timer: Timer?
    
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
//                if (!focused){
//                    self.setNeedsFocusUpdate()
//                    self.updateFocusIfNeeded()
//                    focused = true
//                }
                try device.lockForConfiguration()
                device.focusMode = .autoFocus
                device.focusPointOfInterest = CGPoint(x:0.5, y:0.5)
                device.focusMode = .locked
                device.unlockForConfiguration()
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
                        if connection.isCameraIntrinsicMatrixDeliverySupported{
                            connection.isCameraIntrinsicMatrixDeliveryEnabled = true;
                            print("intrinsic matrix enabled")
                        }
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
        print("button pressed")
        if let timer = self.timer{
            print("timer to nil")
            self.timer!.invalidate()
            self.timer = nil
        }
        else{
//            DispatchQueue.main.async {
//                self.timer = Timer(timeInterval: 0.5, repeats: true, block: { (_) in
//                    print("photo saved")
//                    self.savePhoto()
//                })
//            }
            self.timer = Timer.scheduledTimer(timeInterval: 0.25, target: self, selector: #selector(savePhoto), userInfo: nil, repeats: true)
        }
    }
    @objc func savePhoto(){
        print("photo saved")
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
        //print("isCameraCalibrationDataDeliverySupported: \(output.isCameraCalibrationDataDeliverySupported)")
        
        //## Convert Disparity to Depth ##
        guard let photoDepthData = photo.depthData else {
            print("Fail to get photo.depthData")
            return
        }
        let photoData = photo.fileDataRepresentation();
        
        print (photoDepthData.cameraCalibrationData?.intrinsicMatrix)
        
        let image=UIImage.init(data: photoData!)
        guard let pathDirectory = try? getDocumentsDirectory() else{return}
        let path: String = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        
        //print intrinsic matrix
        
        let intrinsic = photo.cameraCalibrationData?.intrinsicMatrix
        var intrinsicDict = ["intrinsic":intrinsic]
        var intrinsicPath = URL(fileURLWithPath: path + "/intrinsic/")
        try? FileManager().createDirectory(at: intrinsicPath, withIntermediateDirectories: true)
        intrinsicPath = intrinsicPath.appendingPathComponent("intrinsic\(picNum).json")
        
        if JSONSerialization.isValidJSONObject(intrinsicDict) { // True
            do {
                let rawData = try JSONSerialization.data(withJSONObject: intrinsicDict, options: .prettyPrinted)
                try rawData.write(to: intrinsicPath, options: .atomic)
            } catch {
                print("Error: \(error)")
            }
        }
        else{
            print("Not Valid JSON")
        }
        
        //print(photoData)
        
        
        var imgPath = URL(fileURLWithPath: path+"/image/")
        try? FileManager().createDirectory(at: imgPath, withIntermediateDirectories: true)
        imgPath = imgPath.appendingPathComponent("image\(picNum).png")
        try! image!.resized(toWidth: 576)!.pngData()?.write(to: imgPath, options: .atomic)
        //try! image!.pngData()?.write(to: imgPath, options: .atomic)
        
        let depthData = photoDepthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        let depthDataMap = depthData.depthDataMap //AVDepthData -> CVPixelBuffer
        //depthData.cameraCalibrationData?.intrinsicMatrix
        //## Data Analysis ##

        // Useful data
        let width = CVPixelBufferGetWidth(depthDataMap) //768 on an iPhone 7+
        let height = CVPixelBufferGetHeight(depthDataMap) //576 on an iPhone 7+
        
        print("w = \(width) depth = \(height)")
        //CVPixelBufferLockBaseAddress(depthDataMap, CVPixelBufferLockFlags(rawValue: 0))
        let data = readBuffer(pixelBuffer: depthDataMap)
        
        //pixelBuffer to UIImage to png
        let toCIImage = CoreImage.CIImage.init(cvImageBuffer: depthDataMap)
        let toUIImage = UIImage.init(ciImage: toCIImage)
        var depthPath =  URL(fileURLWithPath: path+"/depth/")
        try? FileManager().createDirectory(at: depthPath, withIntermediateDirectories: true)
        depthPath = depthPath.appendingPathComponent("depth\(picNum).png")
        try? toUIImage.pngData()?.write(to: depthPath)
        
        
        // Convert the base address to a safe pointer of the appropriate type
        let floatBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(depthDataMap), to: UnsafeMutablePointer<Float32>.self)

        var arr2 = Array<Float32>(repeating: 0, count: data.count/MemoryLayout<Float32>.stride)
        _ = arr2.withUnsafeMutableBytes { data.copyBytes(to: $0) }
        
        var arr_int = arr2.map { (x) -> Int16 in
            return Int16(lround(Double(x) * 1000))
        }
        
        var dict = ["data":arr_int]
        var dataPath = URL(fileURLWithPath: path+"/data/")
        try? FileManager().createDirectory(at: dataPath, withIntermediateDirectories: true)
        dataPath = dataPath.appendingPathComponent("data\(picNum).json")
        
        if JSONSerialization.isValidJSONObject(dict) { // True
            do {
                let rawData = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
                try rawData.write(to: dataPath, options: .atomic)
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
        picNum += 1
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
