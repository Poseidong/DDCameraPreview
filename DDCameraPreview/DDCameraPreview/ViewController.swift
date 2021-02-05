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
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let vc = CameraViewController()
        vc.imageCallBack = { [weak self] image in
            print("imageSize: \(image.size)")
            self?.imageView.image = image
        }
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true, completion: nil)
    }

}

