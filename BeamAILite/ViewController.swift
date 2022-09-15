//
//  ViewController.swift
//  BeamAILite
//

import UIKit
import AVFoundation
import BeamAISDK

class ViewController: UIViewController {

    // Beam AI objects and modules
    private var beamAI: BeamAI?
    private var timer: Timer?
    
    // Camera preview
    @IBOutlet weak var cameraPreview: PreviewView!
    
    // Button pointers
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    
    // View pointers
    @IBOutlet weak var heartRateView: UIView!
    @IBOutlet weak var hrvView: UIView!
    @IBOutlet weak var stressView: UIView!
    
    // View text pointers
    @IBOutlet weak var heartRateLabel: UILabel!
    @IBOutlet weak var hrvLabel: UILabel!
    @IBOutlet weak var stressLabel: UILabel!
    
    // Stress classification banner pointers
    @IBOutlet weak var stressClassificationBanner: UIView!
    @IBOutlet weak var stressClassificationLabel: UILabel!
    
    // Banner pointers
    @IBOutlet weak var timerBanner: UIView!
    @IBOutlet weak var timerLabel: UILabel!
    @IBOutlet weak var pleaseWaitBanner: UIView!
    @IBOutlet weak var valuesBefore1MinCanBeNoisyBanner: UIView!
    @IBOutlet weak var medicalMessageBanner: UIView!
    @IBOutlet weak var noFaceDetectedBanner: UIView!
    
    // Time stamp
    private var counter: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        // Initialize Beam AI object
        self.beamAI = try! BeamAI(beamID: "your-20-char-beamID", frameRate: 30, window: 60.0, updateEvery: 1.0)
        
        // Set up camera preview
        self.cameraPreview.session = self.beamAI?.getCameraSession()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set up Beam AI object
        self.beamAI?.startSession()
        
        // Move UI to stopped mode
        self.moveUIToStoppedMode()
        self.pleaseWaitBanner.isHidden = true
        self.timerBanner.isHidden = true
        
        // Set up foreground and background manager
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    @objc func appMovedToBackground() {
        // Reset everything
        self.counter = 0
        self.timer?.invalidate()
        self.beamAI?.stopMonitoring()
        self.moveUIToStoppedMode()
    }
    
