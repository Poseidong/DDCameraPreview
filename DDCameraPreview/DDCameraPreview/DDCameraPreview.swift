//
//  DDCameraPreview.swift
//  DDCameraPreview
//
//  Created by 姜维东 on 2021/2/5.
//

import UIKit
import AVFoundation
import CoreFoundation
import CoreGraphics

public protocol DDCameraPreviewDelegate: NSObjectProtocol {
    
    func cameraPreviewClickOk(image: UIImage?)
    
    func cameraPreviewClickCancel()
    
    func cameraPreviewClickDismiss()
}

class DDCameraPreview: UIView, AVCapturePhotoCaptureDelegate {
    
    var delegate: DDCameraPreviewDelegate?
    
    private let screenWidth = UIScreen.main.bounds.size.width
    private let screenHeight = UIScreen.main.bounds.size.height
    
    private var session: AVCaptureSession!
    private var device: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?
    private var imageOutput: AVCaptureOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoOrientation: AVCaptureVideoOrientation?
    
    private var path: UIBezierPath!
    private var fillPath: UIBezierPath!
    private var maskLayer: CAShapeLayer!
    private var borderLayer: CAShapeLayer!
    
    private var isAuthorized = true
    
    private var dataImage: UIImage?
    
    //MARK: life cycle
    override init(frame: CGRect) {
        super.init(frame: frame)
        requestAccess()
        initState()
        configureSession()
        setupCameraLayer()
        updateVideoOrientation()
        setupPathLayer()
        initUI()
        session.startRunning()
        
        NotificationCenter.default.addObserver(self, selector: #selector(onDeviceOrientationDidChange), name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
  
    //MARK: private method
    //MARK: init
    private func initUI() {
        self.addSubview(dismissBtn)
        self.addSubview(shotBtn)
        self.addSubview(okBtn)
        self.addSubview(cancelBtn)
    }
    
    private func initState() {
        session = AVCaptureSession()
        session.canSetSessionPreset(.high)
        device = AVCaptureDevice.default(for: .video)
    }
    
    //MARK: config
    private func configureSession() {
        if session == nil || !isAuthorized {
            return
        }
        session!.beginConfiguration()
        if let backCamera = backCamera() {
            do {
                try videoInput = AVCaptureDeviceInput(device: backCamera)
                if #available(iOS 10.0, *) {
                    let output = AVCapturePhotoOutput()
                    imageOutput = output
                } else {
                    let settings = [AVVideoCodecKey: AVVideoCodecJPEG, AVVideoQualityKey: 1] as [String : Any]
                    let output = AVCaptureStillImageOutput()
                    output.outputSettings = settings
                    imageOutput = output
                }
                if session!.canAddInput(videoInput!)  {
                    session!.addInput(videoInput!)
                }
                if session!.canAddOutput(imageOutput!) {
                    session!.addOutput(imageOutput!)
                }
                session!.commitConfiguration()
            } catch {
                
            }
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
    
    //MARK: get camera
    private func cameraWithPosition(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        var devices: [AVCaptureDevice]
        if #available(iOS 10.0, *) {
            let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified)
            devices = deviceDiscoverySession.devices
        } else {
            devices = AVCaptureDevice.devices(for: .video)
        }
        for captureDevice in devices {
            if captureDevice.position == position {
                return captureDevice
            }
        }
        return nil
    }
    
    private func frontCamera() -> AVCaptureDevice? {
        return cameraWithPosition(position: .front)
    }
    
    private func backCamera() -> AVCaptureDevice? {
        return cameraWithPosition(position: .back)
    }
    
    private func isLandscape() -> Bool {
        let statusBarOrientation = UIApplication.shared.statusBarOrientation
        return (statusBarOrientation == .landscapeLeft || statusBarOrientation == .landscapeRight)
    }
    
    //MARK: get image
    private func getImageFromPath(orgImage: UIImage) -> UIImage? {
        var scale = min(orgImage.size.width / screenWidth, orgImage.size.height / screenHeight)
        if isLandscape() {
            scale = min(orgImage.size.height / screenWidth, orgImage.size.height / screenHeight)
        }
        let orgWidth = path.bounds.width
        let orgHeight = path.bounds.height
        let width = orgWidth * scale
        let height = orgHeight * scale
        var x = path.bounds.origin.x * scale
        var y = path.bounds.origin.y * scale
        if isLandscape() {
            y = path.bounds.origin.x * scale
            x = path.bounds.origin.y * scale
        }
        let cropFrame = CGRect(x: x, y: y, width: width, height: height)
        
        guard let orgImageRef = orgImage.cgImage else {
            return nil
        }
        
        guard let cropImageRef = orgImageRef.cropping(to: cropFrame) else {
            return nil
        }
        
        var orientation = UIImage.Orientation.up
        if UIApplication.shared.statusBarOrientation == .landscapeLeft {
            orientation = .right
        } else if UIApplication.shared.statusBarOrientation == .landscapeRight {
            orientation = .left
        } else if UIApplication.shared.statusBarOrientation == .portraitUpsideDown {
            orientation = .down
        }
        return UIImage(cgImage: cropImageRef, scale: orgImage.scale, orientation: orientation)
    }
    
    private func getImage() {
        guard let connection = imageOutput?.connection(with: .video) else {
            handleImage(data: nil)
            return
        }
        if #available(iOS 10.0, *) {
            let settings = [AVVideoCodecKey: AVVideoCodecJPEG, AVVideoCompressionPropertiesKey: [AVVideoQualityKey: 1]] as [String : Any]
            (imageOutput as! AVCapturePhotoOutput).capturePhoto(with: AVCapturePhotoSettings(format: settings), delegate: self)
        } else {
            (imageOutput as! AVCaptureStillImageOutput).captureStillImageAsynchronously(from: connection) { [weak self](buffer, error) in
                if buffer == nil {
                    self?.handleImage(data: nil)
                    return
                }
                let data = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer!)
                self?.handleImage(data: data)
                if self?.session.isRunning ?? false {
                    self?.session.stopRunning()
                }
            }
        }
    }
    
    //MARK: handleImage
    private func handleImage(data: Data?) {
        if data != nil {
            if let orgImage = UIImage(data: data!) {
                guard let fixImage = orgImage.fixOrientation() else {
                    return
                }
                if let image = getImageFromPath(orgImage: fixImage) {
                    dataImage = image
                } else {
                    print("拍照失败")
                }
            }
        }
    }
    
    //MARK: 更新摄像头方向
    private func updateVideoOrientation() {
        switch UIApplication.shared.statusBarOrientation {
        case .portraitUpsideDown:
            videoOrientation = .portraitUpsideDown
        case .landscapeLeft:
            videoOrientation = .landscapeLeft
        case .landscapeRight:
            videoOrientation = .landscapeRight
        default:
            videoOrientation = .portrait
        }
        if let connection = previewLayer!.connection {
            connection.videoOrientation = videoOrientation!
        }
    }
    
    //MARK: noti
    @objc private func onDeviceOrientationDidChange() {
        updateVideoOrientation()
        updateFrame()
    }
    
    func updateButton(isShotHidden: Bool) {
        shotBtn.isHidden = isShotHidden
        okBtn.isHidden = !isShotHidden
        cancelBtn.isHidden = !isShotHidden
    }
    
    //MARK: click method
    @objc private func dismissAction() {
        delegate?.cameraPreviewClickDismiss()
        if session.isRunning {
            session.stopRunning()
        }
    }
    
    @objc private func shotAction() {
        getImage()
        updateButton(isShotHidden: true)
    }
    
    @objc private func okAction() {
        delegate?.cameraPreviewClickOk(image: dataImage)
    }
    
    @objc private func cancelAction() {
        if !session.isRunning {
            session.startRunning()
        }
        dataImage = nil
        delegate?.cameraPreviewClickCancel()
        updateButton(isShotHidden: false)
    }
    
    //MARK: AVCapturePhotoCaptureDelegate
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        if photoSampleBuffer != nil {
            let data = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer!, previewPhotoSampleBuffer: previewPhotoSampleBuffer)
            handleImage(data: data)
        } else {
            handleImage(data: nil)
        }
        if session.isRunning {
            session.stopRunning()
        }
    }
    
    //MARK: setup ui
    private func setupCameraLayer() {
        if previewLayer == nil {
            previewLayer = AVCaptureVideoPreviewLayer(session: session!)
            previewLayer!.frame = self.bounds
            previewLayer!.videoGravity = .resizeAspect
            self.layer.addSublayer(previewLayer!)
        }
    }
    
    private func setupPathLayer() {
        let shapeLayer = CAShapeLayer()
        maskLayer = shapeLayer
        shapeLayer.frame = self.bounds
        shapeLayer.fillRule = .evenOdd
        shapeLayer.fillColor = UIColor.black.withAlphaComponent(0.7).cgColor
        
        setMaskPath()
        
        let borderLayer = CAShapeLayer()
        borderLayer.frame = path.bounds
        borderLayer.borderWidth = 6
        borderLayer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        borderLayer.cornerRadius = path.bounds.size.width / 2.0
        borderLayer.masksToBounds = true
        
        shapeLayer.addSublayer(borderLayer)
        self.layer.addSublayer(shapeLayer)
        self.borderLayer = borderLayer
    }
    
    //MARK: update frame
    private func updateFrame() {
        shotBtn.frame = getShotFrame()
        okBtn.frame = getOkFrame()
        cancelBtn.frame = getCancelFrame()
        updateCameraLayer()
    }
    
    private func updateCameraLayer() {
        previewLayer!.frame = self.bounds
        maskLayer.frame = self.bounds
        setMaskPath()
        borderLayer.frame = path.bounds
    }
    
    private func setMaskPath() {
        let width = min(screenWidth, screenHeight) - 40
        let height = min(screenWidth, screenHeight) - 40
        let x = self.center.x - width / 2.0
        let y = self.center.y - height / 2.0
        path = UIBezierPath(ovalIn: CGRect(x: x, y: y, width: width, height: height))
        
        let fillWidth = max(screenWidth, screenHeight)
        let fillX = self.center.x - fillWidth / 2.0
        let fillY = self.center.y - fillWidth / 2.0
        let fillRect = CGRect(x: fillX, y: fillY, width: width, height: width)
        print("fillRect = \(fillRect)")
        let fillPath = UIBezierPath(rect: fillRect)
        fillPath.append(path!)
        fillPath.usesEvenOddFillRule = true
        maskLayer.path = fillPath.cgPath
    }
    
    private func updateMaskPath() {
        if path == nil {
            let width = min(screenWidth, screenHeight) - 40
            let height = min(screenWidth, screenHeight) - 40
            let x = self.bounds.minX - width / 2.0
            let y = self.bounds.minY - height / 2.0
            path = UIBezierPath(ovalIn: CGRect(x: x, y: y, width: width, height: height))
        }
        let fillPath = UIBezierPath(rect: self.bounds)
        fillPath.append(path!)
        fillPath.usesEvenOddFillRule = true
    }
    
    //MARK: get frame
    private func getShotFrame() -> CGRect {
        let width = CGFloat(80.0)
        let height = CGFloat(80.0)
        let margin = CGFloat(40.0)
        var x = self.bounds.width - width - margin
        var y = self.bounds.height / 2.0 - height / 2.0
        if !isLandscape() {
            x = self.bounds.width / 2.0 - height / 2.0
            y = self.bounds.height - height - margin
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    private func getOkFrame() -> CGRect {
        let width = CGFloat(36.0)
        let height = CGFloat(36.0)
        var x = shotBtn.frame.midX - width / 2.0
        var y = shotBtn.frame.minY - height
        if !isLandscape() {
            x = shotBtn.frame.maxX
            y = shotBtn.frame.midY - height / 2.0
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    private func getCancelFrame() -> CGRect {
        let width = CGFloat(36.0)
        let height = CGFloat(36.0)
        var x = shotBtn.frame.midX - width / 2.0
        var y = shotBtn.frame.maxY
        if !isLandscape() {
            x = shotBtn.frame.minX - width
            y = shotBtn.frame.midY - height / 2.0
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    //MARK: lazy load
    lazy private var dismissBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.frame = CGRect(x: 22, y: 16, width: 16, height: 16)
        btn.setImage(UIImage(named: "ic_dismiss"), for: .normal)
        btn.addTarget(self, action: #selector(dismissAction), for: .touchUpInside)
        return btn
    }()
    
    lazy private var shotBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.frame = getShotFrame()
        btn.setImage(UIImage(named: "ic_shot"), for: .normal)
        btn.addTarget(self, action: #selector(shotAction), for: .touchUpInside)
        return btn
    }()
    
    lazy private var okBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.frame = getOkFrame()
        btn.setImage(UIImage(named: "ic_ok"), for: .normal)
        btn.addTarget(self, action: #selector(okAction), for: .touchUpInside)
        btn.isHidden = true
        return btn
    }()
    
    lazy private var cancelBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.frame = getCancelFrame()
        btn.setImage(UIImage(named: "ic_cancel"), for: .normal)
        btn.addTarget(self, action: #selector(cancelAction), for: .touchUpInside)
        btn.isHidden = true
        return btn
    }()
}

extension UIImage {
    func fixOrientation() -> UIImage? {
        if self.imageOrientation == .up {
            return self
        }
        var transform = CGAffineTransform.identity
        switch self.imageOrientation {
        case .down,.downMirrored:
            transform = transform.translatedBy(x: self.size.width, y: self.size.height)
            transform = transform.rotated(by: CGFloat(Double.pi))
        case .left,.leftMirrored:
            transform = transform.translatedBy(x: self.size.width, y: 0)
            transform = transform.rotated(by: CGFloat(-Double.pi / 2.0))

        case .right,.rightMirrored:
            transform = transform.translatedBy(x: 0, y: self.size.height)
            transform = transform.rotated(by: CGFloat(-Double.pi / 2.0))

        default:
            break
        }

        switch self.imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: self.size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: self.size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        default:
            break
        }

        guard let ctx = CGContext(data: nil, width: Int(self.size.width), height: Int(self.size.height), bitsPerComponent: self.cgImage!.bitsPerComponent, bytesPerRow: 0, space: self.cgImage!.colorSpace!, bitmapInfo: self.cgImage!.bitmapInfo.rawValue) else {
            return nil
        }
        
        ctx.concatenate(transform)
        switch self.imageOrientation {
        case .left,.leftMirrored,.rightMirrored,.right:
            ctx.draw(self.cgImage!, in: CGRect(x :0,y:0,width:self.size.height,height: self.size.width))
        default:
            ctx.draw(self.cgImage!, in: CGRect(x :0,y:0,width:self.size.width,height: self.size.height))
        }
        let cgimg = ctx.makeImage()
        let img = UIImage(cgImage: cgimg!)
        return img
    }
}

