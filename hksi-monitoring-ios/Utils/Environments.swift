//
//  Environments.swift
//  HKSI Booth
//
//  Created by 黄泽宇 on 19/6/2024.
//

import Foundation

func isInPreview() -> Bool {
  return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
}
