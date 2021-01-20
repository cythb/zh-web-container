//
//  Plugin.swift
//  web-container
//
//  Created by ihugo on 2021/1/16.
//



protocol Plugin {
    var name: String { get }
    
    func userContentController(webview: WKWebView,
                               userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               done:@escaping (_ eventId: String, _ isSuccess: Bool, _ data: [String: Any]) -> Void,
                               progress: ((_ eventId: String, _ progress: Double) -> Void)?)
}

class ReLaunchPlugin: Plugin {
    
    var name: String {
        return "reLaunch"
    }
    
    func userContentController(webview: WKWebView,
                               userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               done:@escaping (_ eventId: String, _ isSuccess: Bool, _ data: [String: Any]) -> Void,
                               progress: ((String, Double) -> Void)?) {
        guard let dict = message.body as? [String: Any],
              let eventId = dict["eventId"] as? String else { return }
        guard let file = dict["url"] as? String,
              let path = getPath(fileName: file) else {
            done(eventId, false, ["": ""])
            return
        }
        
        done(eventId, true, ["": ""])
        let url = URL(fileURLWithPath: path)
        let request = URLRequest(url: url)
        webview.load(request)
    }
}

class TakePhotoPlugin: Plugin {
    var name: String {
        return "takePhoto"
    }
    
    let picker: RxMediaPicker
    var disposeBag = DisposeBag()
    
    init(delegate: RxMediaPickerDelegate) {
        picker = RxMediaPicker(delegate: delegate)
    }
    
    func userContentController(webview: WKWebView,
                               userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               done:@escaping (String, Bool, [String : Any]) -> Void,
                               progress: ((String, Double) -> Void)?) {
        guard let dict = message.body as? [String: Any],
              let eventId = dict["eventId"] as? String else { return }
        guard let sourceType = dict["sourceType"] as? String else {
            done(eventId, false, ["message": "未传sourceType"])
            return
        }
        var type: UIImagePickerController.CameraDevice = .rear
        if sourceType == "front" {
            type = .front
        }
        guard UIImagePickerController.isCameraDeviceAvailable(type) else {
            done(eventId, false, ["message": "不支持的\(type)"])
            return
        }
        
        disposeBag = DisposeBag()
        picker.takePhoto(device: type, flashMode: .off, editable: false)
            .subscribe { (image) in
                var filePath = getTempDirectoryPath()
                filePath.appendPathComponent("\(Date().timeIntervalSince1970).jpg")
                let data = image.0.jpegData(compressionQuality: type == .front ? 0.4 : 0.2)
                try? data?.write(to: filePath)
                
                done(eventId, false, ["tempImagePath": filePath.absoluteString])
            } onError: { (error) in
                done(eventId, false, ["message": error.localizedDescription])
            }
            .disposed(by: disposeBag)

    }
}

class ChooseImagePlugin: Plugin {
    var name: String {
        return "chooseImage"
    }
    
    let picker: RxMediaPicker
    var disposeBag = DisposeBag()
    
    init(delegate: RxMediaPickerDelegate) {
        picker = RxMediaPicker(delegate: delegate)
    }
    
    func userContentController(webview: WKWebView,
                               userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               done:@escaping (String, Bool, [String : Any]) -> Void,
                               progress: ((String, Double) -> Void)?) {
        guard let dict = message.body as? [String: Any],
              let eventId = dict["eventId"] as? String else { return }
        guard let sourceType = dict["sourceType"] as? String else {
            done(eventId, false, ["message": "未传sourceType"])
            return
        }
        var type: UIImagePickerController.SourceType = .photoLibrary
        if sourceType == "album" {
            type = .savedPhotosAlbum
        }
        if sourceType == "camera" {
            type = .camera
        }
        guard UIImagePickerController.isSourceTypeAvailable(type) else {
            done(eventId, false, ["message": "不支持的\(type)"])
            return
        }
        
        disposeBag = DisposeBag()
        picker.selectImage(source: type, editable: true)
            .subscribe { (image) in
                var filePath = getTempDirectoryPath()
                filePath.appendPathComponent("\(Date().timeIntervalSince1970).jpg")
                let data = image.0.jpegData(compressionQuality: 0.8)
                try? data?.write(to: filePath)
                
                done(eventId, false, ["tempImagePath": filePath.absoluteString])
            } onError: { (error) in
                done(eventId, false, ["message": error.localizedDescription])
            }
            .disposed(by: disposeBag)

    }
}

