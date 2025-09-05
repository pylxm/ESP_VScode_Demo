//
//  FilesManager.swift
//  PDLoggerMW
//
//  Created by Jiun Shiah Low on 14/11/24.
//

import Foundation

class FilesManager: FileManager
{
    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    /// create folder
    /// - parameter path: folder name
    func createFolder(path:String)
    {
        do {
            try createDirectory(atPath: path, withIntermediateDirectories: true)
        }
        catch {
            Utils.log("FilesManager.createFolder error: \(error.localizedDescription)");
        }
    }
    
    /// get list of files in the root directory of the app storage
    /// - returns:  array of file URLs
    func mainDirectoryFiles () throws -> [URL]
    {
        try subDirectoryFiles(path: documentsDirectory)
    }
    
    /// get list files in the directory
    /// - parameter path: directory name
    /// - returns: array of file URLs
    func subDirectoryFiles(path:URL) throws -> [URL]
    {
        try contentsOfDirectory(at: path.deletingPathExtension(), includingPropertiesForKeys: nil)
    }
    
    /// get all files starting from path downwards recursively
    /// - parameter path: directory name
    /// - returns: array of file URLs
    func getFiles(path:URL) throws -> [URL]
    {
        var fileList:[URL] = []
        if path.hasDirectoryPath {
            for subPath in try subDirectoryFiles(path: path) {
                fileList += try getFiles(path: subPath)
            }
        }
        else {
            fileList = [path]
        }
        return fileList
    }
    
    /// delete a file
    func deleteA_file(path:URL) throws
    {
        try removeItem(at: path)
    }
    
    /// generate URL of  file from folder path, name and suffix components
    ///  - parameter filePath: folder
    ///  - parameter withName: file name prefix
    ///  - parameter suffix: file name suffix
    func newURL(filePath:String, withName:String, suffix:String) -> URL
    {
        let targetURL = URL(fileURLWithPath: filePath).appendingPathComponent(withName + suffix)
        // Delete the file if exists
        if fileExists(atPath: targetURL.path) {
            do {
                try deleteA_file(path: targetURL)
            }
            catch {
                Utils.log("Unable to delete file, with error: \(error)")
            }
        }
        return targetURL
    }
    
    /// generate URL of  file from name assuming root folder in Settings
    ///  - parameter withName: file name
    func newURL(withName:String) -> URL
    {
        let targetURL = URL(fileURLWithPath: Settings.shared.fileRootPath).appendingPathComponent(withName)
        // Delete the file if exists
        if fileExists(atPath: targetURL.path) {
            do {
                try deleteA_file(path: targetURL)
            }
            catch {
                Utils.log("Unable to delete file, with error: \(error)")
            }
        }
        return targetURL
    }
}
