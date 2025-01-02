import AVFoundation
import CoreImage
import UIKit
import Vision
import os.log

class Camera: NSObject {
    // Keep a weak ref to CameraModel because
    // The user preference settings are there
    weak var cameraModel: CameraModel?
    
    // Facial recognition and tracking related
    var shouldDetectFace = false
    private var detectionRequests: [VNDetectFaceRectanglesRequest]?
    private var trackingRequests: [VNTrackObjectRequest]?
    lazy var sequenceRequestHandler = VNSequenceRequestHandler()
    
    private let captureSession = AVCaptureSession()
    private var isCaptureSessionConfigured = false
    private var deviceInput: AVCaptureDeviceInput?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var sessionQueue = DispatchQueue(label: "session queue")
    
    var deviceResolution: CGSize = CGSize() {
        didSet {
            cameraModel?.deviceResolution = deviceResolution
            cameraModel?.ratio = deviceResolution.width / deviceResolution.height
        }
    }

    var captureDevice: AVCaptureDevice? {
        didSet {
            guard let captureDevice = captureDevice else { return }
            sessionQueue.async {
                self.updateSessionForCaptureDevice(captureDevice)
            }
            
//            logger.debug("Active format is \(captureDevice.activeFormat)")
//            for format in captureDevice.formats {
//                logger.debug("Found format \(format.description)")
//                for dimension in format.supportedMaxPhotoDimensions {
//                    logger.debug("Found supportedDimension \(dimension.width) * \(dimension.height) (\(Float(dimension.width) / Float(dimension.height))")
//                }
//            }
        }
    }
    
    var isRunning: Bool {
        captureSession.isRunning
    }
    
    var isUsingFrontCaptureDevice: Bool {
        guard let captureDevice = captureDevice else { return false }
        return captureDevice.position == .front
    }
    
    var isUsingBackCaptureDevice: Bool {
        guard let captureDevice = captureDevice else { return false }
        return captureDevice.position == .front
    }
    
    private var addToPreviewImageStream: ((CIImage) -> Void)?
    
    private var addToPreviewFaceBoundsStream: (([CGRect]) -> Void)?
    
    private var addToUploadStream: ((CVPixelBuffer) -> Void)?
    
    private var facePixelBufferRenderContext = CIContext()
    
    var isPreviewPaused = false
    
    lazy var previewImageStream: AsyncStream<CIImage> = {
        AsyncStream { continuation in
            addToPreviewImageStream = { ciImage in
                if !self.isPreviewPaused {
                    continuation.yield(ciImage)
                }
            }
        }
    }()
    
    lazy var previewFaceBoundsStream: AsyncStream<[CGRect]> = {
        AsyncStream { continuation in
            addToPreviewFaceBoundsStream = { bounds in
                continuation.yield(bounds)
            }
        }
    }()
    
    lazy var pixelBufferToUploadStream: AsyncStream<CVPixelBuffer> = {
        AsyncStream { continuation in
            addToUploadStream = { ciImage in
                continuation.yield(ciImage)
            }
        }
    }()
        
    override init() {
        super.init()
        initialize()
    }
    
