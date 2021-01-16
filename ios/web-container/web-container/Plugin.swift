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
                               done:@escaping (_ eventId: String, _ isSuccess: Bool, _ data: [String: String]) -> Void )
}

class ReLaunchPlugin: Plugin {
    var name: String {
        return "reLaunch"
    }
    
    func userContentController(webview: WKWebView,
                               userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               done:@escaping (_ eventId: String, _ isSuccess: Bool, _ data: [String: String]) -> Void ) {
        guard let dict = message.body as? [String: String],
              let eventId = dict["eventId"] else { return }
        guard let file = dict["url"],
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
                               done:@escaping (String, Bool, [String : String]) -> Void) {
        guard let dict = message.body as? [String: String],
              let eventId = dict["eventId"] else { return }
        guard let sourceType = dict["sourceType"] else {
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
                               done:@escaping (String, Bool, [String : String]) -> Void) {
        guard let dict = message.body as? [String: String],
              let eventId = dict["eventId"] else { return }
        guard let sourceType = dict["sourceType"] else {
            done(eventId, false, ["message": "未传sourceType"])
            return
        }
        var type: UIImagePickerController.SourceType = .photoLibrary
        if sourceType.contains("album") {
            type = .savedPhotosAlbum
        }
        if sourceType.contains("camera") {
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
