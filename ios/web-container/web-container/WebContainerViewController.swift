//
//  ViewController.swift
//  web-container
//
//  Created by ihugo on 2021/1/12.
//


let log = Logger()

class WebContainerViewController: UIViewController, WKScriptMessageHandler {
    var webview: WKWebView!
    var plugins = [Plugin]()
    
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
        let relaunchPlugin = ReLaunchPlugin()
        let takePhotoPlugin = TakePhotoPlugin(delegate: self)
        let chooseImagePlugin = ChooseImagePlugin(delegate: self)
        let scanCodePlugin = ScanCodePlugin(presentingVC: self)
        let getFileListPlugin = GetFileListPlugin()
        let rmfilePlugin = RmfilePlugin()
        let unzip = UnzipPlugin()
        let downlaod = DownloadFilePlugin()
        self.registerPlugin(wkWebConfig: wkWebConfig, plugin: relaunchPlugin)
        self.registerPlugin(wkWebConfig: wkWebConfig, plugin: takePhotoPlugin)
        self.registerPlugin(wkWebConfig: wkWebConfig, plugin: chooseImagePlugin)
        self.registerPlugin(wkWebConfig: wkWebConfig, plugin: scanCodePlugin)
        self.registerPlugin(wkWebConfig: wkWebConfig, plugin: getFileListPlugin)
        self.registerPlugin(wkWebConfig: wkWebConfig, plugin: rmfilePlugin)
        self.registerPlugin(wkWebConfig: wkWebConfig, plugin: unzip)
        self.registerPlugin(wkWebConfig: wkWebConfig, plugin: downlaod)

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
    }
    
    /// WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let plugin = self.plugins.first(where: { (p) -> Bool in
            return p.name == message.name
        }) else { return }
        
        guard let dict = message.body as? [String: Any],
              nil != dict["eventId"] as? String else { return }
        
        // 传递调用的progress闭包进去，就和done一样，用来和js交互
        // progress -> js.progress -> html
        plugin.userContentController(webview: webview, userContentController: userContentController, didReceive: message, done: done, progress: progress)
    }
    
    func done(eventId: String, isSuccess: Bool, data: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .fragmentsAllowed) else { return }
        
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        let script = "native.done('\(eventId)', \(isSuccess), \(jsonString));"
        self.webview.evaluateJavaScript(script) { (result, error) in
            log.debug("result \(String(describing: result)) error: \(String(describing: error)) data: \(data)")
        }
    }
    
    func progress(eventId: String, progress: Double) {
        let script = "native.progress('\(eventId)', \(progress));"
        self.webview.evaluateJavaScript(script) { (result, error) in
            log.debug("result-progress \(String(describing: result)) error: \(String(describing: error))")
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
    
    private func registerPlugin(wkWebConfig: WKWebViewConfiguration, plugin: Plugin) {
        guard nil == self.plugins.first(where: { (p) -> Bool in
            return p.name == plugin.name
        }) else {
            log.debug("plugin already exists: \(plugin.name)")
            return
        }
        
        wkWebConfig.userContentController.add(self, name: plugin.name)
        self.plugins.append(plugin)
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

extension WebContainerViewController: RxMediaPickerDelegate {
    func present(picker: UIImagePickerController) {
        self.present(picker, animated: true, completion: nil)
    }
    
    func dismiss(picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
}
