//
//  RouteModel.swift
//  HKSI Booth
//
//  Created by 黄泽宇 on 7/7/2024.
//

import Observation

@Observable
class RouteModel {
    var paths = [Route]()
    
    func push(_ r: Route) {
        paths.append(r)
    }
    
    func pop() {
        paths.removeLast()
    }
    
    func pushReplaceTop(_ r: Route) {
        paths[paths.count - 1] = r
//        paths.append(r)
//        paths.remove(at: paths.count - 2)
    }
    
    func pushReplace(_ r: Route) {
        paths = [r]
    }
}

enum Route {
    case welcome /// The master view does not need to be presented here
    case settings
    case scanning
    case result
    case questionnaire
}