    public func initialize() {
        /// Don't do camera inidialization if in preview
        guard !isInPreview() else {
            return
        }

        prepareVisionRequest() // Prepare facial recognition & tracking
        
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(self, selector: #selector(updateForDeviceOrientation), name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    private func configureCaptureSession(completionHandler: (_ success: Bool) -> Void) {
        
        var success = false
        
        self.captureSession.beginConfiguration()
        
        defer {
            self.captureSession.commitConfiguration()
            completionHandler(success)
        }
        
        guard
            let captureDevice = captureDevice,
            let deviceInput = try? AVCaptureDeviceInput(device: captureDevice)
        else {
            logger.error("Failed to obtain video input.")
            return
        }
        
        let photoOutput = AVCapturePhotoOutput()
                        
        captureSession.sessionPreset = AVCaptureSession.Preset.photo

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoDataOutputQueue"))
  
        guard captureSession.canAddInput(deviceInput) else {
            logger.error("Unable to add device input to capture session.")
            return
        }
        guard captureSession.canAddOutput(photoOutput) else {
            logger.error("Unable to add photo output to capture session.")
            return
        }
        guard captureSession.canAddOutput(videoOutput) else {
            logger.error("Unable to add video output to capture session.")
            return
        }
        
        captureSession.addInput(deviceInput)
        captureSession.addOutput(photoOutput)
        captureSession.addOutput(videoOutput)
        
        self.deviceInput = deviceInput
        self.photoOutput = photoOutput
        self.videoOutput = videoOutput
        

//        photoOutput.isHighResolutionCaptureEnabled = true // deprecated, use the alternative below
        logger.debug("During ConfigureCaptureSession, activeFormat of \(deviceInput.device.localizedName) is \(deviceInput.device.activeFormat.description)")
        var bestDimension: CMVideoDimensions?
        for dimension in deviceInput.device.activeFormat.supportedMaxPhotoDimensions {
            if dimension.width > bestDimension?.width ?? 0 && dimension.height > bestDimension?.height ?? 0 {
                bestDimension = dimension
            }
        }
        if let bestDimension {
            photoOutput.maxPhotoDimensions = bestDimension
            self.deviceResolution = CGSize(width: CGFloat(bestDimension.width), height: CGFloat(bestDimension.height))
            logger.debug("Setting photoOutput maxPhotoDimensions to \(bestDimension.width) x \(bestDimension.height). Camera.deviceResolution = \(self.deviceResolution.debugDescription)")
        }
        
        photoOutput.maxPhotoQualityPrioritization = .quality
        
        updateVideoOutputConnection()
        
        isCaptureSessionConfigured = true
        
        success = true
    }
    
    private func checkAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            logger.debug("Camera access authorized.")
            return true
        case .notDetermined:
            logger.debug("Camera access not determined.")
            sessionQueue.suspend()
            let status = await AVCaptureDevice.requestAccess(for: .video)
            sessionQueue.resume()
            return status
        case .denied:
            logger.debug("Camera access denied.")
            return false
        case .restricted:
            logger.debug("Camera library access restricted.")
            return false
        @unknown default:
            return false
        }
    }
    
    private func deviceInputFor(device: AVCaptureDevice?) -> AVCaptureDeviceInput? {
        guard let validDevice = device else { return nil }
        do {
            return try AVCaptureDeviceInput(device: validDevice)
        } catch let error {
            logger.error("Error getting capture device input: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func updateSessionForCaptureDevice(_ captureDevice: AVCaptureDevice) {
        guard isCaptureSessionConfigured else { return }
        
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        for input in captureSession.inputs {
            if let deviceInput = input as? AVCaptureDeviceInput {
                captureSession.removeInput(deviceInput)
            }
        }
        
        if let deviceInput = deviceInputFor(device: captureDevice) {
            if !captureSession.inputs.contains(deviceInput), captureSession.canAddInput(deviceInput) {
                captureSession.addInput(deviceInput)
            }
        }
        
        updateVideoOutputConnection()
    }
    
    private func updateVideoOutputConnection() {
        if let videoOutput = videoOutput, let videoOutputConnection = videoOutput.connection(with: .video) {
            if videoOutputConnection.isVideoMirroringSupported {
                videoOutputConnection.isVideoMirrored = isUsingFrontCaptureDevice
            }
        }
    }
    
    func start() async {
        let authorized = await checkAuthorization()
        guard authorized else {
            logger.error("Camera access was not authorized.")
            return
        }
        
        if isCaptureSessionConfigured {
            if !captureSession.isRunning {
                sessionQueue.async { [self] in
                    self.captureSession.startRunning()
                }
            }
            return
        }
        
        sessionQueue.async { [self] in
            self.configureCaptureSession { success in
                guard success else { return }
                self.captureSession.startRunning()
            }
        }
    }
    
    func stop() {
        guard isCaptureSessionConfigured else { return }
        
        if captureSession.isRunning {
            sessionQueue.async {
                self.captureSession.stopRunning()
            }
        }
    }
    
//    func switchCaptureDevice() {
//        if let captureDevice = captureDevice, let index = availableCaptureDevices.firstIndex(of: captureDevice) {
//            let nextIndex = (index + 1) % availableCaptureDevices.count
//            self.captureDevice = availableCaptureDevices[nextIndex]
//        } else {
//            self.captureDevice = AVCaptureDevice.default(for: .video)
//        }
//    }

    private var deviceOrientation: UIDeviceOrientation {
        var orientation = UIDevice.current.orientation
        if orientation == UIDeviceOrientation.unknown {
            orientation = UIScreen.main.orientation
        }
        return orientation
    }
    
    @objc
    func updateForDeviceOrientation() {
        //TODO: Figure out if we need this for anything.
    }
    
    private func videoOrientationFor(_ deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation? {
        switch deviceOrientation {
        case .portrait: return AVCaptureVideoOrientation.portrait
        case .portraitUpsideDown: return AVCaptureVideoOrientation.portraitUpsideDown
        case .landscapeLeft: return AVCaptureVideoOrientation.landscapeRight
        case .landscapeRight: return AVCaptureVideoOrientation.landscapeLeft
        default: return nil
        }
    }
    
    private func exifOrientationFor(_ deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        switch deviceOrientation {
        case .portraitUpsideDown:
            return .rightMirrored
            
        case .landscapeLeft:
            return .downMirrored
            
        case .landscapeRight:
            return .upMirrored
            
        default:
            return .leftMirrored
        }
    }
    
//    func takePhoto() {
//        guard let photoOutput = self.photoOutput else { return }
//        
//        sessionQueue.async {
//        
//            var photoSettings = AVCapturePhotoSettings()
//
//            if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
//                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
//            }
//            
//            let isFlashAvailable = self.deviceInput?.device.isFlashAvailable ?? false
//            photoSettings.flashMode = isFlashAvailable ? .auto : .off
//            photoSettings.isHighResolutionPhotoEnabled = true
//            if let previewPhotoPixelFormatType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
//                photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPhotoPixelFormatType]
//            }
//            photoSettings.photoQualityPrioritization = .balanced
//            
//            if let photoOutputVideoConnection = photoOutput.connection(with: .video) {
//                if photoOutputVideoConnection.isVideoOrientationSupported,
//                    let videoOrientation = self.videoOrientationFor(self.deviceOrientation) {
//                    photoOutputVideoConnection.videoOrientation = videoOrientation
//                }
//            }
//            
//            photoOutput.capturePhoto(with: photoSettings, delegate: self)
//        }
//    }
    
    private func prepareVisionRequest() {
        var trackingRequests = [VNTrackObjectRequest]()
        
        let faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: { (request, error) in
            if error != nil {
                logger.error("FaceDetection error: \(String(describing: error)).")
                return
            }
            
            guard let faceDetectionRequest = request as? VNDetectFaceRectanglesRequest,
                  let results = faceDetectionRequest.results else {
                return
            }

            DispatchQueue.main.async {
                // Add the observations to the tracking list
                for observation in results {
                    guard self.observationIsConfident(observation) else { continue }
                    let faceTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
                    trackingRequests.append(faceTrackingRequest)
                    logger.debug("FaceDetection found: \(observation.debugDescription)")
                }
                self.trackingRequests = trackingRequests
            }
        })
        
        // Start with detection.  Find face, then track it.
        self.detectionRequests = [faceDetectionRequest]
        
        self.sequenceRequestHandler = VNSequenceRequestHandler()
    }
    
    private func observationIsConfident(_ observation: VNFaceObservation) -> Bool {
        let expectedBox = cameraModel?.faceExpectedBoundingBox
        return observation.confidence >= 0.8 && (
            expectedBox == nil || observation.boundingBox.intersects(expectedBox!)
        )
    }
}

extension Camera: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        
        if connection.isVideoOrientationSupported,
           let videoOrientation = videoOrientationFor(deviceOrientation) {
            connection.videoOrientation = videoOrientation
        }

        /// Add the original camera view to the UI
        addToPreviewImageStream?(CIImage(cvPixelBuffer: pixelBuffer))
        
        /// Add the view to the network uploading stream
        // TODO: The face dection is broken, and currently we simply upload the entire view
        if shouldDetectFace {
//            detectFaceAndAddToFaceStream(pixelBuffer)
            addToUploadStream?(pixelBuffer)
        }
    }
    
    private func detectFaceAndAddToUploadStream(_ pixelBuffer: CVPixelBuffer) {
        // MARK: Facial Recognition & Tracking
        /// - Tag: Process Images: Detection or Tracking
        var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
        
        let cameraIntrinsicData = CMGetAttachment(pixelBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil)
        if cameraIntrinsicData != nil {
            requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsicData
        }
        
        let exifOrientation = self.exifOrientationFor(deviceOrientation)
        
        /// - Tag: Detection
        /// If there is currently no tracking requests,
        /// it means the detection request is not executed so no faces are found are tracked
        guard let requests = self.trackingRequests, !requests.isEmpty else {
            /// No tracking object detected, so perform initial detection
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                            orientation: exifOrientation,
                                                            options: requestHandlerOptions)
            
            do {
                guard let detectRequests = self.detectionRequests else { return }
                try imageRequestHandler.perform(detectRequests)
            } catch let error as NSError {
                NSLog("Failed to perform FaceRectangleRequest: %@", error)
            }
            return
        }
        
        /// - Tag: Tracking
        do {
            try self.sequenceRequestHandler.perform(requests,
                                                    on: pixelBuffer,
                                                    orientation: exifOrientation)
        } catch let error as NSError {
            NSLog("Failed to perform SequenceRequest: %@", error)
        }
        
        var newTrackingRequests = [VNTrackObjectRequest]()
        var faceBounds = [CGRect]()
        for trackingRequest in requests {
            
            guard let results = trackingRequest.results else {
                return
            }
            
            guard let observation = results[0] as? VNDetectedObjectObservation else {
                return
            }
            
            /// Record the tracked face bounds
//            let percentageBound = observation.boundingBox
//            //            let deviceScaleBound = self.getFaceBound(observation)
//            faceBounds.append(percentageBound)
//            if let faceCroppedImage = self.getFaceCroppedImage(pixelBuffer: pixelBuffer, percentageBound: percentageBound) {
//                var outputPixelBuffer: CVPixelBuffer?
//                CVPixelBufferCreate(
//                    kCFAllocatorDefault,
//                    240,
//                    240,
//                    CVPixelBufferGetPixelFormatType(pixelBuffer),
//                    nil,
//                    &outputPixelBuffer)
//                facePixelBufferRenderContext.render(faceCroppedImage, to: outputPixelBuffer!)
//                addToFaceStream?(outputPixelBuffer!)
//            }
            addToUploadStream?(pixelBuffer)
            
            /// Setup the next round of tracking.
            if !trackingRequest.isLastFrame {
                if observation.confidence > 0.3 {
                    trackingRequest.inputObservation = observation
                } else {
                    trackingRequest.isLastFrame = true
                }
                newTrackingRequests.append(trackingRequest)
            }
        }
        self.trackingRequests = newTrackingRequests
        addToPreviewFaceBoundsStream?(faceBounds)
    }
    
    private func getFaceBound(_ faceTrackingObservation: VNDetectedObjectObservation) -> CGRect {
        let deviceResolution = self.deviceResolution
        let faceBound = VNImageRectForNormalizedRect(faceTrackingObservation.boundingBox, Int(deviceResolution.width), Int(deviceResolution.height))
        return faceBound
    }
    
    /// This is the CIImage version of image cropping.
    /// It is said to have better performance, but the coordinate system is really annoying and misalign with the documentation.
    private func getFaceCroppedImage(pixelBuffer: CVPixelBuffer, percentageBound bound: CGRect) -> CIImage? {
        var ciImage = CIImage(cvImageBuffer: pixelBuffer)

        /// Stretch the bounding box to 1:1
        // let imageWidth = CVPixelBufferGetWidth(pixelBuffer)
        // let imageWidth = CVPixelBufferGetHeight(pixelBuffer)
        let imageWidth = ciImage.extent.width
        let imageHeight = ciImage.extent.height
        var x = bound.origin.x * imageWidth
        let width = bound.size.width * imageWidth
        var y = bound.origin.y * imageHeight
        let height = bound.size.height * imageHeight
        var size: CGFloat
        if width > height {
            size = width
            y = y - (width - height) / 2
            y = min(max(y, 0), imageHeight - size)
        } else {
            size = height
            x = x - (height - width) / 2
            x = min(max(x, 0), imageWidth - size)
        }

        /// Crop
        /// I want to sincerely fuck Apple because the document says
        /// both `VNDetectedObjectObservation.boundingBox` and `CIImage` have origins at the bottom-left.
        /// So why does `CIImage.cropped` flip the y-axis, huh?
        /// Why don't you write that information in the documentation,
        /// or at least an example that demonstratesthe coordinate system?
        /// Hate your SDK, hate your attitude. The hardest modern programming language I have ever used.
        let fuckAppleWhyIsMyYAxisInverted = (imageHeight - (y + height / 2)) - height / 2
        ciImage = ciImage.cropped(to: CGRect(x: x, y: fuckAppleWhyIsMyYAxisInverted, width: size, height: size))
        
        /// Resize
        let filter = CIFilter(name: "CILanczosScaleTransform")!
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(240 / width, forKey: kCIInputScaleKey)
        guard let image = filter.outputImage else { return nil }
        
        /// Fix cropping
        /// https://stackoverflow.com/a/73333116/5735654
        let transformFilter = CIFilter(name: "CIAffineTransform")!
        let translate = CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY)
        let value = NSValue(cgAffineTransform: translate)
        transformFilter.setValue(value, forKey: kCIInputTransformKey)
        transformFilter.setValue(image, forKey: kCIInputImageKey)
        let newImage = transformFilter.outputImage

