//
//  ViewController.swift
//  Camera
//
//  Created by Rizwan on 16/06/17.
//  Copyright © 2017 Rizwan. All rights reserved.
//

import UIKit
import AVFoundation
import CoreMotion
import Foundation

class ViewController: UIViewController {

    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var outputButton: UIButton!
    @IBAction func outputButton(_ sender: Any) {
        exportRot()
    }
    
    var captureSession: AVCaptureSession?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var capturePhotoOutput: AVCapturePhotoOutput?
    var qrCodeFrameView: UIView?
    let motionManager = CMMotionManager()
    
    var roll: Double = 0.0
    var pitch: Double = 0.0
    var yaw: Double = 0.0
    var rotX: Double = 0.0
    var rotY: Double = 0.0
    var rotZ: Double = 0.0
    
    var rollArr = [Double]()
    var pitchArr = [Double]()
    var yawArr = [Double]()
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        captureButton.layer.cornerRadius = captureButton.frame.size.width / 2
        captureButton.clipsToBounds = true
        
        // Get an instance of the AVCaptureDevice class to initialize a device object and provide the video as the media type parameter
        guard let captureDevice = AVCaptureDevice.default(for: AVMediaType.video) else {
            print("No video device found")
            return
        }

        
        do {
            // Get an instance of the AVCaptureDeviceInput class using the previous deivce object
            let input = try AVCaptureDeviceInput(device: captureDevice)
            
            // Initialize the captureSession object
            captureSession = AVCaptureSession()
            
            // Set the input devcie on the capture session
            captureSession?.addInput(input)
            
            // Get an instance of ACCapturePhotoOutput class
            capturePhotoOutput = AVCapturePhotoOutput()
            capturePhotoOutput?.isHighResolutionCaptureEnabled = true
            
            // Set the output on the capture session
            captureSession?.addOutput(capturePhotoOutput!)
            
            // Initialize a AVCaptureMetadataOutput object and set it as the input device
            let captureMetadataOutput = AVCaptureMetadataOutput()
            captureSession?.addOutput(captureMetadataOutput)

            // Set delegate and use the default dispatch queue to execute the call back
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
            
            //Initialise the video preview layer and add it as a sublayer to the viewPreview view's layer
            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
            videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
            videoPreviewLayer?.frame = view.layer.bounds
            previewView.layer.addSublayer(videoPreviewLayer!)
            
            //start video capture
            captureSession?.startRunning()
            
//            messageLabel.isHidden = true
            
            //Initialize QR Code Frame to highlight the QR code
            qrCodeFrameView = UIView()
            
            if let qrCodeFrameView = qrCodeFrameView {
                qrCodeFrameView.layer.borderColor = UIColor.green.cgColor
                qrCodeFrameView.layer.borderWidth = 2
                view.addSubview(qrCodeFrameView)
                view.bringSubviewToFront(qrCodeFrameView)
            }
        } catch {
            //If any error occurs, simply print it out
            print(error)
            return
        }
    
        motionManager.gyroUpdateInterval = 0.2

        motionManager.startGyroUpdates(to: OperationQueue.current!, withHandler: { (gyroData: CMGyroData?, NSError) -> Void in
            self.outputRotData(gyroData!.rotationRate)
            
            if (NSError != nil){
                print("\(NSError)")
            }
        })

