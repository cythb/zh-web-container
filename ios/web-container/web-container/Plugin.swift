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
        guard var file = dict["url"] as? String else {
            done(eventId, false, ["": ""])
            return
        }
        
        // Special path handling, if `mainbundle/index` opens the built-in home page.
        if file.starts(with: "mainbundle/") {
            var components = file.split(separator: "/")
            components.removeFirst()
            file = components.joined(separator: "/")
        }
        
        guard let path = getPath(fileName: file) else {
            done(eventId, false, ["": ""])
            return
        }
        let url = URL(fileURLWithPath: path)
        
        done(eventId, true, ["": ""])
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

class DownloadFilePlugin: Plugin {
    var downlaodBag = DisposeBag()

    var name: String {
        return "downloadFile"
    }
    
    func userContentController(webview: WKWebView,
                               userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               done:@escaping (String, Bool, [String: Any]) -> Void,
                               progress: ((String, Double) -> Void)?) {
        guard let dict = message.body as? [String: Any],
              let eventId = dict["eventId"] as? String else { return }
        guard let urlStr = dict["url"] as? String,
              var filePath = dict["filePath"] as? String,
              let url = URL(string: urlStr) else {
            done(eventId, false, ["message": "下载失败"])
            return
        }
        
        if filePath.starts(with:"/") {
            filePath.removeFirst()
        }
        guard filePath.lengthOfBytes(using: .utf8) > 0 else {
            done(eventId, false, ["message": "下载失败"])
            return
        }
        
        let homrUrl = getHomeDirectoryPath()
        let fileURL = homrUrl.appendingPathComponent(filePath)

        RxAlamofire.download(URLRequest(url: url) ) { (aURL, response) -> (destinationURL: URL, options: DownloadRequest.Options) in
            return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
        }.flatMap { request -> Observable<RxProgress> in
            let progressPart = request.rx.progress()
            return progressPart
        }.subscribe(onNext: { (p) in
            log.debug(p.completed)
            progress?(eventId, Double(p.completed))
        }, onError: { (_) in
            done(eventId, false, ["message": "下载失败"])
        }, onCompleted: {
            done(eventId, true, ["message": "下载成功"])
        }, onDisposed: {
            log.debug("download disposed")
        })
        .disposed(by: downlaodBag)
    }
}


class UploadFilePlugin: Plugin {
    var uploadBag = DisposeBag()
    
    var name: String {
        return "uploadFile"
    }
    
    func userContentController(webview: WKWebView,
                               userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               done:@escaping (String, Bool, [String: Any]) -> Void,
                               progress: ((String, Double) -> Void)?) {
        guard let dict = message.body as? [String: Any],
              let eventId = dict["eventId"] as? String else { return }
        guard let urlStr = dict["url"] as? String,
              var filePath = dict["filePath"] as? String,
              let name = dict["name"] as? String,
              let url = URL(string: urlStr) else {
            done(eventId, false, ["message": "下载失败"])
            return
        }
        
        if filePath.starts(with:"/") {
            filePath.removeFirst()
        }
        guard filePath.lengthOfBytes(using: .utf8) > 0 else {
            done(eventId, false, ["message": "上传失败，请检查文件路径是否正确"])
            return
        }
        
        let homrUrl = getHomeDirectoryPath()
        let fileURL = homrUrl.appendingPathComponent(filePath)
        
        let parameters = dict["formData"] as? [String: String]

        let upload: Observable<RxAlamofire.RxProgress> = RxAlamofire.upload(multipartFormData: { (multipartFormData) in
            if let parameters = parameters {
                for (key, value) in parameters {
                    multipartFormData.append("\(value)".data(using: String.Encoding.utf8)!, withName: key as String)
                }
            }
            multipartFormData.append(fileURL, withName: name)
        }, to: url, method: .post, headers: nil)
        upload.subscribe(onNext: { (p) in
            log.debug(p.completed)
            progress?(eventId, Double(p.completed))
        }, onError: { (_) in
            done(eventId, false, ["message": "上传失败"])
        }, onCompleted: {
            done(eventId, true, ["message": "上传成功"])
        }, onDisposed: {
            log.debug("upload disposed")
        }).disposed(by: uploadBag)
    }
}

