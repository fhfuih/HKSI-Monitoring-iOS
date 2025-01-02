import AVFoundation
import SwiftUI
import os.log

@Observable
final class CameraModel {
    /// Keep a record of other models used by this one
    @ObservationIgnored
    weak var webRTCModel: WebRTCModel?

    /// These variables are for user's settings and preference
    var availableCaptureDevices = [AVCaptureDevice]()
    var selectedCaptureDevice: AVCaptureDevice? {
        didSet {
            guard let selectedCaptureDevice else { return }
            guard selectedCaptureDevice != oldValue else { return }

            self.preferredCameraID = selectedCaptureDevice.uniqueID /// Save user preference

            camera.captureDevice = selectedCaptureDevice /// Tell camera to update internally

//            self.availableFormats = selectedCaptureDevice.formats /// Set the 2nd list's value
//            
//            self.setSelectedFormat() /// Set the defalt selection of the 2nd list
        }
    }

    /// This feature is not implemented
    /// Currently, we use the automatically set activeFormat
//    var availableFormats = [AVCaptureDevice.Format]()
//    var selectedFormat: AVCaptureDevice.Format? {
//        didSet {
//            guard let selectedFormat else { return }
//            guard selectedFormat != oldValue else { return }
//
//            self.preferredCameraFormatHash = selectedFormat.hash /// Set user preference
//        }
//    }

    /// These variables are properties of Camera's internal properties
    var shouldDetectFace: Bool {
        get {
            camera.shouldDetectFace
        }
        set {
            camera.shouldDetectFace = newValue
        }
    }
    
    /// These variables will be reversely set in Camera's internal
    var ratio = 4.0 / 3.0
    var deviceResolution = CGSize()
    
    /// These constants describe the outline of the suggested face/head placement (in percentage)
    let facePercentageAgainstHeight = 0.8
    let faceExpectedBoundingBox = CGRect(x: (1-0.3)/2, y: (1-0.5)/2, width: 0.3, height: 0.5)
    
    /// These variables will be continuously updated by the async Task below
    var cameraPreviewImage: Image?
    var cameraPreviewFaceBounds: [CGRect] = [CGRect]()
    
    /// If use `cameraDebugPreviewUploadingImage`, remember to also *comment* `@ObservationIgnored` as well.
    /// If not using it, remember to *uncomment* to boost performance
    @ObservationIgnored
    var cameraDebugPreviewUploadingImage: Image?
    
    /// These variables are the user's preferences (the "saved" settings)
    @ObservationIgnored
    @AppStorage("preferredCameraID")
    var preferredCameraID: String?
    
//    @ObservationIgnored
//    @AppStorage("preferredCameraFormatHash")
//    var preferredCameraFormatHash: Int?
    
    /// Internal variables
    @ObservationIgnored
    private let camera = Camera()
    
    @ObservationIgnored
    var isPhotosLoaded = false
    
    @ObservationIgnored
    private let ciContext = CIContext()
    
    init() {
        /// Prepare user preferences for capture devices
        getAvailableCaptureDevices()
        setSelectedCaptureDevice()

        /// Set reverse reference for potential hackings
        camera.cameraModel = self

        /// Bind camera preview stream to the view.
        /// This does NOT start the camera and add images to the stream.
        Task {
            await startCameraPreviewImageUpdate()
        }
        
        Task {
            await startCameraPreviewFaceBoundsUpdate()
        }
        
        Task {
            await startCameraViewUpload()
        }
        
//        Task {
//            await handleCameraPhotos()
//        }
    }
    
    func startCamera() async {
        await camera.start()
    }
    
    func stopCamera() {
        camera.stop()
    }

    private func startCameraPreviewImageUpdate() async {
        let imageStream = camera.previewImageStream.map { $0.image }

        for await image in imageStream {
            Task { @MainActor in
                cameraPreviewImage = image
            }
        }
    }
    
