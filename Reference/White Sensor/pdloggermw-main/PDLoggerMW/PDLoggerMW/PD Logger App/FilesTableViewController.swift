//
//  FilesTableViewController.swift
//  PDLoggerMW
//
//  Created by Jiun Shiah Low on 18/11/24.
//

import UIKit

class FilesTableViewController: UITableViewController, UISearchBarDelegate
{
    @IBOutlet var searchBar: UISearchBar!
    var folders: [URL] = []
    var currentFolders: [URL] = []
    let fileManager = Settings.shared.fileManager
    var filePath:URL!
    var fileNaviCount = 0
    var isSelectBtnPressed:Bool = false
    var selectedFiles: [URL] = []
    
    @IBOutlet weak var selectButton: UIBarButtonItem!
    @IBOutlet weak var deleteButton: UIBarButtonItem!
    
    override func viewDidLoad() 
    {
        super.viewDidLoad()
        searchBar.delegate = self
        
        selectButton.title = "Select"
        deleteButton.isEnabled = false
        deleteButton.tintColor = .clear
    }
    
    override func viewDidAppear(_ animated: Bool) 
    {
        refreshFolder()
    }
    
    // clear selection, search bar, folder list and reload table
    func refreshFolder()
    {
        selectedFiles = []

        do {
            if fileNaviCount == 0 {
                folders = try fileManager.mainDirectoryFiles()
            }
            else {
                folders = try fileManager.subDirectoryFiles(path: filePath)
            }
        }
        catch {
            Utils.log("Error at fileNaviCount \(fileNaviCount): \(error)")
        }
        folders.sort {
            $0.lastPathComponent < $1.lastPathComponent
        }

        // apply search filter after folders array refreshed
        searchBar(searchBar, textDidChange: searchBar.text ?? "")
    }
    
    // delegate for searchBar on text change
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String)
    {
        if searchText.isEmpty {
            currentFolders = folders
        }
        else {
            currentFolders = folders.filter{$0.lastPathComponent.localizedCaseInsensitiveContains(searchText)}
        }
        self.tableView.reloadData()
    }
    
    // MARK: - Select
    //Select <-> Cancel
    @IBAction func selectFilesButtonTapped(_ sender: Any) 
    {
        isSelectBtnPressed = !isSelectBtnPressed
        if isSelectBtnPressed {
            selectButton.title = "Cancel"
            deleteButton.isEnabled = true
            deleteButton.tintColor = .black
        }
        else  { // not select mode
            selectedFiles = []
            selectButton.title = "Select"
            deleteButton.isEnabled = false
            deleteButton.tintColor = .clear
        }
        
        self.tableView.setEditing(isSelectBtnPressed, animated: true)
    }
    
    func hasSelectedFiles(otherwise:String) -> Bool
    {
        if selectedFiles.isEmpty {
            Utils.alert(self, title: "Selection", message: otherwise)
            return false
        }
        return true
    }
    
    // MARK: - Delete
    @IBAction func deleteButtonTapped(_ sender: Any) {
        if hasSelectedFiles(otherwise: "Please select at least one to delete") {
            // Create the actions
            let yesAction = UIAlertAction(title: "Yes", style: .default) { _ in
                Utils.alert(self, title: "Deleting files...\n", message: "Please Wait\n\n\n", configure: { alertController in
                    let progressView = UIProgressView(frame: CGRect(x: 10, y: 100, width: 250, height: 0))
                    progressView.tintColor = UIColor.blue
                    progressView.progressViewStyle = .bar
                    progressView.tag = 1
                    alertController.view.addSubview(progressView)
                }, completion: {alertController in
                    let progressView = alertController.view.viewWithTag(1) as! UIProgressView
                    for i in 0..<self.selectedFiles.count {
                        progressView.progress = Float(i+1) / Float(self.selectedFiles.count)
                        progressView.setNeedsDisplay()
                        
                        do {
                            try self.fileManager.deleteA_file(path: self.selectedFiles[i])
                            Utils.log("File \(i) delete successful!")
                        }
                        catch {
                            Utils.log("Error deleting file \(i): \(error)")
                        }
                    }
                    // clear selection and search bar on new view
                    self.dismiss(animated: true) {
                        // clear select mode
                        self.selectFilesButtonTapped(sender)
                        self.refreshFolder()
                    }
                })
            }
            
            let noAction = UIAlertAction(title: "No", style: .default)
            Utils.alert(self, title: "Delete File?", message: nil, actions: [yesAction, noAction])
        }
    }
    
    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        currentFolders.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "fileTableItem", for: indexPath)
        let cellItem = currentFolders[indexPath.row]  // URL of file in current cell
        
        var fileSizeText = ""
        if let fileSize = try? fileManager.attributesOfItem(atPath: cellItem.path)[FileAttributeKey.size] as? UInt64 {
            fileSizeText = "   (\(Utils.sizeFormat(bytes: fileSize)))"
        }
        
        // Configure the cell...
        switch cellItem.pathExtension {
        case "csv":
            cell.imageView?.image = #imageLiteral(resourceName: "csv-icon")
        case "mov","mp4":
            cell.imageView?.image = #imageLiteral(resourceName: "videos-icon")
        default:
            cell.imageView?.image = #imageLiteral(resourceName: "folder-icon")
            fileSizeText = ""  // do not show size for folder
        }
        
        cell.textLabel?.text = cellItem.deletingPathExtension().lastPathComponent + fileSizeText
        cell.selectionStyle = .blue
        
        cell.backgroundColor = (indexPath.row % 2 == 0) ? .csvRow1.withAlphaComponent(0.5) : .csvRow2
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        if isSelectBtnPressed {
            selectedFiles.append(currentFolders[indexPath.row])
        }
        else {
            processSelection(currentFolders[indexPath.row])
        }
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath)
    {
        if isSelectBtnPressed {
            selectedFiles = selectedFiles.filter{ $0 != currentFolders[indexPath.row] }
        }
    }
    
    func processSelection(_ path:URL)
    {
        let thisPathExt = path.pathExtension
        
        selectedFiles = []
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        if path.hasDirectoryPath {
            if let vc = storyboard.instantiateViewController(withIdentifier: "FileMan") as? FilesTableViewController {
                vc.filePath = path
                vc.fileNaviCount = fileNaviCount + 1
                self.navigationController?.pushViewController(vc, animated: false)
            }
        }
        else if thisPathExt == "mov" || thisPathExt == "mp4" {
            if let vc = storyboard.instantiateViewController(withIdentifier: "VideoVc") as? VideoPlayerViewController {
                vc.videoFilePath = path
                self.navigationController?.pushViewController(vc, animated: false)
            }
        }
        else if thisPathExt == "csv" {
            if let vc = storyboard.instantiateViewController(withIdentifier: "CsvVc") as? CsvViewController {
                vc.filePath = path
                self.navigationController?.pushViewController(vc, animated: false)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle
    {
        UITableViewCell.EditingStyle(rawValue: 3)!
    }

}