var database: FMDatabase?
class OpenSqlitePlugin: Plugin {
    var name: String {
        return "openSqlite"
    }
    
    func userContentController(webview: WKWebView,
                               userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               done:@escaping (String, Bool, [String: Any]) -> Void,
                               progress: ((String, Double) -> Void)?) {
        guard let dict = message.body as? [String: Any],
              let eventId = dict["eventId"] as? String else { return }
        guard var filePath = dict["file"] as? String else {
            done(eventId, false, ["message": "打开sqlite文件失败"])
            return
        }
        guard database == nil else {
            done(eventId, false, ["message": "打开sqlite文件失败, 已经打开一个sqlite数据库，请先关闭。"])
            return
        }
        
        if filePath.starts(with:"/") {
            filePath.removeFirst()
        }
        guard filePath.lengthOfBytes(using: .utf8) > 0 else {
            done(eventId, false, ["message": "打开sqlite文件失败，请检查文件路径是否正确"])
            return
        }
        
        let homrUrl = getHomeDirectoryPath()
        let fileURL = homrUrl.appendingPathComponent(filePath)
        
        database = FMDatabase(url: fileURL)
        if database?.open() == false {
            done(eventId, false, ["message": "打开sqlite文件失败"])
        } else {
            done(eventId, true, ["message": "打开sqlite文件成功"])
        }
    }
}

class CloseSqlitePlugin: Plugin {
    var name: String {
        return "closeSqlite"
    }
    
    func userContentController(webview: WKWebView,
                               userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               done:@escaping (String, Bool, [String: Any]) -> Void,
                               progress: ((String, Double) -> Void)?) {
        guard let dict = message.body as? [String: Any],
              let eventId = dict["eventId"] as? String else { return }
        guard database != nil else {
            done(eventId, false, ["message": "关闭失败，目前没有打开的数据库。"])
            return
        }
        
        database?.close()
        database = nil
        done(eventId, true, ["message": "关闭sqlite文件成功"])
    }
}

class ExecuteUpdatePlugin: Plugin {
    var name: String {
        return "executeUpdate"
    }
    
    func userContentController(webview: WKWebView,
                               userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               done:@escaping (String, Bool, [String: Any]) -> Void,
                               progress: ((String, Double) -> Void)?) {
        guard let dict = message.body as? [String: Any],
              let eventId = dict["eventId"] as? String else { return }
        guard let sql = dict["sql"] as? String else {
            done(eventId, false, ["message": "未找到执行的sql语句"])
            return
        }
        guard let db = database else {
            done(eventId, false, ["message": "执行sql失败，目前没有打开的数据库。"])
            return
        }
        
        do {
            try db.executeUpdate(sql, values: nil)
            done(eventId, true, ["message": "执行sql成功."])
        } catch let error {
            done(eventId, false, ["message": "执行sql失败.\(error)"])
            log.error(error)
        }
    }
}

class ExecuteQueryPlugin: Plugin {
    var name: String {
        return "executeQuery"
    }
    
    func userContentController(webview: WKWebView,
                               userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               done:@escaping (String, Bool, [String: Any]) -> Void,
                               progress: ((String, Double) -> Void)?) {
        guard let dict = message.body as? [String: Any],
              let eventId = dict["eventId"] as? String else { return }
        guard let sql = dict["sql"] as? String else {
            done(eventId, false, ["message": "未找到执行的sql语句"])
            return
        }
        guard let db = database else {
            done(eventId, false, ["message": "查询失败，目前没有打开的数据库。"])
            return
        }
        
        do {
            let rs = try db.executeQuery(sql, values: nil)
            var results = [[String: Any]]()
            while rs.next() {
                guard let result = (rs.resultDictionary as? [String: Any]) else { continue }
                
                results.append(result)
            }
            done(eventId, true, ["message": "执行sql成功.", "results": results])
            log.debug("执行sql成功：\(results)")
        } catch let error {
            done(eventId, false, ["message": "执行sql失败.\(error)"])
            log.error(error)
        }
    }
}
