//
//  ContentView.swift
//  historydatesapp4ios
//
//  Created by qiaelel on 25.10.2026.
//

import SwiftUI
import WebKit
import Combine


struct ContentView: View {
    @StateObject private var webState = WebViewState()
    private let targetURL = URL(string: "https://historydatesapp.qiaelel.ru")!


    private var isRunningForPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            if isRunningForPreviews {
                VStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                    Text("Предпросмотр WebKit отключен в Canvas")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
            } else {
                WebViewWrapper(url: targetURL, webState: webState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea(edges: .bottom)
            }


            if webState.isLoading && !webState.hasError && !isRunningForPreviews {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                    .scaleEffect(1.3)
            }


            if webState.hasError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(Color(UIColor.systemGray2))

                    Text("Что-то пошло не так...")
                        .font(.headline)
                        .foregroundColor(.black)
                    
                    Text("Возможно страница не была сохранена. Попробуйте подключится к интернету и перезапустить приложение.")
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Text("Ошибка:")
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Text(webState.errorMessage)
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    


                    Button(action: {
                        webState.retryAction?()
                    }) {
                        Label("Повторить", systemImage: "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
            }
        }
        .preferredColorScheme(.light)
    }
}


class WebViewState: ObservableObject {
    @Published var isLoading: Bool = true
    @Published var hasError: Bool = false
    @Published var errorMessage: String = ""
    var retryAction: (() -> Void)?
}


struct WebViewWrapper: UIViewRepresentable {
    let url: URL
    @ObservedObject var webState: WebViewState

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true

        let initialFrame = UIScreen.main.bounds
        let webView = WKWebView(frame: initialFrame, configuration: configuration)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]


        webView.overrideUserInterfaceStyle = .light
        webView.scrollView.overrideUserInterfaceStyle = .light


        webView.isOpaque = true
        webView.backgroundColor = .white
        webView.scrollView.backgroundColor = .white


        webView.scrollView.indicatorStyle = .black

        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.bounces = true


        webView.customUserAgent = "historydatesapp4ios/1.0"


        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = .systemGray
        refreshControl.addTarget(context.coordinator, action: #selector(Coordinator.handleRefresh), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl

        context.coordinator.webView = webView
        webState.retryAction = { [weak webView] in
            webState.hasError = false
            webState.isLoading = true
            webView?.load(URLRequest(url: url))
        }

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewWrapper
        weak var webView: WKWebView?

        init(_ parent: WebViewWrapper) {
            self.parent = parent
        }

        @objc func handleRefresh() {
            webView?.reload()
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.webState.isLoading = true
                self.parent.webState.hasError = false
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.webState.isLoading = false
                self.parent.webState.hasError = false
                webView.scrollView.refreshControl?.endRefreshing()
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            handleNavigationError(error, webView: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handleNavigationError(error, webView: webView)
        }

        private func handleNavigationError(_ error: Error, webView: WKWebView) {
            DispatchQueue.main.async {
                let nsError = error as NSError
                if nsError.code == NSURLErrorCancelled {
                    return
                }
                self.parent.webState.isLoading = false
                self.parent.webState.hasError = true
                self.parent.webState.errorMessage = error.localizedDescription
                webView.scrollView.refreshControl?.endRefreshing()
            }
        }
    }
}
