//
//  CameraViewController.swift
//  DDCameraPreview
//
//  Created by 姜维东 on 2021/2/5.
//

import UIKit
import AVFoundation

typealias Callback = (String) -> Void

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
//        cameraView.frame = view.bounds
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        cameraView = DDCameraPreview(delegate: self)
        view.addSubview(cameraView)
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var shouldAutorotate: Bool {
        if UIApplication.shared.statusBarOrientation == .landscapeLeft || UIApplication.shared.statusBarOrientation == .landscapeRight {
            return true
        }
        return false
    }
    
    func cameraPreviewClickOk(image: UIImage?) {
        if image != nil {
            UIImageWriteToSavedPhotosAlbum(image!, self, #selector(saveImage(image:didFinishSavingWithError:contextInfo:)), nil)
            writeImageToPath(data: image?.jpegData(compressionQuality: 1))
            imageCallBack?(getFilePath())
            dismiss(animated: true, completion: nil)
        }
    }
    
    func cameraPreviewClickCancel() {
        
    }
    
    func cameraPreviewClickDismiss() {
        dismiss(animated: true, completion: nil)
    }
    
    //MARK: private method
    private func getSavePath() -> String {
        var documentPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
        if documentPath == nil {
            documentPath = NSHomeDirectory() + "/Documents"
        }
        return documentPath! + "/preview/avatar"
    }
    
    private func getFilePath() -> String {
        return getSavePath() + "/avatar.jpg"
    }
    
    private func writeImageToPath(data: Data?) {
        let savePath = getSavePath()
        do {
            try FileManager.default.createDirectory(atPath: savePath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("创建目录失败")
        }
        let ret = FileManager.default.createFile(atPath: getFilePath(), contents: data, attributes: nil)
        if ret {
            print("写入成功")
        } else {
            print("写入失败")
        }
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
