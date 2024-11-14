import UIKit
import WebKit

class WebViewController: UIViewController, WKNavigationDelegate {
    
    var urlString: String?
    private var webView: WKWebView!
    
    override func loadView() {
        webView = WKWebView()
        webView.navigationDelegate = self
        view = webView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let urlString = urlString, let url = URL(string: urlString) else {
            print("Invalid URL.")
            return
        }
        
        webView.load(URLRequest(url: url))
        webView.allowsBackForwardNavigationGestures = true
    }
}