    private func showValidationErrorMessage() {
        let alert = UIAlertController(title: "Validation Failed", message: "Beam AI SDK validation was not successful. You will not be able to continue monitoring your stress, heart rate and heart rate variability. If you have an invalid beamID, please obtain a valid beamID. If you don't have internet connection, please connect to the internet and restart the app.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            // Do nothing
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func startButtonPressed(_ sender: Any) {
        
        // Invalidate timer in case it is running
        self.timer?.invalidate()
        self.clearLabels()
        do {
            try self.beamAI?.startMonitoring()
        } catch {
            self.showValidationErrorMessage()
        }
        
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            let output = self.beamAI?.getEstimates()
            
            // Validation has failed or another issue has happened and monitoring cannot progress
            if (output!["CODE"] as! String == "S1-SDKIsNotMonitoring") ||
                (output!["CODE"] as! String == "E1-SDKValidationRejected") ||
                (output!["CODE"] as! String == "E2-CameraSessionNotRunning")
            {
                self.counter = 0
                self.timer?.invalidate()
                self.beamAI?.stopMonitoring()
                self.moveUIToStoppedMode()
            }
            
            if (output!["CODE"] as! String == "S2-NoFaceDetected") {
                
                self.pleaseWaitBanner.isHidden = true
                self.valuesBefore1MinCanBeNoisyBanner.isHidden = true
                self.noFaceDetectedBanner.isHidden = false
                self.clearLabels()
                self.counter = 0
                
            } else if (output!["CODE"] as! String == "S3-NotEnoughFramesProcessed") {
                
                // Increase timer
                self.counter += 1
                let hoursTime = self.counter / 3600
                let minutesTime = (self.counter % 3600) / 60
                let secondsTime = self.counter % 60
                self.timerLabel.text = String(format: "%02d", hoursTime) + ":" + String(format: "%02d", minutesTime) + ":" + String(format: "%02d", secondsTime)
                
                // Modify banners
                self.pleaseWaitBanner.isHidden = false
                self.valuesBefore1MinCanBeNoisyBanner.isHidden = false
                self.noFaceDetectedBanner.isHidden = true
                
                // Reset labels
                self.stressLabel.text = "---"
                self.hrvLabel.text = "---"
                self.heartRateLabel.text = "---"
                
                // Reset stress classification banner
                self.stressClassificationBanner.backgroundColor = .black
                self.stressClassificationLabel.text = "---"
                
            } else if (output!["CODE"] as! String == "S4-NotFullWindow") ||
                (output!["CODE"] as! String == "S5-FullResults") {
                
                // Increase timer
                self.counter += 1
                let hoursTime = self.counter / 3600
                let minutesTime = (self.counter % 3600) / 60
                let secondsTime = self.counter % 60
                self.timerLabel.text = String(format: "%02d", hoursTime) + ":" + String(format: "%02d", minutesTime) + ":" + String(format: "%02d", secondsTime)
                
                // Update values
                self.updateHeartRate(heartRate: output!["HEARTRATE"] as! Double)
                self.updateHRV(heartRateVariability: output!["HRV"] as! Double)
                self.updateStress(stress: output!["STRESS"] as! Double)
                
                if (output!["CODE"] as! String == "S4-NotFullWindow") {
                    
                    // Modify banners
                    self.pleaseWaitBanner.isHidden = true
                    self.valuesBefore1MinCanBeNoisyBanner.isHidden = false
                    self.noFaceDetectedBanner.isHidden = true
                    
                } else {
                    
                    // Modify banners
                    self.pleaseWaitBanner.isHidden = true
                    self.valuesBefore1MinCanBeNoisyBanner.isHidden = true
                    self.noFaceDetectedBanner.isHidden = true
                    
                }
                
            }
        }
        
        self.moveUIToMeasuringMode()
    }
    
    private func updateHeartRate(heartRate: Double) {
        if heartRate < 0 { return }
        
        if heartRate.isNaN {
            self.heartRateLabel.text = "NaN"
        } else {
            self.heartRateLabel.text = "\(round(heartRate * 10) / 10)"
        }
    }
    
    private func updateHRV(heartRateVariability: Double) {
        if heartRateVariability < 0 { return }
        
        if heartRateVariability.isNaN {
            self.hrvLabel.text = "NaN"
        } else {
            self.hrvLabel.text = "\(Int(round(heartRateVariability * 1000)))"
        }
    }
    
    private func updateStress(stress: Double) {
        if stress < 0 { return }
        
        if stress.isNaN {
            
            self.stressLabel.text = "NaN"
            self.stressClassificationLabel.text = "---"
            self.stressClassificationBanner.backgroundColor = .black
            
        } else {
        
            let stressRounded = round(stress * 100) / 100
            self.stressLabel.text = "\(stressRounded)"
        
            if (stressRounded < 1.5) {
                self.stressClassificationLabel.text = "Normal"
                self.stressClassificationBanner.backgroundColor = UIColor(red: 12/256, green: 128/256, blue: 42/256, alpha: 1.0)
            } else if (1.5 <= stressRounded) && (stressRounded < 2.5) {
                self.stressClassificationLabel.text = "Mild"
                self.stressClassificationBanner.backgroundColor = .blue
            } else if (2.5 <= stressRounded) && (stressRounded < 3.5) {
                self.stressClassificationLabel.text = "High"
                self.stressClassificationBanner.backgroundColor = .orange
            } else if (3.5 <= stressRounded)  {
                self.stressClassificationLabel.text = "Very High"
                self.stressClassificationBanner.backgroundColor = .red
            }
            
        }
    }
    
    @IBAction func stopButtonPressed(_ sender: Any) {
        self.counter = 0
        self.timer?.invalidate()
        self.beamAI?.stopMonitoring()
        self.moveUIToStoppedMode()
    }
    
    private func moveUIToStoppedMode() {
        
        self.heartRateView.isHidden = true
        self.hrvView.isHidden = true
        self.stressView.isHidden = true
        self.stopButton.isHidden = true
        
        self.timerBanner.isHidden = true
        self.pleaseWaitBanner.isHidden = true
        
        self.startButton.isHidden = false
        
        self.pleaseWaitBanner.isHidden = true
        self.timerBanner.isHidden = true
        self.valuesBefore1MinCanBeNoisyBanner.isHidden = true
        
        self.medicalMessageBanner.isHidden = true
        self.noFaceDetectedBanner.isHidden = true
        
    }
    
    private func moveUIToMeasuringMode() {
        self.heartRateView.isHidden = false
        self.hrvView.isHidden = false
        self.stressView.isHidden = false
        self.stopButton.isHidden = false
        
        self.timerBanner.isHidden = false
        self.pleaseWaitBanner.isHidden = false
        
        self.startButton.isHidden = true
        
        self.pleaseWaitBanner.isHidden = false
        self.timerBanner.isHidden = false
        self.valuesBefore1MinCanBeNoisyBanner.isHidden = false
        
        self.medicalMessageBanner.isHidden = false
        self.noFaceDetectedBanner.isHidden = true
    }
    
    private func clearLabels() {
        
        // Reset labels
        self.stressLabel.text = "---"
        self.hrvLabel.text = "---"
        self.heartRateLabel.text = "---"
        
        // Reset stress classification banner
        self.stressClassificationBanner.backgroundColor = .black
        self.stressClassificationLabel.text = "---"
        
        // Reset timer label
        self.timerLabel.text = "00:00:00"
        
    }
    
    private func updatePreviewLayer(layer: AVCaptureConnection, orientation: AVCaptureVideoOrientation) {
        layer.videoOrientation = orientation
        self.cameraPreview.frame = view.bounds
        self.cameraPreview.videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if let connection = self.cameraPreview.videoPreviewLayer.connection {
            let currentDevice = UIDevice.current
            let orientation: UIDeviceOrientation = currentDevice.orientation
            let previewLayerConnection: AVCaptureConnection = connection
            
            if previewLayerConnection.isVideoOrientationSupported {
                switch orientation {
                case .portrait: self.updatePreviewLayer(layer: previewLayerConnection, orientation: .portrait)
                case .landscapeRight: self.updatePreviewLayer(layer: previewLayerConnection, orientation: .landscapeLeft)
                case .landscapeLeft: self.updatePreviewLayer(layer: previewLayerConnection, orientation: .landscapeRight)
                case .portraitUpsideDown: self.updatePreviewLayer(layer: previewLayerConnection, orientation: .portraitUpsideDown)
                default: self.updatePreviewLayer(layer: previewLayerConnection, orientation: .portrait)
                }
            }
        }
    }
}