class ScanCodePlugin: NSObject, Plugin, UIImagePickerControllerDelegate, UINavigationControllerDelegate,
                      LBXScanViewControllerDelegate {
    var name: String {
        return "scanCode"
    }
    
    weak var presentingVC: UIViewController? = nil
    var eventId: String?
    var onlyFromCamera: Bool = false
    var done: ((String, Bool, [String : Any]) -> Void)?

    init(presentingVC: UIViewController?) {
        self.presentingVC = presentingVC
    }
    
    func userContentController(webview: WKWebView,
                               userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               done:@escaping (String, Bool, [String : Any]) -> Void,
                               progress: ((String, Double) -> Void)?) {
        guard let dict = message.body as? [String: Any],
              let eventId = dict["eventId"] as? String else { return }
        if let flag = (dict["onlyFromCamera"] as? Bool) {
            onlyFromCamera = flag
        }
        self.eventId = eventId
        self.done = done
        
        if onlyFromCamera == false {
            let alertController = UIAlertController(title: nil, message: "您希望如何进行扫描？", preferredStyle: .actionSheet)
            alertController.addAction(UIAlertAction(title: "相册", style: .default, handler: { [unowned self] (action) in
                self.openAlbum()
            }))
            
            alertController.addAction(UIAlertAction(title: "相机", style: .default, handler: { [unowned self] (action) in
                self.openCamera()
            }))
            self.presentingVC?.present(alertController, animated: true)
        } else {
            self.openCamera()
        }
    }
    
    private func openAlbum() {
        LBXPermissions.authorizePhotoWith { [unowned self] (granted) in
            if granted {
                let picker = UIImagePickerController()
              
                picker.sourceType = UIImagePickerController.SourceType.photoLibrary
                picker.delegate = self

                picker.allowsEditing = true
                presentingVC?.present(picker, animated: true, completion: nil)
            } else {
                LBXPermissions.jumpToSystemPrivacySetting()
            }
        }
    }
    
    private func openCamera() {
        //设置扫码区域参数
        var style = LBXScanViewStyle()
        style.centerUpOffset = 44
        style.photoframeAngleStyle = LBXScanViewPhotoframeAngleStyle.Inner
        style.photoframeLineW = 2
        style.photoframeAngleW = 18
        style.photoframeAngleH = 18
        style.isNeedShowRetangle = false

        style.anmiationStyle = LBXScanViewAnimationStyle.LineMove

        style.colorAngle = UIColor(red: 0.0/255, green: 200.0/255.0, blue: 20.0/255.0, alpha: 1.0)

        style.animationImage = UIImage(named: "CodeScan.bundle/qrcode_Scan_weixin_Line")

        let vc = LBXScanViewController()
        vc.scanStyle = style
        vc.scanResultDelegate = self
        self.presentingVC?.present(vc, animated: true)
    }
    
    func scanFinished(scanResult: LBXScanResult, error: String?) {
        guard let eventId = self.eventId else {
            return
        }
        
        if error == nil {
            self.done?(eventId, true, ["result": scanResult.strScanned ?? ""])
        } else {
            self.done?(eventId, false, ["message": error ?? ""])
        }
        self.presentingVC?.dismiss(animated: true)
    }
    
    // MARK: - 相册选择图片识别二维码
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        
        var image:UIImage? = info[UIImagePickerController.InfoKey.editedImage] as? UIImage
        
        if (image == nil )
        {
            image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage
        }
        
        if(image == nil) {
            return
        }
        
        if(image != nil) {
            let arrayResult = LBXScanWrapper.recognizeQRImage(image: image!)
            if arrayResult.count > 0 {
                let result = arrayResult[0]
                
                //showMsg(title: result.strBarCodeType, message: result.strScanned)
                if let eventId = self.eventId {
                    self.done?(eventId, true, ["result": result.strScanned ?? ""])
                }
                
                return
            }
        }
        
        if let eventId = self.eventId {
            self.done?(eventId, false, ["message": "识别失败"])
        }
    }
}

