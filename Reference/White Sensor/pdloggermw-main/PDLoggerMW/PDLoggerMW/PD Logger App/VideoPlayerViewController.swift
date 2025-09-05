//
//  VideoPlayerViewController.swift
//  PDLoggerMW
//
//  Created by Jiun Shiah Low on 18/11/24.
//

import UIKit

class VideoPlayerViewController: UIViewController {
    
    var videoFilePath:URL!
    @IBOutlet var videoPlayerCustom: VideoPlayer!
    
    
    override func viewDidLoad()
    {
        super.viewDidLoad()

        Utils.log("videoFilePath: \(String(describing: videoFilePath))")
        videoPlayerCustom.setupAvPlayer(filePath: videoFilePath)
        videoPlayerCustom.playVideo()
    }

}
