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
        wkWebConfig.userContentController.add(self, name: "callbackHandler")
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            // your code here
            self.webview.evaluateJavaScript("native.hello();") { (r1, error) in
                print("r1 \(r1) error: \(error)")
            }
        }
    }
    
    /// WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if (message.name == "callbackHandler") {
            
        }
    }
}

