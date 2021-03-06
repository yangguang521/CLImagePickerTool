//
//  CLVideoPlayView.swift
//  ImageDeal
//
//  Created by darren on 2017/8/3.
//  Copyright © 2017年 陈亮陈亮. All rights reserved.
//

import UIKit
import Photos
import PassKit


typealias singleVideoClickSureBtnClouse = ()->()


class CLVideoPlayView: UIView {

    var lastImageView = UIImageView()
    var originalFrame:CGRect!
    
    var asset: PHAsset?
    
    var playerItem: AVPlayerItem?
    var player: AVPlayer?
    
    var singleVideoClickSureBtn: singleVideoClickSureBtnClouse?
    
    lazy var bottomView: UIView = {
        let bottom = UIView.init(frame: CGRect(x: 0, y: KScreenHeight-44, width: KScreenWidth, height: 44))
        bottom.backgroundColor = UIColor(white: 0, alpha: 0.8)
        let btn = UIButton.init(frame: CGRect(x: KScreenWidth-80, y: 0, width: 80, height: 44))
        btn.setTitle("确定", for: .normal)
        btn.setTitleColor(mainColor, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        bottom.addSubview(btn)
        btn.addTarget(self, action: #selector(clickSureBtn), for: .touchUpInside)
        return bottom
    }()

    
    lazy var playBtn: UIButton = {
        let btn = UIButton.init(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        
        btn.setBackgroundImage(UIImage(named: "clvedioplaybtn", in: BundleUtil.getCurrentBundle(), compatibleWith: nil), for: .normal)
        btn.center = self.center
        return btn
    }()
    
    public static func setupAmplifyViewWithUITapGestureRecognizer(tap:UITapGestureRecognizer,superView:UIView,originImageAsset:PHAsset,isSingleChoose:Bool) -> CLVideoPlayView{
        
        let amplifyView = CLVideoPlayView.init(frame: (UIApplication.shared.keyWindow?.bounds)!)
        
        amplifyView.setupUIWithUITapGestureRecognizer(tap: tap, superView: superView,originImageAsset:originImageAsset,isSingleChoose:isSingleChoose)
        
        UIApplication.shared.keyWindow?.addSubview(amplifyView)
        
        return amplifyView
    }
    
    private func setupUIWithUITapGestureRecognizer(tap:UITapGestureRecognizer,superView:UIView,originImageAsset: PHAsset,isSingleChoose:Bool) {
        
        self.asset = originImageAsset
        
        self.frame = (UIApplication.shared.keyWindow?.bounds)!
        self.backgroundColor = UIColor.black
        
        self.addGestureRecognizer(UITapGestureRecognizer.init(target: self, action: #selector(self.clickBgView(tapBgView:))))
        
        // 点击的图片
        let picView = tap.view
        
        let imageView = UIImageView()
        imageView.image = (tap.view as! UIImageView).image
        imageView.frame = self.convert((picView?.frame)!, from: superView)
        self.addSubview(imageView)
        
        CLPickersTools.instence.getAssetOrigin(asset: originImageAsset) { (img, info) in
            if img != nil {
                imageView.image = img!
            }
        }
        
        self.lastImageView = imageView;
        
        self.originalFrame = imageView.frame
        
        UIView.animate(withDuration: 0.5, animations: { 
            var frame = imageView.frame
            frame.size.width = self.frame.size.width
            let bili = ((imageView.image?.size.height)! / (imageView.image?.size.width)!)
            frame.size.height = frame.size.width * bili
            frame.origin.x = 0
            frame.origin.y = (self.frame.size.height - frame.size.height) * 0.5
            imageView.frame = frame
        }) { (true:Bool) in
            // 播放按钮
            self.addSubview(self.playBtn)
            self.playBtn.addTarget(self, action: #selector(self.clickPlayBtn), for: .touchUpInside)
        }
        
        self.setupBottomView()
    }
    
    func clickPlayBtn() {
        self.playBtn.isHidden = true
        
        if self.asset == nil {
            return
        }
        let manager = PHImageManager.default()
        let videoRequestOptions = PHVideoRequestOptions()
        videoRequestOptions.deliveryMode = .automatic
        videoRequestOptions.version = .current
        videoRequestOptions.isNetworkAccessAllowed = true
        
        videoRequestOptions.progressHandler = {
        (progress, error, stop, info) in
    
             DispatchQueue.main.async(execute: {
                print(progress, info ?? "0000")
            })
        }

        PopViewUtil.share.showLoading()
        manager.requestPlayerItem(forVideo: self.asset!, options: videoRequestOptions) { (playItem, info) in
            
            DispatchQueue.main.async(execute: {
                self.removeObserver()
                
                self.playerItem = playItem
                self.player = AVPlayer(playerItem: self.playerItem)
                let playerLayer = AVPlayerLayer(player: self.player)
                playerLayer.frame = self.bounds
                playerLayer.videoGravity = AVLayerVideoGravityResizeAspect //视频填充模式
                self.lastImageView.layer.addSublayer(playerLayer)
                
                self.addObserver()
            })
        }
    }
    
    func addObserver(){
        
        //为AVPlayerItem添加status属性观察，得到资源准备好，开始播放视频
        playerItem?.addObserver(self, forKeyPath: "status", options: .new, context: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(CLVideoPlayView.playerItemDidReachEnd(notification:)), name: Notification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
    }
    
    func removeObserver() {
        if self.playerItem != nil {
            self.playerItem?.removeObserver(self, forKeyPath: "status")
            NotificationCenter.default.removeObserver(self, name:  Notification.Name.AVPlayerItemDidPlayToEndTime, object: self.playerItem)
        }

    }
    
    func playerItemDidReachEnd(notification:Notification) {
        self.playBtn.isHidden = false
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let object = object as? AVPlayerItem  else { return }
        guard let keyPath = keyPath else { return }
        if keyPath == "status"{
            if object.status == .readyToPlay{ //当资源准备好播放，那么开始播放视频
                self.player?.play()

                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()+1, execute: {
                    PopViewUtil.share.stopLoading()
                })
            }else if object.status == .failed || object.status == .unknown{
                print("播放出错")
                PopViewUtil.alert(message: "播放出错", leftTitle: "", rightTitle: "确定", leftHandler: {
                }, rightHandler: {
                })
                PopViewUtil.share.stopLoading()
            }
        }
    }
    
    deinit {
        self.removeObserver()
    }
    
    func clickBgView(tapBgView:UITapGestureRecognizer){
        
        UIView.animate(withDuration: 0.5, animations: {
            self.lastImageView.frame = self.originalFrame
            self.lastImageView.alpha = 0
            self.playBtn.alpha = 0
            tapBgView.view?.backgroundColor = UIColor.clear
            
        }) { (true:Bool) in
            tapBgView.view?.removeFromSuperview()
            
            self.removeFromSuperview()
            self.playBtn.removeFromSuperview()
        }
    }
    
    func setupBottomView() {
        self.addSubview(self.bottomView)
    }
    
    func clickSureBtn() {
        
        self.removeFromSuperview()
        
        if self.singleVideoClickSureBtn != nil {
            self.singleVideoClickSureBtn!()
        }
        
    }

}
