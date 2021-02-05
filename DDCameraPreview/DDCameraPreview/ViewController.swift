//
//  ViewController.swift
//  DDCameraPreview
//
//  Created by 姜维东 on 2021/2/5.
//

import UIKit

class ViewController: UIViewController {
    
    private lazy var imageView: UIImageView = {
       let imageView = UIImageView(frame: CGRect(x: 100, y: 150, width: 200, height: 200))
        imageView.backgroundColor = .white
        return imageView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .cyan
        view.addSubview(imageView)
        
        let btn = UIButton(frame: CGRect(x: 200, y: 50, width: 50, height: 50))
        btn.backgroundColor = .white
        btn.addTarget(self, action: #selector(nextPage), for: .touchUpInside)
        view.addSubview(btn)
    }
    
    @objc private func nextPage() {
        let vc = CameraViewController()
        vc.imageCallBack = { [weak self] filePath in
            if let data = FileManager.default.contents(atPath: filePath) {
                let image = UIImage(data: data)
                self?.imageView.image = image
            } else {
                print("获取图片失败")
            }
        }
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true, completion: nil)
    }
}

