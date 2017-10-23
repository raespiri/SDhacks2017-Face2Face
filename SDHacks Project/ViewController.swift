//
//  ViewController.swift
//  SDHacks Project
//
//  Created by Toshitaka on 10/20/17.
//  Copyright © 2017 Toshitaka. All rights reserved.
//

import UIKit
import AVFoundation
import Speech

class ViewController: UIViewController,AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureFileOutputRecordingDelegate, SFSpeechRecognizerDelegate {

    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var bigView: UIView!
    @IBOutlet weak var buttonBar: UIView!
    @IBOutlet weak var viewSwitch: UIButton!
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var videoButton: UIButton!
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var settingsButton: UIButton!
    
    var flashMode:Int = 0
    var capturing:Bool = false
    var panGesture = UIPinchGestureRecognizer()
    
    let imagePicker = UIImagePickerController()
    var session: AVCaptureSession?
    var input: AVCaptureDeviceInput?
    var output: AVCaptureVideoDataOutput?
    var outputMovie: AVCaptureMovieFileOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var AVDevice: AVCaptureDevice?

    let minimumZoom: CGFloat = 1.0
    let maximumZoom: CGFloat = 3.0
    var lastZoomFactor: CGFloat = 1.0
    
    let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy : CIDetectorAccuracyLow])
    let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    let audioEngine = AVAudioEngine()
    var secondsWithoutMouthMovement = 0
    
    var assetWriterInput: AVAssetWriterInput?
    var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    var assetWriter: AVAssetWriter?
    var frameNumber: Int64 = 0

    var file_url: URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //gesture not working for pinch zoom
        panGesture = UIPinchGestureRecognizer.init(target: self, action: #selector(pinch(_:)))
        cameraView.addGestureRecognizer(panGesture)

        self.view.bringSubview(toFront: self.buttonBar)
        
        // Do any additional setup after loading the view, typically from a nib.
        session = AVCaptureSession()
//        outputMovie = AVCaptureMovieFileOutput()
//        output?.alwaysDiscardsLateVideoFrames = true
        
        do {
            AVDevice = getDevice(position: .front)
            let deviceInput = try AVCaptureDeviceInput(device: AVDevice)
            
            if (session?.canAddInput(deviceInput) == true) {
                session?.addInput(deviceInput)
            }
            
            let dataOutput = AVCaptureVideoDataOutput()
            
            dataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange as UInt32)]
            
            dataOutput.alwaysDiscardsLateVideoFrames = true
            
            if (session?.canAddOutput(dataOutput) == true) {
                session?.addOutput(dataOutput)
            }
            
            previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
            previewLayer?.connection.videoOrientation = AVCaptureVideoOrientation.portrait
            previewLayer?.frame = cameraView.bounds
            cameraView.layer.addSublayer(previewLayer!)
            
            session?.startRunning()
            
            let queue = DispatchQueue(label: "videoQueue", qos: .background, attributes: .concurrent)
            dataOutput.setSampleBufferDelegate(self, queue: queue)
        }
        catch let error as NSError {
            NSLog("\(error), \(error.localizedDescription)")
        }
    }
    
    @IBAction func toggleCamera(_ sender: Any) {
        switchCameraView()
    }
    
    func switchCameraView() {
        // Get current input
        guard let input = self.session?.inputs[0] as? AVCaptureDeviceInput else { return }
        
        // Begin new session configuration and defer commit
        self.session?.beginConfiguration()
        defer { self.session?.commitConfiguration() }
        
        // Create new capture device
        var newDevice: AVCaptureDevice?
        if input.device.position == .back {
            newDevice = self.getDevice(position: .front)
        } else {
            newDevice = self.getDevice(position: .back)
        }
        
        // Create new capture input
        var deviceInput: AVCaptureDeviceInput!
        do {
            deviceInput = try AVCaptureDeviceInput(device: newDevice)
        } catch let error {
            print(error.localizedDescription)
            return
        }
        
        // Swap capture device inputs
        self.session?.removeInput(input)
        self.session?.addInput(deviceInput)
    }

    @IBAction func flashButtonPressed(_ sender: UIButton) {
        if(flashMode == 0) {
            flashButton.setImage( UIImage(named:"Flash_On"), for: UIControlState.normal)
            flashMode = 1
        }
        else if(flashMode == 1) {
            flashButton.setImage( UIImage(named:"Flash_Off"), for: UIControlState.normal)
            flashMode = 0
            
            flashOff(device: AVDevice!)
            //turn flash off
        }
    }
    
    @IBAction func capturePressed(_ sender: Any) {
        if capturing && audioEngine.isRunning{
            capturing = false
            audioEngine.stop()
            recognitionRequest?.endAudio()
            captureButton.setImage(UIImage(named: "Button_Unpressed"), for: UIControlState.normal)
            
            assetWriter?.endSession(atSourceTime: CMTimeMake(frameNumber, 25))
            assetWriter?.finishWriting(completionHandler: {
                if self.assetWriter?.status == AVAssetWriterStatus.failed {
                    print("FAILED")
                }
                else {
                    print("NOT FAILED")
                }
            })
            
            UISaveVideoAtPathToSavedPhotosAlbum((file_url?.path)!, self, nil, nil)

            if flashMode == 1 {
                flashOff(device: AVDevice!)
            }
        }
        else {
            capturing = true
            captureButton.setImage(UIImage(named: "Button_Pressed"), for: UIControlState.normal)
            try! startRecording()
            
            assetWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo,outputSettings: [AVVideoWidthKey: Int(640), AVVideoHeightKey: Int(480), AVVideoCodecKey: AVVideoCodecType.h264])
            
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput!, sourcePixelBufferAttributes:
                [ kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32BGRA)])
            
            
            assetWriter = try! AVAssetWriter(outputURL: getURL(), fileType: AVFileTypeMPEG4)
            assetWriter?.add(assetWriterInput!)
            assetWriterInput?.expectsMediaDataInRealTime = true
            
            assetWriter?.startWriting()
            assetWriter?.startSession(atSourceTime: kCMTimeZero)
            
            if flashMode == 1 {
                flashOn(device: AVDevice!)
            }
        }
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        speechRecognizer.delegate = self
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            /*
             The callback may not be called on the main thread. Add an
             operation to the main queue to update the record button's state.
             */
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.captureButton.isEnabled = true
                    
                case .denied:
                    self.captureButton.isEnabled = false
                    
                case .restricted:
                    self.captureButton.isEnabled = false
                    
                case .notDetermined:
                    self.captureButton.isEnabled = false
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Hide the navigation bar on the this view controller
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Show the navigation bar on other view controllers
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    //Get the device (Front or Back)
    func getDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let device_types:[AVCaptureDeviceType] = [AVCaptureDeviceType.builtInDualCamera,
                                                  AVCaptureDeviceType.builtInMicrophone,
                                                  AVCaptureDeviceType.builtInTelephotoCamera,
                                                  AVCaptureDeviceType.builtInWideAngleCamera]
        let discoSes = AVCaptureDevice.DiscoverySession.init(deviceTypes: device_types, mediaType: nil, position: position)
        let deviceList: NSArray = discoSes!.devices as NSArray;
        for de in deviceList {
            let deviceConverted = de as! AVCaptureDevice
            if(deviceConverted.position == position){
                return deviceConverted
            }
        }
        return nil
    }
    
    func capture(_ output: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        print("capture")
    }
    
    func pinch(_ pinch: UIPinchGestureRecognizer) {
        guard let device = AVDevice else { return }
        
        // Return zoom value between the minimum and maximum zoom values
        func minMaxZoom(_ factor: CGFloat) -> CGFloat {
            return min(min(max(factor, minimumZoom), maximumZoom), device.activeFormat.videoMaxZoomFactor)
        }
        
        func update(scale factor: CGFloat) {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.videoZoomFactor = factor
            } catch {
                print("\(error.localizedDescription)")
            }
        }
        
        let newScaleFactor = minMaxZoom(pinch.scale * lastZoomFactor)
        
        switch pinch.state {
        case .began: fallthrough
        case .changed: update(scale: newScaleFactor)
        case .ended:
            lastZoomFactor = minMaxZoom(newScaleFactor)
            update(scale: lastZoomFactor)
        default: break
        }
    }
    
    private func flashOff(device:AVCaptureDevice)
    {
        do{
            if (device.hasTorch){
                try device.lockForConfiguration()
                device.torchMode = .off
                device.flashMode = .off
                device.unlockForConfiguration()
            }
        }catch{
            //DISABEL FLASH BUTTON HERE IF ERROR
            print("Device tourch Flash Error ");
        }
    }
    
    private func flashOn(device:AVCaptureDevice)
    {
        do{
            if (device.hasTorch)
            {
                try device.lockForConfiguration()
                device.torchMode = .on
                device.flashMode = .on
                device.unlockForConfiguration()
            }
        }catch{
            //DISABEL FLASH BUTTON HERE IF ERROR
            print("Device tourch Flash Error ");
        }
    }
    
    private func startRecording() throws {
        
        // Cancel the previous task if it's running.
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        self.secondsWithoutMouthMovement = 0

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(AVAudioSessionCategoryRecord)
        try audioSession.setMode(AVAudioSessionModeMeasurement)
        try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let inputNode = audioEngine.inputNode else { fatalError("Audio engine has no input node") }
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object") }
        
        // Configure request so that results are returned before audio recording is finished
        recognitionRequest.shouldReportPartialResults = true
        
        // A recognition task represents a speech recognition session.
        // We keep a reference to the task so that it can be cancelled.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                if self.secondsWithoutMouthMovement > 2 {
                    self.switchCameraView()
                    self.secondsWithoutMouthMovement = 0
                    //                    print(result.bestTranscription.formattedString)
                    isFinal = result.isFinal
                }
                else {
                    //                    print(result.bestTranscription.formattedString)
                    isFinal = result.isFinal
                }
                
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.captureButton.isEnabled = true
                self.captureButton.setImage(UIImage(named: "Button_Unpressed"), for: UIControlState.normal)
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        try audioEngine.start()
    }
    
    func captureOutput(_ output: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        DispatchQueue.main.sync {
            let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate)
            let ciImage = CIImage(cvImageBuffer: pixelBuffer!, options: attachments as! [String : Any]?)
            let allFeatures = self.faceDetector?.features(in: ciImage, options: [CIDetectorImageOrientation: exifOrientation(orientation: UIDevice.current.orientation), CIDetectorSmile: true])
            
            guard let features = allFeatures else { return }
            for feature in features as! [CIFaceFeature] {
                if(feature.hasSmile) {
//                                        print("Talking")
                    secondsWithoutMouthMovement = 0
                }
                else{
//                                        print("Not talking")
                    secondsWithoutMouthMovement = secondsWithoutMouthMovement + 1
                }
            }
            if(capturing) {
                let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
                if (assetWriterInput?.isReadyForMoreMediaData)! {
                    pixelBufferAdaptor?.append(imageBuffer!, withPresentationTime: CMTimeMake(frameNumber, 25))
                }
                frameNumber += 1
                assetWriterInput?.markAsFinished()
            }
        }
    }
    
    func exifOrientation(orientation: UIDeviceOrientation) -> Int {
        switch orientation {
        case .portraitUpsideDown:
            return 8
        case .landscapeLeft:
            return 3
        case .landscapeRight:
            return 1
        default:
            return 6
        }
    }

    func getURL() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        file_url = paths[0].appendingPathComponent("output.mov")
        return file_url!
    }
    
}
