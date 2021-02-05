//
//  CameraViewController.swift
//  DDCameraPreview
//
//  Created by 姜维东 on 2021/2/5.
//

import UIKit
import AVFoundation

typealias Callback = (UIImage) -> Void

class CameraViewController: UIViewController, DDCameraPreviewDelegate {
    
    open var imageCallBack: Callback?
    private var isAuthorized = true
    
    var cameraView: DDCameraPreview!
    
    //MARK: life cycle
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        cameraView.frame = view.bounds
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        cameraView = DDCameraPreview(frame: view.bounds)
        cameraView.delegate = self
        view.addSubview(cameraView)
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    
    func cameraPreviewClickOk(image: UIImage?) {
        if image != nil {
            UIImageWriteToSavedPhotosAlbum(image!, self, #selector(saveImage(image:didFinishSavingWithError:contextInfo:)), nil)
            imageCallBack?(image!)
            dismiss(animated: true, completion: nil)
        }
    }
    
    func cameraPreviewClickCancel() {
        
    }
    
    func cameraPreviewClickDismiss() {
        dismiss(animated: true, completion: nil)
    }
    
    //MARK: request access
    private func requestAccess() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = false
            AVCaptureDevice.requestAccess(for: .video) { [weak self](granted) in
                self?.isAuthorized = granted
            }
        default:
            isAuthorized = false
        }
    }
    
    //MARK: save image
    @objc private func saveImage(image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: AnyObject) {
        if error != nil {
            //            print("保存失败")
        } else {
            //            print("保存成功")
        }
    }
}
