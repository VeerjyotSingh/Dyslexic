//  Created by Veerjyot Singh on 06/11/23.

import UIKit
import AVFoundation
import Vision
import Alamofire

struct MyVariables {
    static var capturedImage:UIImage?
}

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate{
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
    }
    
    @IBAction func captureButton(_ sender: UIButton) {
    }
    
    private var captureSession = AVCaptureSession()
    private var capturePhotoOutput = AVCapturePhotoOutput()
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up the capture session
        captureSession.sessionPreset = .photo
        
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            print("No video device available")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
        } catch {
            print("Error setting up camera input: \(error)")
        }
        
        if captureSession.canAddOutput(capturePhotoOutput) {
            captureSession.addOutput(capturePhotoOutput)
        }
        
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.videoGravity = .resizeAspectFill
        videoPreviewLayer.frame = view.bounds
        view.layer.addSublayer(videoPreviewLayer)
        
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
        
        
        // Create a button for capturing photos
        let captureButton = UIButton(type: .custom)
        captureButton.frame = CGRect(x: view.frame.width / 2, y: view.frame.height - 80, width: 80, height: 80)
        captureButton.layer.borderWidth = 4
        captureButton.layer.borderColor = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        captureButton.layer.cornerRadius = 0.5*captureButton.bounds.size.width
        captureButton.clipsToBounds = true
        captureButton.backgroundColor = UIColor.white
        captureButton.center = CGPoint(x: view.frame.width / 2, y: view.frame.height - 80)
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        view.addSubview(captureButton)
    }
    
    @objc func capturePhoto() {
        let photoSettings = AVCapturePhotoSettings()
        capturePhotoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            return
        }
        
        if let imageData = photo.fileDataRepresentation(),
           let image = UIImage(data: imageData) {
            // Create the ImageViewerViewController
            let imageViewerVC = ImageViewerViewController()
            imageViewerVC.capturedImage = image
            MyVariables.capturedImage = image
            // Present the ImageViewerViewController modally
            performSegue(withIdentifier: "image captured", sender: self)
      }
    }
  }
    
    
    
    class ImageViewerViewController: UIViewController {
        @IBOutlet weak var imageViewer: UIImageView!
        @IBOutlet weak var textView: UITextView!
        var texter = ""
        let apiKey = ""
        let apiUrl = "https://api.openai.com/v1/engines/text-davinci-002/completions"
        var y = true
        let synthesizer = AVSpeechSynthesizer()
        @IBAction func play(_ sender: UIBarButtonItem) {
            if y == true{
                y = false
                let utterance = AVSpeechUtterance(string: texter)
                
                
                // Configure the utterance.
                utterance.rate = 0.5
                utterance.pitchMultiplier = 0.8
                utterance.postUtteranceDelay = 0.2
                utterance.volume = 0.8
                
                
                // Retrieve the British English voice.
                let voice = AVSpeechSynthesisVoice(language: "en-GB")
                
                
                // Assign the voice to the utterance.
                utterance.voice = voice
                // Create a speech synthesizer.
                
                
                // Tell the synthesizer to speak the utterance.
                synthesizer.speak(utterance)
                y = true
            }else{
                print("already speaking")
            }
        }
        
        var capturedImage = MyVariables.capturedImage
        var new:[String] = []
        override func viewWillAppear(_ animated: Bool) {
            
            if let capturedImage = capturedImage {
                // Create an image view and add it to the view controller's view
                let imageView = UIImageView(frame: view.bounds)
                imageView.image = capturedImage
                imageView.contentMode = .scaleAspectFit
                
                if let cgImage = capturedImage.cgImage {
                    let requestHandler = VNImageRequestHandler(cgImage: cgImage)
                    let request = VNRecognizeTextRequest(completionHandler: recognizeTextHandler)
                    
                    do {
                        // Perform the text-recognition request.
                        try requestHandler.perform([request])
                    } catch {
                        print("Unable to perform the requests: \(error).")
                    }
                }
            }
                
        }

           override func viewDidLoad() {
               super.viewDidLoad()
               
           }

        
        func processResults(_ recognizedStrings: [String]) {
            imageViewer.image = capturedImage!
            var str = ""
            for i in recognizedStrings {
                str += i
            }
            let prompt = str+". para was written by a dyslexic person, rewrite the para in normal text."
            print(prompt)
            let parameters: [String: Any] = [
                "prompt": prompt,
                "max_tokens": 500
            ]

            let headers: HTTPHeaders = [
                HTTPHeader(name: "Authorization", value: "Bearer \(apiKey)"),
                HTTPHeader(name: "Content-Type", value: "application/json")
            ]

            AF.request(apiUrl, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
                .responseJSON { response in
                    switch response.result {
                    case .success(let value):
                        if let JSON = value as? [String: Any] {
                            if let choices = JSON["choices"] as? [[String: Any]], let text = choices.first?["text"] as? String {
                                self.textView.text = text
                                self.texter = text
                            }
                        }
                    case .failure(let error):
                        print("Error: \(error)")
                    }
                }
            
        }
        
        func recognizeTextHandler(request: VNRequest, error: Error?) {
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }
            
            let recognizedStrings = observations.compactMap { observation in
                // Return the string of the top VNRecognizedText instance.
                return observation.topCandidates(1).first?.string
            }
            new = recognizedStrings
            processResults(recognizedStrings)
        }
}