//        logger.info("Original extent: origin \(ciImage.extent.origin.debugDescription), size \(ciImage.extent.size.debugDescription), cropped extent: origin \(newImage?.extent.origin.debugDescription ?? "?"), size \(newImage?.extent.size.debugDescription ?? "?")")
        return newImage
    }
    
    /// This is the CGImage version of the image cropping.
    /// It is said to introduce extra overhead by CGImage, but the API and coordinate system is much friendlier.
    private func getFaceCroppedImageUsingCGImage(pixelBuffer: CVPixelBuffer, percentageBound bound: CGRect) -> CGImage? {
        let ciImage = CIImage(cvImageBuffer: pixelBuffer)

        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        let croppingRect = CGRect(
            x: bound.origin.x * imageWidth,
            y: bound.origin.y * imageHeight,
            width: bound.size.width * imageWidth,
            height: bound.size.height * imageHeight
        )

        let croppedImage = cgImage.cropping(to: croppingRect)
        return croppedImage
    }
}

extension AVCaptureDevice: Identifiable {
    public var id: String {
        get {
            self.uniqueID
        }
    }
}

fileprivate extension UIScreen {

    var orientation: UIDeviceOrientation {
        let point = coordinateSpace.convert(CGPoint.zero, to: fixedCoordinateSpace)
        if point == CGPoint.zero {
            return .portrait
        } else if point.x != 0 && point.y != 0 {
            return .portraitUpsideDown
        } else if point.x == 0 && point.y != 0 {
            return .landscapeRight //.landscapeLeft
        } else if point.x != 0 && point.y == 0 {
            return .landscapeLeft //.landscapeRight
        } else {
            return .unknown
        }
    }
}
