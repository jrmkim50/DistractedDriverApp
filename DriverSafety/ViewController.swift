//
//  ViewController.swift
//  DriverSafety
//
//  Created by Jeremy Kim on 5/25/19.
//  Copyright © 2019 Jeremy Kim. All rights reserved.
//

import UIKit
import AVKit
import Vision
import AVFoundation


class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var prediction: UILabel!
    @IBOutlet weak var screenView: UIImageView!
    var flag = 0
    var count = 1
    var audioPlayer = AVAudioPlayer()
    
    var timer = Timer()
    var isTimerRunning = false
    var seconds = 0
    func runTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: {(timer) in
            self.updateTimer()
        })
    }
    
    @objc func updateTimer() {
        self.seconds += 1
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        prediction.text = "Status: Predicting"
        // Do any additional setup after loading the view, typically from a nib.
        let captureSession = AVCaptureSession()
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {return}
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else {return}
        captureSession.addInput(input)
        captureSession.startRunning()
        
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        cameraView.layer.addSublayer(previewLayer)
        previewLayer.frame = cameraView.frame
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(dataOutput)
        
        runTimer()
        
        
    }

    
    enum HandSign: String {
        case c0 = "c0"
        case c1 = "c1"
        case c2 = "c2"
        case c3 = "c3"
        case c4 = "c4"
        case c5 = "c5"
        case c6 = "c6"
        case c7 = "c7"
        case c8 = "c8"
        case c9 = "c9"
    }
    
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        /* Initialise CVPixelBuffer from sample buffer
         CVPixelBuffer is the input type we will feed our coremlmodel .
         */
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let image = UIImage(cgImage: cgImage)
        DispatchQueue.main.async {
            self.screenView.image = image
        }

        
        /* Initialise Core ML model
         We create a model container to be used with VNCoreMLRequest based on our HandSigns Core ML model.
         */
        guard let handSignsModel = try? VNCoreMLModel(for: b5dd14e01247494e92bdcf246451ac2d().model) else { return }
        
        /* Create a Core ML Vision request
         The completion block will execute when the request finishes execution and fetches a response.
         */
        let request =  VNCoreMLRequest(model: handSignsModel) { (finishedRequest, err) in
            
            /* Dealing with the result of the Core ML Vision request
             The request's result is an array of VNClassificationObservation object which holds
             identifier - The prediction tag we had defined in our Custom Vision model - FiveHand, FistHand, VictoryHand, NoHand
             confidence - The confidence on the prediction made by the model on a scale of 0 to 1
             */
            guard let results = finishedRequest.results as? [VNClassificationObservation] else { return }
            
            /* Results array holds predictions iwth decreasing level of confidence.
             Thus we choose the first one with highest confidence. */
            guard let firstResult = results.first else { return }
            
            var predictionString = ""
            
            let sound = Bundle.main.path(forResource: "submarine-diving-alarm-daniel_simon", ofType: "mp3")
            do {
                self.audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: sound!))
            }
            catch {
                print(error)
            }
            if(self.seconds % 10 == 0 || (self.seconds+1) % 10 == 0 || (self.seconds-1) % 10 == 0) {
                DispatchQueue.main.async {
                    switch firstResult.identifier {
                    case HandSign.c0.rawValue:
                        predictionString = "safe driving"
                        print(self.flag)
                        self.flag = 0
                    case HandSign.c1.rawValue:
                        predictionString = "texting - right"
                        print(self.flag)
                        self.flag = 1
                    case HandSign.c2.rawValue:
                        predictionString = "talking on the phone - right"
                        print(self.flag)
                        self.flag = 1
                    case HandSign.c3.rawValue:
                        predictionString = "texting - left"
                        print(self.flag)
                        self.flag = 1
                    case HandSign.c4.rawValue:
                        predictionString = "talking on the phone - left"
                        print(self.flag)
                        self.flag = 1
                    case HandSign.c5.rawValue:
                        predictionString = "operating the radio"
                        print(self.flag)
                        self.flag = 1
                    case HandSign.c6.rawValue:
                        predictionString = "drinking"
                        print(self.flag)
                        self.flag = 1
                    case HandSign.c7.rawValue:
                        predictionString = "reaching behind"
                        print(self.flag)
                        self.flag = 1
                    case HandSign.c8.rawValue:
                        predictionString = "distracted driver"
                        print(self.flag)
                        self.flag = 1
                    case HandSign.c9.rawValue:
                        predictionString = "talking to passenger"
                        print(self.flag)
                        self.flag = 1
                    default:
                        break
                    }
                    //self.prediction.text = predictionString + "(\(firstResult.confidence))"
                    
                    if (Float(firstResult.confidence) > 0.6) {
                        self.prediction.text = predictionString + "(\(firstResult.confidence))"
                        if (self.flag == 1) {
                            print("flag yes!!!")
                            print(self.flag)
                            
                            self.count+=1
                            if (self.count % 10 == 0) {
                                self.audioPlayer.play()
                                self.count = 1
                            }
                            print("cout: " + String(self.count))
                        }
                    }
                    
                    
                }
            }
            /* Depending on the identifier we set the UILabel text with it's confidence.
             We update UI on the main queue. */
            
        }
        
        /* Perform the above request using Vision Image Request Handler
         We input our CVPixelbuffer to this handler along with the request declared above.
         */
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
    }
    

}
