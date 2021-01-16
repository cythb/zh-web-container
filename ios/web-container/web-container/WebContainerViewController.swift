//
//  ViewController.swift
//  web-container
//
//  Created by ihugo on 2021/1/12.
//

import UIKit
import WebKit
import SnapKit
import Log

let log = Logger()

class WebContainerViewController: UIViewController, WKScriptMessageHandler {
    var webview: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let wkUController = WKUserContentController()
        // 注入JS
        if let infoScript = self.scriptForSystemInfo() {
            wkUController.addUserScript(infoScript)
        }
        let wkUScript = self.scriptForSDK()
        wkUController.addUserScript(wkUScript)
        
        let wkWebConfig = WKWebViewConfiguration()
        wkWebConfig.userContentController = wkUController
        // 注入JS交互函数
        wkWebConfig.userContentController.add(self, name: "reLaunch")
        webview = WKWebView(frame: CGRect.zero, configuration: wkWebConfig)
        webview.uiDelegate = self
        
        let path = getPath(fileName: "index.html")
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
        
        return Bundle.main.path(forResource: "html/\(fileName)", ofType: nil)
    }
    
    func done(eventId: String, isSuccess: Bool, data: [String: String]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .fragmentsAllowed) else { return }
        
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        let script = "native.done('\(eventId)', \(isSuccess), \(jsonString));"
        self.webview.evaluateJavaScript(script) { (result, error) in
            log.debug("result \(String(describing: result)) error: \(String(describing: error))")
        }
    }
    
    private func scriptForSDK() -> WKUserScript {
        var jScript = ""
        if let jsPath = Bundle.main.path(forResource: "src/index", ofType: "js") {
            let jsURL = URL(fileURLWithPath: jsPath)
            if  let data = try? Data(contentsOf: jsURL), let script = String(data: data, encoding: .utf8) {
                jScript = script
            }
        }
        
        let wkUScript = WKUserScript(source: jScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        return wkUScript
    }
    
    private func scriptForSystemInfo() -> WKUserScript? {
        guard let info = SystemInfo.getInfo().jsonString() else { return nil }
        
        let js = "const systemInfo = \(info);"
        let wkUScript = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        return wkUScript
    }
}

extension WebContainerViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
            completionHandler()
        }))
        
        present(alertController, animated: true, completion: nil)
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)

        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
            completionHandler(true)
        }))
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { (action) in
            completionHandler(false)
        }))
        
        present(alertController, animated: true, completion: nil)
    }
    
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alertController = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        
        alertController.addTextField { (textField) in
            textField.text = defaultText
        }
        
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
            if let text = alertController.textFields?.first?.text {
                completionHandler(text)
            } else {
                completionHandler(defaultText)
            }
        }))
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { (action) in
            completionHandler(nil)
        }))
        
        present(alertController, animated: true, completion: nil)
    }
}
