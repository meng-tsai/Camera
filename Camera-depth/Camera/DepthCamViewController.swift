//
//  DepthCamViewController.swift
//  Camera
//
//  Created by WANG on 7/26/20.
//  Copyright © 2020 Rizwan. All rights reserved.
//

import UIKit
import AVFoundation


class DepthCamViewController: UIViewController {

    @IBOutlet weak var previewView: UIView!
    
    @IBAction func onTapTakePhoto(_ sender: Any) {

        guard var capturePhotoOutput = self.capturePhotoOutput else { return }

        var photoSettings = AVCapturePhotoSettings()
        photoSettings.isDepthDataDeliveryEnabled = true

        capturePhotoOutput.capturePhoto(with: photoSettings, delegate: self)

    }

    var session: AVCaptureSession?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var capturePhotoOutput: AVCapturePhotoOutput?


    override func viewDidLoad() {
        super.viewDidLoad()

        AVCaptureDevice.requestAccess(for: .video, completionHandler: { _ in })

        let captureDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back)

        print(captureDevice!.activeDepthDataFormat)

        do{
            let input = try AVCaptureDeviceInput(device: captureDevice!)

            self.capturePhotoOutput = AVCapturePhotoOutput()

            self.session = AVCaptureSession()
            self.session?.beginConfiguration()
            self.session?.sessionPreset = .photo
            self.session?.addInput(input)

            self.videoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.session!)
            self.videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
            self.videoPreviewLayer?.frame = self.view.layer.bounds
            self.previewView.layer.addSublayer(self.videoPreviewLayer!)

            self.session?.addOutput(self.capturePhotoOutput!)
            self.session?.commitConfiguration()
            self.capturePhotoOutput?.isDepthDataDeliveryEnabled = true
            self.session?.startRunning()
        }
        catch{
            print(error)
        }

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

extension DepthCamViewController : AVCapturePhotoCaptureDelegate {

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print(photo.depthData)
        guard let imageData = photo.fileDataRepresentation() else {
            fatalError("imageData No available")
        }
        
        let capturedImage = UIImage.init(data: imageData , scale: 1.0)
        if let image = capturedImage {
            // Save our captured image to photos album
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
    }


}
