//
//  ViewController.swift
//  web-container
//
//  Created by ihugo on 2021/1/12.
//

import UIKit
import WebKit
import SnapKit

class ViewController: UIViewController, WKScriptMessageHandler {
    var webview: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 注入JS
        var jScript = ""
        if let jsPath = Bundle.main.path(forResource: "src/index", ofType: "js") {
            let jsURL = URL(fileURLWithPath: jsPath)
            if  let data = try? Data(contentsOf: jsURL), let script = String(data: data, encoding: .utf8) {
                jScript = script
            }
        }
        
        let wkUScript = WKUserScript(source: jScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        let wkUController = WKUserContentController()
        wkUController.addUserScript(wkUScript)
        let wkWebConfig = WKWebViewConfiguration()
        wkWebConfig.userContentController = wkUController
        // 注入JS交互函数
        wkWebConfig.userContentController.add(self, name: "reLaunch")
        webview = WKWebView(frame: CGRect.zero, configuration: wkWebConfig)
        
        let path = Bundle.main.path(forResource: "index", ofType: "html")
        let url = URL(fileURLWithPath: path!)
        let request = URLRequest(url: url)
        webview.load(request)
        
        self.view.addSubview(webview)
        webview.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
        if #available(iOS 11.0, *) {
            webview.scrollView.contentInsetAdjustmentBehavior = .never
        } else {
        }
        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
//            // your code here
//            self.webview.evaluateJavaScript("native.hello();") { (r1, error) in
//                print("r1 \(r1) error: \(error)")
//            }
//        }
    }
    
    /// WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if (message.name == "reLaunch") {
            guard let dict = message.body as? [String: String],
                  let eventId = dict["eventId"] else { return }
            guard let file = dict["url"],
                  let path = getPath(fileName: file) else {
                done(eventId: eventId, isSuccess: false, data: ["": ""])
                return
            }
            
            done(eventId: eventId, isSuccess: true, data: ["": ""])
            let url = URL(fileURLWithPath: path)
            let request = URLRequest(url: url)
            webview.load(request)
        }
    }
    
    /// 获取资源的路径。
    ///
    /// 默认搜索顺序：Document/web, main bundle
    /// - Parameter fileName: resource name
    /// - Returns: path
    func getPath(fileName: String) -> String? {
        let doc = getDocumentDirectoryPath()
        let fileInDoc = "\(doc.absoluteString)/\(fileName)"
        if FileManager.default.fileExists(atPath: fileName) {
            return fileInDoc
        }
        
        return Bundle.main.path(forResource: fileName, ofType: nil)
    }
    
    func done(eventId: String, isSuccess: Bool, data: [String: String]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .fragmentsAllowed) else { return }
        
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        let script = "native.done('\(eventId)', \(isSuccess), \(jsonString));"
        self.webview.evaluateJavaScript(script) { (r1, error) in
            print("r1 \(r1) error: \(error)")
        }
    }
}