        motionManager.startDeviceMotionUpdates(to: OperationQueue.current!, withHandler: {(motionData: CMDeviceMotion?, NSError) -> Void in self.outputRPY(data: motionData!)
            if (NSError != nil){
                print("\(NSError)")
            }
        })

    }
    
    func outputRPY(data: CMDeviceMotion){
            let rpyattitude = motionManager.deviceMotion!.attitude
        roll  = rpyattitude.roll * (180.0 / M_PI)
        pitch   = rpyattitude.pitch * (180.0 / M_PI)
        yaw    = rpyattitude.yaw * (180.0 / M_PI)
    }
    
    func getRot(){
        messageLabel.text = "roll = \(roll), pitch = \(pitch), yaw = \(yaw)"
        rollArr.append(roll)
        pitchArr.append(pitch)
        yawArr.append(yaw)
    }
    
    func outputRotData(_ rotation: CMRotationRate){
        rotX = rotation.x
        rotY = rotation.y
        rotZ = rotation.z
    }
    
    func getDocumentsDirectory() throws -> URL {
         return try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    }
    
    func exportRot(){
        let metadata: [String: [Double]] = [
            "roll": rollArr,
            "pitch": pitchArr,
            "yaw": yawArr
        ]
        
        // Serialize to JSON
        //guard let jsonData = try? JSONSerialization.data(withJSONObject: metadata) else{return}
            // Convert to a string and print
        //guard let JSONString = String(data: jsonData, encoding: String.Encoding.utf8) else{return}
        //print(JSONString)
        guard let pathDirectory = try? getDocumentsDirectory() else{return}
        try? FileManager().createDirectory(at: pathDirectory, withIntermediateDirectories: true)
        let filePath = pathDirectory.appendingPathComponent("Rotation\(Date()).json")
        print(filePath)
        let json = try? JSONEncoder().encode(metadata)
        do {
             try json!.write(to: filePath)
        } catch {
            print("Failed to write JSON data: \(error.localizedDescription)")
        }
    }
    
    override func viewDidLayoutSubviews() {
        videoPreviewLayer?.frame = view.bounds
        if let previewLayer = videoPreviewLayer ,(previewLayer.connection?.isVideoOrientationSupported)! {
            previewLayer.connection?.videoOrientation = UIApplication.shared.statusBarOrientation.videoOrientation ?? .portrait
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func onTapTakePhoto(_ sender: Any) {
        // Make sure capturePhotoOutput is valid
        guard let capturePhotoOutput = self.capturePhotoOutput else { return }
        
        // Get an instance of AVCapturePhotoSettings class
        let photoSettings = AVCapturePhotoSettings()
        
        // Set photo settings for our need
        photoSettings.isAutoStillImageStabilizationEnabled = true
        photoSettings.isHighResolutionPhotoEnabled = true
        photoSettings.flashMode = .auto
        
        // Call capturePhoto method by passing our photo settings and a delegate implementing AVCapturePhotoCaptureDelegate
        capturePhotoOutput.capturePhoto(with: photoSettings, delegate: self)
        getRot()
    }
}

extension ViewController : AVCapturePhotoCaptureDelegate {
    func photoOutput(_ captureOutput: AVCapturePhotoOutput,
                 didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?,
                 previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?,
                 resolvedSettings: AVCaptureResolvedPhotoSettings,
                 bracketSettings: AVCaptureBracketedStillImageSettings?,
                 error: Error?) {
        // Make sure we get some photo sample buffer
        guard error == nil,
            let photoSampleBuffer = photoSampleBuffer else {
            print("Error capturing photo: \(String(describing: error))")
            return
        }
        
        // Convert photo same buffer to a jpeg image data by using AVCapturePhotoOutput
        guard let imageData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer) else {
            return
        }
        
        // Initialise an UIImage with our image data
        let capturedImage = UIImage.init(data: imageData , scale: 1.0)
        if let image = capturedImage {
            // Save our captured image to photos album
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
    }
}

extension ViewController : AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ captureOutput: AVCaptureMetadataOutput,
                       didOutput metadataObjects: [AVMetadataObject],
                       from connection: AVCaptureConnection) {
        // Check if the metadataObjects array is contains at least one object.
        if metadataObjects.count == 0 {
            qrCodeFrameView?.frame = CGRect.zero
//            messageLabel.isHidden = true
            return
        }
        
        // Get the metadata object.
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        
        if metadataObj.type == AVMetadataObject.ObjectType.qr {
            // If the found metadata is equal to the QR code metadata then update the status label's text and set the bounds
            let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj)
            qrCodeFrameView?.frame = barCodeObject!.bounds
            
            if metadataObj.stringValue != nil {
//                messageLabel.isHidden = false
                messageLabel.text = metadataObj.stringValue
            }
        }
    }
}

extension UIInterfaceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeRight: return .landscapeRight
        case .landscapeLeft: return .landscapeLeft
        case .portrait: return .portrait
        default: return nil
        }
    }
}