class GetFileListPlugin: Plugin {
    var name: String {
        return "getFileList"
    }
    
    func userContentController(webview: WKWebView,
                               userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               done:@escaping (String, Bool, [String : Any]) -> Void,
                               progress: ((String, Double) -> Void)?) {
        guard let dict = message.body as? [String: Any],
              let eventId = dict["eventId"] as? String else { return }
        var path = (dict["path"] as? String) ?? "/"
        if path.hasSuffix("/") {
            path.removeLast()
        }
        
        var files = [[String: Any]]()
        var url = getHomeDirectoryPath()
        if path.lengthOfBytes(using: .utf8) > 0 {
            url.appendPathComponent(path)
        }
        if let items = try? FileManager.default.contentsOfDirectory(atPath: url.relativePath) {
            for file in items {
                let filePath = "\(url.relativePath)/\(file)"
                guard let attributes = try? FileManager.default.attributesOfItem(atPath: filePath) as NSDictionary else {
                    done(eventId, false, ["message": "获取文件属性失败"])
                    continue
                }
                var item = [String: Any]()
                let size = attributes.fileSize()
                let createTime = attributes.fileCreationDate()?.timeIntervalSince1970 ?? 0
                let fileType = attributes.fileType()
                item["filePath"] = filePath
                item["size"] = size
                item["createTime"] = createTime
                item["fileType"] = fileType
                files.append(item)
            }
            done(eventId, true, ["files": files])
            return
        }
        done(eventId, false, ["message": "查询文件失败"])
    }
}

class RmfilePlugin: Plugin {
    var name: String {
        return "rmFile"
    }
    
    func userContentController(webview: WKWebView,
                               userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               done:@escaping (String, Bool, [String : Any]) -> Void,
                               progress: ((String, Double) -> Void)?) {
        guard let dict = message.body as? [String: Any],
              let eventId = dict["eventId"] as? String else { return }
        var path = (dict["path"] as? String) ?? "/"
        if path.hasSuffix("/") {
            path.removeLast()
        }
        
        var url = getHomeDirectoryPath()
        if path.lengthOfBytes(using: .utf8) > 0 {
            url.appendPathComponent(path)
        }
        if FileManager.default.fileExists(atPath: url.relativePath) {
            do {
                try FileManager.default.removeItem(atPath: url.relativePath)
                done(eventId, true, ["message": "删除文件成功"])
            } catch {
                done(eventId, false, ["message": "删除文件失败"])
            }
        } else {
            done(eventId, true, ["message": "删除文件成功"])
        }
    }
}

class UnzipPlugin: Plugin {
    var name: String {
        return "unzip"
    }
    
    func userContentController(webview: WKWebView,
                               userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               done:@escaping (String, Bool, [String : Any]) -> Void,
                               progress: ((String, Double) -> Void)?) {
        guard let dict = message.body as? [String: Any],
              let eventId = dict["eventId"] as? String else { return }
        guard var zipFilePath = dict["zipFilePath"] as? String,
              var targetPath = dict["targetPath"] as? String else {
            done(eventId, false, ["message": "解压缩失败"])
            return
        }
        
        if zipFilePath.starts(with:"/") {
            zipFilePath.removeFirst()
        }
        if targetPath.starts(with:"/") {
            targetPath.removeFirst()
        }
        guard zipFilePath.lengthOfBytes(using: .utf8) > 0,
              targetPath.lengthOfBytes(using: .utf8) > 0 else {
            done(eventId, false, ["message": "解压缩失败"])
            return
        }
        
        let url = getHomeDirectoryPath()
        let zipURL = url.appendingPathComponent(zipFilePath)
        let targetURL = url.appendingPathComponent(targetPath)
        
        do {
            try Zip.unzipFile(zipURL, destination: targetURL, overwrite: true, password:nil, progress: { (percent) -> () in
                progress?(eventId, percent)
                
                if percent == 1 {
                    done(eventId, true, ["message": "解压缩成功"])
                }
            })
        }
        catch {
            done(eventId, false, ["message": "解压缩失败"])
        }
    }
}
