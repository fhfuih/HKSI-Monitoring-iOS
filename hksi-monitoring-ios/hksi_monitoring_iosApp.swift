//
//  hksi_monitoring_iosApp.swift
//  hksi-monitoring-ios
//
//  Created by 黄泽宇 on 26/7/2024.
//

import SwiftUI

//import SwiftData

/// Cannot see custom font even after configuring everything?
/// https://stackoverflow.com/a/75648998/5735654
//private func registerCustomFonts() {
//    let fonts = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil)
//    fonts?.forEach { url in
//        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
//    }
//}
/// No, actually the key is to write file name only in Info -> Fonts provided by application
/// Don't write path + file name
/// https://betterprogramming.pub/custom-fonts-in-swiftui-d529de69131d

@main
struct hksi_monitoring_iosApp: App {
  @Environment(\.scenePhase) private var scenePhase

  @State var routeModel = RouteModel()
  @State var webRTCModel = WebRTCModel()
  @State var qnScaleModel = QNScaleModel()
  @State var cameraModel = CameraModel()

  init() {
    cameraModel.webRTCModel = webRTCModel
  }

  var body: some Scene {
    //        let _ = registerCustomFonts()
    //        let _ = print(UIFont.familyNames.sorted().joined(separator: ", "))
    WindowGroup {
      NavigationStack(path: $routeModel.paths.animation(.linear(duration: 0))) {
        //                WebRTCTestScreen()
        WelcomeScreen()
          .navigationDestination(for: Route.self) { route in
            switch route {
            case .settings:
              SettingsScreen()
            case .scanning:
              ScanningScreen()
            case .result:
              ResultScreen()
            /// Please ignore the following warning
            @unknown default:
              Text("Internal error")
            }
          }
      }
      .environment(qnScaleModel)
      .environment(cameraModel)
      .environment(routeModel)
      .environment(webRTCModel)
      .onChange(of: scenePhase) { oldPhase, newPhase in
          qnScaleModel.checkBluetoothPermission()

          switch newPhase {
          case .background:
              print("SchenePhase: Background from \(oldPhase)")
          case .inactive:
              print("SchenePhase: Inactive from \(oldPhase)")
          case .active:
              print("SchenePhase: Active/Foreground from \(oldPhase)")
          @unknown default:
              print("SchenePhase: Unknown scene phase \(newPhase) from \(oldPhase)")
          }
      }
    }
  }
}
