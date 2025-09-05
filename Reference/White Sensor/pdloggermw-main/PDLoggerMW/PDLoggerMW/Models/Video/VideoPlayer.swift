//
//  VideoPlayer.swift
//  PDLoggerMW
//
//  Created by Jiun Shiah Low on 18/11/24.
//

import AVKit

class VideoPlayer: UIView
{
    var avPlayerController:AVPlayerViewController!
    var avPlayer:AVPlayer!
    
    func setupAvPlayer(filePath:URL)
    {
        avPlayer = AVPlayer(url: filePath)
        avPlayerController = AVPlayerViewController()
        avPlayerController.player = avPlayer
        avPlayerController.view.frame = self.bounds
        addSubview(avPlayerController.view)
    }
    
    func playVideo()
    {
        avPlayerController.player?.play()
    }

}
