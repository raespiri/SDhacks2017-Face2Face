//
//  playerContorller.swift
//  SDHacks Project
//
//  Created by Toshitaka on 10/21/17.
//  Copyright © 2017 Toshitaka. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation

class playerController: AVPlayerViewController {
    
    var programVar:NSURL!
    
    override func viewDidLoad() {
        let videoURL = programVar
        let player = AVPlayer(url: videoURL! as URL)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        self.present(playerViewController, animated: true) {
            playerViewController.player!.play()
        }
    }
}
