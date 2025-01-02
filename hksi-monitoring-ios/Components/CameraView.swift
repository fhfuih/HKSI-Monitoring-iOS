import SwiftUI

struct CameraView: View {
    @Environment(CameraModel.self) var cameraModel: CameraModel

    private static let barHeightFactor = 0.15
    
    var body: some View {
        @Bindable var cameraModel = cameraModel
        ZStack {
            ViewfinderView(image: $cameraModel.cameraPreviewImage)
                .background(.black)
            
            GeometryReader { geometry in
                let height = geometry.size.height * cameraModel.facePercentageAgainstHeight
                Image("head")
                    .resizable()
                    .scaledToFit()
                    .frame(height: height)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            
            /// A test view to inspect the actual rectangle of expected face area
            GeometryReader { geometry in
                let x = geometry.size.width * cameraModel.faceExpectedBoundingBox.midX
                let y = geometry.size.height * cameraModel.faceExpectedBoundingBox.midY
                let width = geometry.size.width * cameraModel.faceExpectedBoundingBox.width
                let height = geometry.size.height * cameraModel.faceExpectedBoundingBox.height
                Rectangle()
                    .frame(width: width, height: height)
                    .foregroundColor(.red.opacity(0))
                    .border(.red)
                    .position(x: x, y: y)
            }
            
            FaceBoundsView()
        }
        .aspectRatio(cameraModel.ratio, contentMode: .fit)
        .onAppear {
            guard !isInPreview() else { return }

            Task {
                await cameraModel.startCamera()
            }
        }
        .onDisappear {
            guard !isInPreview() else { return }
            
            cameraModel.stopCamera()
            
            /// Remove the last frame from the last user. Prevent the next user from seeing it during page transition
            cameraModel.cameraPreviewImage = nil
            cameraModel.cameraPreviewFaceBounds = []
            cameraModel.cameraDebugPreviewUploadingImage = nil
        }
    }
}

struct FaceBoundsView: View {
    @Environment(CameraModel.self) var cameraModel: CameraModel
    
    var body: some View {
        GeometryReader { geom in
            Canvas { context, size in
                for bound in cameraModel.cameraPreviewFaceBounds {
                    let effectiveBound = CGRect(
                        x: bound.origin.x * geom.size.width,
                        y: bound.origin.y * geom.size.height,
                        width: bound.width * geom.size.width,
                        height: bound.height * geom.size.height)
                    context.stroke(Path(effectiveBound), with: .color(.green), lineWidth: 2)
                }
            }
            .frame(width: geom.size.width, height: geom.size.height)
        }
    }
}

/// If uncomment this view,
/// remember to also remove a specific `@ObservationIgnored` in `CameraModel.swift`
//struct FrameToUploadView: View {
//    @Environment(CameraModel.self) var cameraModel: CameraModel
//    
//    private static let barHeightFactor = 0.15
//    
//    var body: some View {
//        @Bindable var cameraModel = cameraModel
//        ZStack {
//            ViewfinderView(image: $cameraModel.cameraDebugPreviewUploadingImage)
//                .background(.black)
//                .border(Color.yellow, width: 3)
//        }
//        .aspectRatio(4 / 3, contentMode: .fit)
//        .task {
//            guard !isInPreview() else {
//                return
//            }
//            
//            await cameraModel.startCamera()
//        }
//    }
//}
