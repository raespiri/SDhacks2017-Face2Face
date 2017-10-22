//
//  CollectionViewController.swift
//  SDHacks Project
//
//  Created by Toshitaka on 10/21/17.
//  Copyright © 2017 Toshitaka. All rights reserved.
//

import Foundation
import UIKit
import Photos

private let reuseIdentifier = "Cell"

class CollectionViewController: UICollectionViewController,UICollectionViewDelegateFlowLayout {

    var videoArray = [NSData]()
    var videoURLArrray = [NSURL]()
    var screenSize:CGRect!
    var screenWidth:CGFloat!
    var selectedVideo:NSURL!

    override func viewDidLoad() {
        grabVideos()
        screenSize = UIScreen.main.bounds
        screenWidth = screenSize.width
        
        let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: screenWidth/3, height: screenWidth/3)
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        collectionView!.collectionViewLayout = layout
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: {
            self.collectionView?.reloadData()
        })
    }
    
    func grabVideos() {

        let imgManager = PHImageManager.default()

        let fetchOption = PHFetchOptions()
        fetchOption.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        if let fetchResult:PHFetchResult = PHAsset.fetchAssets(with: .video, options: fetchOption) {
            if fetchResult.count > 0 {
                for i in 0...fetchResult.count-1 {
                    imgManager.requestAVAsset(forVideo: fetchResult.object(at: i) as PHAsset, options: PHVideoRequestOptions(), resultHandler:
                        {(avAsset, audioMix, info) -> Void in
                            if let asset = avAsset as? AVURLAsset {
                                let videoData = NSData(contentsOf: asset.url)
                                self.videoArray.append(videoData!)
                                self.videoURLArrray.append(asset.url as NSURL)
                                
//                                let duration : CMTime = asset.duration
//                                let durationInSecond = CMTimeGetSeconds(duration)
//                                print(durationInSecond)
                            }
                        })
                }
                
                self.collectionView?.reloadData()
            }
            else {
                print("Error: No Videos Found")
                self.collectionView?.reloadData()
            }
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return videoURLArrray.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath)
        var imageView = cell.viewWithTag(1) as! UIImageView
        imageView.image = generateThumnail(url: videoURLArrray[indexPath.row])
        
        return cell
    }
    
    func generateThumnail(url : NSURL) -> UIImage?{
        let asset: AVAsset = AVAsset(url: url as URL)
        let assetImgGenerate : AVAssetImageGenerator = AVAssetImageGenerator(asset: asset)
        assetImgGenerate.appliesPreferredTrackTransform = true
        let time        : CMTime = CMTimeMake(1, 30)
        let img         : CGImage
        do {
            try img = assetImgGenerate.copyCGImage(at: time, actualTime: nil)
            let frameImg: UIImage = UIImage(cgImage: img)
            return frameImg
        } catch {
            
        }
        return nil
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Create a variable that you want to send based on the destination view controller
        // You can get a reference to the data by using indexPath shown below
        print("running")
        
        selectedVideo = videoURLArrray[indexPath.row]
        performSegue(withIdentifier: "playVideo", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        let destinationVC = segue.destination as! playerController
        destinationVC.programVar = selectedVideo
    }
}
