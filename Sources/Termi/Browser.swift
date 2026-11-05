import SwiftUI
import WebKit

@MainActor
final class BrowserDelegate: NSObject, WKNavigationDelegate, WKUIDelegate {
    weak var tab: Tab?
    init(tab: Tab) { self.tab = tab }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        tab?.isLoading = true; tab?.browserError = nil
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        tab?.isLoading = false
        tab?.address = webView.url?.absoluteString ?? ""
        tab?.pageTitle = webView.title ?? "Browser"
        tab?.onChange?()
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failed(error) }
    private func failed(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        tab?.isLoading = false; tab?.browserError = error.localizedDescription
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let scheme = navigationAction.request.url?.scheme?.lowercased() ?? ""
        decisionHandler(["http", "https", "about"].contains(scheme) ? .allow : .cancel)
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url, ["http", "https"].contains(url.scheme ?? "") { webView.load(URLRequest(url: url)) }
        return nil
    }
}

struct BrowserHost: NSViewRepresentable {
    @ObservedObject var tab: Tab
    func makeNSView(context: Context) -> WKWebView {
        if let existing = tab.webView { return existing }
        let web = WKWebView(frame: .zero)
        web.underPageBackgroundColor = Palette.terminal
        web.allowsBackForwardNavigationGestures = true
        web.isInspectable = true
        let delegate = BrowserDelegate(tab: tab)
        tab.browserDelegate = delegate
        web.navigationDelegate = delegate; web.uiDelegate = delegate
        tab.webView = web
        if let url = AddressResolver.resolve(tab.address) { web.load(URLRequest(url: url)) }
        return web
    }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

struct BrowserContent: View {
    @ObservedObject var tab: Tab
    @State private var input = ""
    @State private var homeSearch = ""
    @FocusState private var addressFocused: Bool
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                IconButton(icon: "chevron.left", help: "Go back") { tab.webView?.goBack() }.disabled(tab.webView?.canGoBack != true)
                IconButton(icon: "chevron.right", help: "Go forward") { tab.webView?.goForward() }.disabled(tab.webView?.canGoForward != true)
                IconButton(icon: tab.isLoading ? "xmark" : "arrow.clockwise", help: tab.isLoading ? "Stop loading" : "Reload page") { if tab.isLoading { tab.webView?.stopLoading(); tab.isLoading = false } else { tab.webView?.reload() } }
                HStack(spacing: 8) {
                    Image(systemName: input.hasPrefix("https:") ? "lock" : "globe").font(.system(size: 11)).foregroundStyle(Palette.dim)
                    TextField("Search or enter a URL", text: $input).textFieldStyle(.plain).font(.system(size: 12)).focused($addressFocused).onSubmit { navigate(input) }
                    if tab.isLoading { ProgressView().controlSize(.mini) }
                }.padding(.horizontal, 12).frame(height: 30).background(Color.black.opacity(0.17), in: RoundedRectangle(cornerRadius: 7)).overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Palette.line))
                IconButton(icon: "safari", help: "Open in default browser") {
                    if let url = tab.webView?.url { NSWorkspace.shared.open(url) }
                }
            }.padding(.horizontal, 16).frame(height: 52).background(Palette.background)
            Rectangle().fill(Palette.line).frame(height: 1)
            ZStack {
                if tab.address.isEmpty {
                    VStack(spacing: 22) {
                        Image(systemName: "globe.americas").font(.system(size: 36, weight: .ultraLight)).foregroundStyle(Palette.accent)
                            .frame(width: 80, height: 80).background(Palette.accent.opacity(0.055), in: RoundedRectangle(cornerRadius: 23))
                        VStack(spacing: 9) {
                            Text("The web, within reach.").font(.system(size: 28, weight: .medium, design: .rounded)).tracking(-0.7).foregroundStyle(Palette.text)
                            Text("Your preview, your docs, your next idea.").font(.system(size: 13)).foregroundStyle(Palette.muted)
                        }
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
                            TextField("Search the web or enter a URL", text: $homeSearch).textFieldStyle(.plain).onSubmit { navigate(homeSearch) }
                            Shortcut(label: "↵")
                        }.padding(15).frame(width: 400).background(Palette.elevated, in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.line))
                        HStack(spacing: 12) {
                            quickLink("Localhost", detail: ":3000", icon: "server.rack", url: "http://localhost:3000")
                            quickLink("GitHub", detail: "Your code", icon: "chevron.left.forwardslash.chevron.right", url: "https://github.com")
                            quickLink("MDN", detail: "Web docs", icon: "book.closed", url: "https://developer.mozilla.org")
                        }.padding(.top, 5)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    BrowserHost(tab: tab)
                    if let error = tab.browserError {
                        VStack(spacing: 16) {
                            Image(systemName: "wifi.exclamationmark").font(.system(size: 30)).foregroundStyle(Palette.accent)
                            Text("Couldn’t reach this page").font(.system(size: 21, weight: .medium))
                            Text(error).font(.system(size: 13)).foregroundStyle(Palette.muted).multilineTextAlignment(.center).frame(maxWidth: 380)
                            Button("Try again") { tab.webView?.reload() }.buttonStyle(.bordered)
                        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.background)
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.onAppear { input = tab.address }.onChange(of: tab.address) { _, value in if !addressFocused { input = value } }
    }
    func navigate(_ value: String) {
        guard let url = AddressResolver.resolve(value) else { return }
        tab.browserError = nil; addressFocused = false; input = url.absoluteString
        if let web = tab.webView { web.load(URLRequest(url: url)) }
        tab.address = url.absoluteString; tab.onChange?()
    }
    func quickLink(_ title: String, detail: String, icon: String, url: String) -> some View {
        Button { navigate(url) } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon).font(.system(size: 16)).foregroundStyle(Palette.accent)
                VStack(alignment: .leading, spacing: 3) { Text(title).foregroundStyle(Palette.text); Text(detail).font(.system(size: 10)).foregroundStyle(Palette.dim) }
            }.font(.system(size: 12, weight: .medium)).frame(width: 102, alignment: .leading).padding(14)
                .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Palette.line))
        }.buttonStyle(.plain)
    }
}
