//
//  Plugin.swift
//  web-container
//
//  Created by ihugo on 2021/1/16.
//

import Foundation
import WebKit

protocol Plugin {
    var name: String { get }
    
    func userContentController(webview: WKWebView,
                               userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               done: (_ eventId: String, _ isSuccess: Bool, _ data: [String: String]) -> Void )
}

class ReLaunchPlugin: Plugin {
    var name: String {
        return "reLaunch"
    }
    
    func userContentController(webview: WKWebView,
                               userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               done: (_ eventId: String, _ isSuccess: Bool, _ data: [String: String]) -> Void ) {
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
