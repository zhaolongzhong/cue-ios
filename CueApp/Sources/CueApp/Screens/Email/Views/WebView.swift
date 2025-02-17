import SwiftUI
import WebKit

#if os(iOS)
struct WebView: UIViewRepresentable {
    let htmlContent: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(wrapHTML(htmlContent), baseURL: nil)
    }
}
#else
struct WebView: NSViewRepresentable {
    let htmlContent: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator

        // Configure for better content handling
        webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        webView.allowsMagnification = true

        // Important: Set autoresizing mask to fill parent
        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.autoresizingMask = [.width, .height]

        // Enable link handling
        webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        webView.allowsMagnification = true

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(wrapHTML(htmlContent), baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
#endif

extension WebView {
    private func wrapHTML(_ content: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    font-size: 16px;
                    line-height: 1.5;
                    color: #333;
                    margin: 0;
                    padding: 0;
                    background-color: transparent;
                }
                a {
                    color: #007AFF;
                    text-decoration: none;
                }
                img {
                    max-width: 100%;
                    height: auto;
                }
                pre, code {
                    background-color: #f5f5f5;
                    padding: 8px;
                    border-radius: 4px;
                    overflow-x: auto;
                }
                @media (prefers-color-scheme: dark) {
                    body {
                        color: #fff;
                    }
                    a {
                        color: #0A84FF;
                    }
                    pre, code {
                        background-color: #1a1a1a;
                    }
                }
            </style>
        </head>
        <body>
            \(content)
        </body>
        </html>
        """
    }
}
