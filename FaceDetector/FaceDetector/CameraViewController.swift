//
//  ViewController.swift
//  CarsMovie
//
//  Created by Iman Zarrabian on 12/12/2017.
//  Copyright © 2017 Iman Zarrabian. All rights reserved.
//

import UIKit
import Vision
import AVFoundation
import FirebaseDatabase

class CameraViewController: UIViewController {

    @IBOutlet weak var cameraView: UIView!
   
    @IBOutlet private weak var highlightView: UIView? {
        didSet {
            self.highlightView?.layer.borderColor = UIColor.green.cgColor
            self.highlightView?.layer.borderWidth = 4
            self.highlightView?.backgroundColor = .clear
        }
    }
    
    private var lastFaceObservation: VNDetectedObjectObservation?
    private var faceDetectingRequest: VNDetectFaceRectanglesRequest!
    private let faceBoxLayer = CALayer()
    private let visionSequenceHandler = VNSequenceRequestHandler()
    private lazy var cameraLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    private lazy var captureSession: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = AVCaptureSession.Preset.photo
        guard
            let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: backCamera)
            else { return session }
        session.addInput(input)
        return session
    }()
    
    private var ref: DatabaseReference!
    private var oldXSent = CGFloat(0.5)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAndRunVideo()
        setupFaceDetection()
        ref = Database.database().reference()
    }
    
    func setupFaceDetection() {
        faceDetectingRequest = VNDetectFaceRectanglesRequest(completionHandler: self.faceHandler)
    }
    
    func setupAndRunVideo() {
        cameraLayer.connection?.videoOrientation = .landscapeRight
        self.highlightView?.frame = .zero
        
        self.cameraView?.layer.addSublayer(self.cameraLayer)
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoQueue"))
        self.captureSession.addOutput(videoOutput)
        
        self.captureSession.startRunning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // make sure the layer is the correct size
        self.cameraLayer.frame = self.cameraView?.bounds ?? .zero
    }
    
    private func handleVisionRequestUpdate(_ request: VNRequest, error: Error?) {
        // Dispatch to the main queue because we are touching non-atomic, non-thread safe properties of the view controller
        DispatchQueue.main.async {
            // make sure we have an actual result
            guard let newObservation = request.results?.first as? VNDetectedObjectObservation else { return }
            
            // prepare for next loop
            self.lastFaceObservation = newObservation
            
            // check the confidence level before updating the UI
            guard newObservation.confidence >= 0.3 else {
                // hide the rectangle when we lose accuracy so the user knows something is wrong
                print("low accuracy \(newObservation.confidence)")
                self.highlightView?.frame = .zero
                return
            }
            
            self.handleNewObservation(observation: newObservation)
        }
    }
    
    
    func faceHandler(request: VNRequest, error: Error?) {
        
        guard let observations = request.results as? [VNFaceObservation] else {
            print("oooops! didn't provide faces observations")
            return
        }
        DispatchQueue.main.async {
            if let detectedFace = observations.first {
                self.lastFaceObservation = detectedFace
            }
        }
    }
    
    @IBAction func reset(_ sender: UIButton) {
        lastFaceObservation = nil
        oldXSent = CGFloat(0.5)
    }
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard
            // make sure the pixel buffer can be converted
            let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            // make sure that there is a previous observation we can feed into the request
            else { return }
        
        if lastFaceObservation == nil { //Face detection
            var requestOptions: [VNImageOption : Any] = [:]
            
            if let camData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
                requestOptions = [.cameraIntrinsics: camData]
            }
            
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: requestOptions)
            do {
                try imageRequestHandler.perform([faceDetectingRequest])
            } catch {
                print(error)
            }
        } else { //Object (Face) Tracking
            let request = VNTrackObjectRequest(detectedObjectObservation: lastFaceObservation!, completionHandler: handleVisionRequestUpdate)

            request.trackingLevel = .accurate
            
            do {
                try self.visionSequenceHandler.perform([request], on: pixelBuffer)
            } catch {
                print("Throws: \(error)")
            }
        }
    }
}


extension CameraViewController {
    func handleNewObservation(observation: VNDetectedObjectObservation) {
        
        //https://github.com/jeffreybergier/Blog-Getting-Started-with-Vision/issues/2
        
        var transformedRect = observation.boundingBox
        transformedRect.origin.y = 1 - (observation.boundingBox.origin.y + observation.boundingBox.size.height)
        transformedRect.origin.x = 1 - observation.boundingBox.origin.x
        
        sendXPositionToRemote(x: transformedRect.origin.x)
        drawBox(normalizedRect: transformedRect)
    }
    
    func drawBox(normalizedRect rect: CGRect) {
        var convertedRect = self.cameraLayer.layerRectConverted(fromMetadataOutputRect: rect)
       // print("converted rectangle \(convertedRect)")
        
        convertedRect.origin.x = cameraView.frame.size.width - convertedRect.origin.x
        
        faceBoxLayer.removeFromSuperlayer()
        faceBoxLayer.frame = convertedRect
        faceBoxLayer.borderWidth = 1.0
        faceBoxLayer.borderColor = UIColor.green.cgColor
        
        cameraView.layer.addSublayer(faceBoxLayer)
    }
    
    func sendXPositionToRemote(x: CGFloat) {
        let tsString = String(Date().timeIntervalSince1970)
        let tsStringComponents = tsString.split(separator: ".")
        let flatDate = tsStringComponents.joined(separator: "")
        if abs(oldXSent - x) > 0.1 && abs(0.5 - x) > 0.25 && x < 1.0 && x > 0.0 {
            print("sending \(x)")
            oldXSent = x
            ref.child("deltas").updateChildValues([flatDate: x])
        }
    }
}
