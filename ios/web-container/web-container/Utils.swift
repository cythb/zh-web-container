//
//  Utils.swift
//  web-container
//
//  Created by ihugo on 2021/1/14.
//

import Foundation

// Get user's documents directory path
func getDocumentDirectoryPath() -> URL {
    let arrayPaths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    let docDirectoryPath = arrayPaths[0]
    return docDirectoryPath
}

// Get user's cache directory path
func getCacheDirectoryPath() -> URL {
    let arrayPaths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
    let cacheDirectoryPath = arrayPaths[0]
    return cacheDirectoryPath
}

// Get user's temp directory path
func getTempDirectoryPath() -> URL {
    let tempDirectoryPath = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    return tempDirectoryPath
}