    private func startCameraPreviewFaceBoundsUpdate() async {
        let faceBoundsStream = camera.previewFaceBoundsStream
        
        for await bounds in faceBoundsStream {
            Task { @MainActor in
                cameraPreviewFaceBounds = bounds
            }
        }
    }
    
    private func startCameraViewUpload() async {
        let pixelBufferToUploadStream = camera.pixelBufferToUploadStream
        
        for await pixelBuffer in pixelBufferToUploadStream {
            webRTCModel?.didOutput(pixelBuffer)
            cameraDebugPreviewUploadingImage = CIImage(cvPixelBuffer: pixelBuffer).image
        }
    }
    
    private func getAvailableCaptureDevices() {
        let allCaptureDevices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInDualWideCamera,
                .builtInDualCamera,
                .builtInWideAngleCamera,
                .builtInUltraWideCamera,
                .builtInTelephotoCamera,
                .builtInTrueDepthCamera
            ],
            mediaType: .video,
            position: .unspecified
        ).devices.sorted { d1, d2 in
            return d1.position.rawValue > d2.position.rawValue || d1.deviceType.rawValue < d2.deviceType.rawValue
        }
        
        availableCaptureDevices = allCaptureDevices
            .filter( { $0.isConnected } )
            .filter( { !$0.isSuspended } )
    }
    
    private func setSelectedCaptureDevice() {
        if let preferredCameraID, let preferredDevice = AVCaptureDevice(uniqueID: preferredCameraID) {
            selectedCaptureDevice = preferredDevice
            logger.debug("Set the camera device to preferred device \(preferredDevice.localizedName)")
        } else {
            selectedCaptureDevice = availableCaptureDevices.first ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            if selectedCaptureDevice != nil {
                preferredCameraID = selectedCaptureDevice!.uniqueID
            }
            logger.debug("Set the camera device to default device \(self.selectedCaptureDevice?.localizedName ?? "null")")
        }
    }
    
//    private func setSelectedFormat() {
//        let effectivePrefrredFormatHash = preferredCameraFormatHash ?? availableFormats[0].hash
//        for format in availableFormats {
//            if format.hash == effectivePrefrredFormatHash {
//                selectedFormat = format
//            }
//        }
//        if selectedFormat == nil {
//            selectedFormat = availableFormats[0]
//        }
//        logger.debug("Set the camera format to \(self.selectedFormat)")
//    }
    
    private func unpackPhoto(_ photo: AVCapturePhoto) -> PhotoData? {
        guard let imageData = photo.fileDataRepresentation() else { return nil }

        guard let previewCGImage = photo.previewCGImageRepresentation(),
           let metadataOrientation = photo.metadata[String(kCGImagePropertyOrientation)] as? UInt32,
              let cgImageOrientation = CGImagePropertyOrientation(rawValue: metadataOrientation) else { return nil }
        let imageOrientation = Image.Orientation(cgImageOrientation)
        let thumbnailImage = Image(decorative: previewCGImage, scale: 1, orientation: imageOrientation)
        
        let photoDimensions = photo.resolvedSettings.photoDimensions
        let imageSize = (width: Int(photoDimensions.width), height: Int(photoDimensions.height))
        let previewDimensions = photo.resolvedSettings.previewDimensions
        let thumbnailSize = (width: Int(previewDimensions.width), height: Int(previewDimensions.height))
        
        return PhotoData(thumbnailImage: thumbnailImage, thumbnailSize: thumbnailSize, imageData: imageData, imageSize: imageSize)
    }
}

fileprivate struct PhotoData {
    var thumbnailImage: Image
    var thumbnailSize: (width: Int, height: Int)
    var imageData: Data
    var imageSize: (width: Int, height: Int)
}

fileprivate extension CIImage {
    var image: Image? {
        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(self, from: self.extent) else { return nil }
        return Image(decorative: cgImage, scale: 1, orientation: .up)
    }
}

fileprivate extension Image.Orientation {
    init(_ cgImageOrientation: CGImagePropertyOrientation) {
        switch cgImageOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        }
    }
}
