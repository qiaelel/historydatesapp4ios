//
//  ContentView.swift
//  historydatesapp4ios
//
//  Created by qiaelel on 25.10.2026.
//

import SwiftUI
import WebKit
import Combine

// MARK: - Локальное хранилище страниц для надежного офлайн-режима
final class OfflineStorage {
    static let shared = OfflineStorage()
    private let folderURL: URL

    private init() {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        folderURL = paths[0].appendingPathComponent("OfflinePages", isDirectory: true)
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
    }

    private func fileName(for url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.fragment = nil
        var urlString = components?.string ?? url.absoluteString
        if urlString.hasSuffix("/") && url.path != "/" && !url.path.isEmpty {
            urlString.removeLast()
        }
        let data = Data(urlString.utf8)
        return data.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-") + ".html"
    }

    func save(html: String, for url: URL) {
        let fileURL = folderURL.appendingPathComponent(fileName(for: url))
        try? html.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func getHTML(for url: URL) -> String? {
        let fileURL = folderURL.appendingPathComponent(fileName(for: url))
        if let html = try? String(contentsOf: fileURL, encoding: .utf8), !html.isEmpty {
            return html
        }
        var alt = url.absoluteString
        if alt.hasSuffix("/") { alt.removeLast() } else { alt += "/" }
        if let altURL = URL(string: alt) {
            let altFileURL = folderURL.appendingPathComponent(fileName(for: altURL))
            return try? String(contentsOf: altFileURL, encoding: .utf8)
        }
        return nil
    }
}

// MARK: - Главный экран
struct ContentView: View {
    @AppStorage("isInitialCacheCompleted") private var isInitialCacheCompleted: Bool = false

    @StateObject private var webState = WebViewState()
    @State private var cacheProgress: Double = 0.0
    @State private var cacheStatusText: String = "Инициализация..."

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
                WebViewWrapper(
                    url: targetURL,
                    webState: webState,
                    isInitialCacheCompleted: isInitialCacheCompleted,
                    onProgressUpdate: { progress, text in
                        self.cacheProgress = progress
                        if let text = text { self.cacheStatusText = text }
                    },
                    onCacheCompleted: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            self.isInitialCacheCompleted = true
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(edges: .bottom)
            }

            // 1. Экран первичного кэширования (таймаут 60 сек)
            if !isInitialCacheCompleted && !isRunningForPreviews && !webState.hasError {
                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)

                    VStack(spacing: 8) {
                        Text("Обновление")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.black)

                        Text("Обновляем данные проекта для работы с актуальной информацией без интернета.")
                            .font(.subheadline)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 36)
                        Text("Это версия для закрытого бета-тестирования (v.1.0 RC2).")
                            .font(.subheadline)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 36)
                        Text("iam@qiaelel.ru")
                            .font(.subheadline)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 36)
                    }

                    VStack(spacing: 10) {
                        if cacheProgress > 0 {
                            ProgressView(value: min(max(cacheProgress, 0.0), 1.0), total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                .padding(.horizontal, 48)

                            Text("\(Int(min(max(cacheProgress, 0.0), 1.0) * 100))%")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.gray)
                        } else {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                                .scaleEffect(1.2)
                        }

                        Text(cacheStatusText)
                            .font(.caption2)
                            .foregroundColor(Color(UIColor.tertiaryLabel))
                    }
                    .padding(.top, 12)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
                .transition(.opacity)
            }

            // 2. Индикатор обычной загрузки страницы
            if webState.isLoading && isInitialCacheCompleted && !webState.hasError && !isRunningForPreviews {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                    .scaleEffect(1.3)
            }

            // 3. Экран сбоя сети / отсутствия страницы в кэше
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
    let isInitialCacheCompleted: Bool
    let onProgressUpdate: (Double, String?) -> Void
    let onCacheCompleted: () -> Void

    var currentTimeout: TimeInterval {
        isInitialCacheCompleted ? 12.0 : 60.0
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.userContentController.add(context.coordinator, name: "cacheBridge")

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
        context.coordinator.lastRequestedURL = url

        webState.retryAction = { [weak webView, weak coordinator = context.coordinator] in
            guard let webView = webView, let coordinator = coordinator else { return }
            coordinator.parent.webState.hasError = false
            coordinator.parent.webState.isLoading = true

            let retryURL = coordinator.lastFailedURL ?? coordinator.lastRequestedURL ?? url
            coordinator.startTimeoutTimer(for: retryURL)

            var request = URLRequest(url: retryURL)
            request.cachePolicy = .useProtocolCachePolicy
            webView.load(request)
        }

        context.coordinator.startTimeoutTimer(for: url)
        var initialRequest = URLRequest(url: url)
        initialRequest.cachePolicy = .useProtocolCachePolicy
        webView.load(initialRequest)

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "cacheBridge")
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebViewWrapper
        weak var webView: WKWebView?

        var lastRequestedURL: URL?
        var lastFailedURL: URL?
        private var timeoutWorkItem: DispatchWorkItem?

        init(_ parent: WebViewWrapper) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "cacheBridge" else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                if let dict = message.body as? [String: Any] {
                    let status = dict["status"] as? String ?? ""

                    if status == "savePage",
                       let pageUrlString = dict["url"] as? String,
                       let html = dict["html"] as? String,
                       let pageUrl = URL(string: pageUrlString) {
                        OfflineStorage.shared.save(html: html, for: pageUrl)
                    } else if status == "progress" {
                        let progress = dict["progress"] as? Double ?? 0.0
                        let messageText = dict["message"] as? String
                        self.parent.onProgressUpdate(progress, messageText)
                    } else if status == "completed" {
                        self.parent.onProgressUpdate(1.0, "Обновлено!")
                        self.parent.onCacheCompleted()
                    }
                } else if let text = message.body as? String, text == "completed" {
                    self.parent.onCacheCompleted()
                }
            }
        }

        func startTimeoutTimer(for url: URL? = nil) {
            cancelTimeoutTimer()
            let targetURL = url ?? lastRequestedURL ?? parent.url
            let timeout = parent.currentTimeout

            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self, let currentWebView = self.webView else { return }

                if self.parent.webState.isLoading {
                    currentWebView.stopLoading()

                    if let cachedHTML = OfflineStorage.shared.getHTML(for: targetURL) {
                        self.parent.webState.isLoading = false
                        self.parent.webState.hasError = false
                        currentWebView.loadHTMLString(cachedHTML, baseURL: targetURL)
                        currentWebView.scrollView.refreshControl?.endRefreshing()
                        return
                    }

                    self.showError(
                        for: targetURL,
                        message: "Время ожидания ответа от сервера истекло."
                    )
                }
            }
            self.timeoutWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: workItem)
        }

        func cancelTimeoutTimer() {
            timeoutWorkItem?.cancel()
            timeoutWorkItem = nil
        }

        @objc func handleRefresh() {
            guard let currentWebView = webView else { return }
            let refreshURL = currentWebView.url ?? lastRequestedURL ?? parent.url
            startTimeoutTimer(for: refreshURL)

            var request = URLRequest(url: refreshURL)
            request.cachePolicy = .useProtocolCachePolicy
            currentWebView.load(request)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let requestURL = navigationAction.request.url {
                lastRequestedURL = requestURL
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.webState.isLoading = true
                self.parent.webState.hasError = false
            }
            startTimeoutTimer(for: lastRequestedURL)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            cancelTimeoutTimer()
            DispatchQueue.main.async {
                self.parent.webState.isLoading = false
                self.parent.webState.hasError = false
                webView.scrollView.refreshControl?.endRefreshing()
            }

            if !parent.isInitialCacheCompleted {
                crawlAndCacheAllPages(webView: webView)
            }
        }

        /// Двухуровневый сбор страниц с автоматическим инлайнингом CSS-стилей
        private func crawlAndCacheAllPages(webView: WKWebView) {
            let js = """
            (async function() {
                try {
                    if ('serviceWorker' in navigator) {
                        await navigator.serviceWorker.ready;
                    }

                    if (!('caches' in window)) {
                        window.webkit.messageHandlers.cacheBridge.postMessage({ status: 'completed' });
                        return;
                    }

                    const cacheNames = await caches.keys();
                    const targetCaches = [];
                    if (cacheNames.length > 0) {
                        for (const name of cacheNames) {
                            targetCaches.push(await caches.open(name));
                        }
                    } else {
                        targetCaches.push(await caches.open('v1'));
                    }

                    const targetDomain = 'historydatesapp.qiaelel.ru';
                    const collectedLinks = new Set();
                    const cssCache = new Map();

                    function sanitizeAndAdd(rawUrl, baseUrl) {
                        if (!rawUrl || typeof rawUrl !== 'string') return;
                        try {
                            const parsed = new URL(rawUrl, baseUrl || window.location.href);
                            if (parsed.hostname === targetDomain && (parsed.protocol === 'http:' || parsed.protocol === 'https:')) {
                                parsed.hash = '';
                                collectedLinks.add(parsed.href);
                                if (parsed.pathname === '/' || parsed.pathname === '') {
                                    collectedLinks.add(parsed.origin);
                                    collectedLinks.add(parsed.origin + '/');
                                }
                            }
                        } catch (e) {}
                    }

                    try {
                        const sitemapRes = await fetch('/sitemap.xml');
                        if (sitemapRes.ok) {
                            const xmlText = await sitemapRes.text();
                            const parser = new DOMParser();
                            const xmlDoc = parser.parseFromString(xmlText, 'text/xml');
                            const locs = xmlDoc.querySelectorAll('loc');
                            locs.forEach(loc => sanitizeAndAdd(loc.textContent.trim()));
                        }
                    } catch (e) {}

                    document.querySelectorAll('a[href]').forEach(a => {
                        const href = a.getAttribute('href');
                        if (href) sanitizeAndAdd(href, window.location.href);
                    });

                    sanitizeAndAdd('/', window.location.origin);
                    sanitizeAndAdd(window.location.href);

                    const firstLevelBatch = Array.from(collectedLinks);
                    for (const sectionUrl of firstLevelBatch) {
                        try {
                            const res = await fetch(sectionUrl);
                            if (res.ok) {
                                const html = await res.text();
                                const parser = new DOMParser();
                                const doc = parser.parseFromString(html, 'text/html');
                                doc.querySelectorAll('a[href]').forEach(a => {
                                    const rawHref = a.getAttribute('href');
                                    if (rawHref) sanitizeAndAdd(rawHref, sectionUrl);
                                });
                            }
                        } catch (e) {}
                    }

                    const finalUrls = Array.from(collectedLinks);
                    const total = finalUrls.length;
                    let loaded = 0;

                    if (total === 0) {
                        window.webkit.messageHandlers.cacheBridge.postMessage({ status: 'completed' });
                        return;
                    }

                    window.webkit.messageHandlers.cacheBridge.postMessage({
                        status: 'progress',
                        progress: 0.05,
                        message: 'В процессе: ' + total
                    });

                    for (const pageUrl of finalUrls) {
                        try {
                            const response = await fetch(pageUrl, { cache: 'reload' });
                            if (response.ok) {
                                let htmlText = await response.text();

                                try {
                                    const parser = new DOMParser();
                                    const doc = parser.parseFromString(htmlText, 'text/html');
                                    const linkTags = Array.from(doc.querySelectorAll('link[rel="stylesheet"]'));

                                    for (const link of linkTags) {
                                        const href = link.getAttribute('href');
                                        if (href) {
                                            try {
                                                const cssUrl = new URL(href, pageUrl).href;
                                                let cssContent = cssCache.get(cssUrl);

                                                if (!cssContent) {
                                                    const cssRes = await fetch(cssUrl, { cache: 'reload' });
                                                    if (cssRes.ok) {
                                                        cssContent = await cssRes.text();
                                                        cssCache.set(cssUrl, cssContent);

                                                        for (const c of targetCaches) {
                                                            await c.put(cssUrl, new Response(cssContent, {
                                                                headers: { 'Content-Type': 'text/css' }
                                                            }));
                                                        }
                                                    }
                                                }

                                                if (cssContent) {
                                                    const styleTag = doc.createElement('style');
                                                    styleTag.setAttribute('data-inlined-from', href);
                                                    styleTag.textContent = cssContent;
                                                    link.parentNode.replaceChild(styleTag, link);
                                                }
                                            } catch (cssErr) {
                                                console.warn('Ошибка загрузки CSS:', href, cssErr);
                                            }
                                        }
                                    }

                                    htmlText = '<!DOCTYPE html>\\n' + doc.documentElement.outerHTML;
                                } catch (inlineErr) {
                                    console.warn('Ошибка инлайнинга CSS в страницу:', pageUrl, inlineErr);
                                }

                                for (const c of targetCaches) {
                                    await c.put(pageUrl, new Response(htmlText, {
                                        headers: response.headers,
                                        status: response.status,
                                        statusText: response.statusText
                                    }));
                                }

                                window.webkit.messageHandlers.cacheBridge.postMessage({
                                    status: 'savePage',
                                    url: pageUrl,
                                    html: htmlText
                                });
                            }
                        } catch (err) {
                            console.warn('Пропущен URL:', pageUrl);
                        }

                        loaded++;
                        const currentProgress = total > 0 ? (loaded / total) : 1.0;
                        window.webkit.messageHandlers.cacheBridge.postMessage({
                            status: 'progress',
                            progress: currentProgress,
                            message: 'Обновлено: ' + loaded + ' из ' + total
                        });
                    }

                    window.webkit.messageHandlers.cacheBridge.postMessage({ status: 'completed' });
                } catch (e) {
                    console.error('Ошибка в crawlAndCacheAllPages:', e);
                    window.webkit.messageHandlers.cacheBridge.postMessage({ status: 'completed' });
                }
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            cancelTimeoutTimer()
            handleError(error, webView: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            cancelTimeoutTimer()
            handleError(error, webView: webView)
        }

        private func handleError(_ error: Error, webView: WKWebView) {
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled {
                return
            }

            let failingURL = (nsError.userInfo[NSURLErrorFailingURLErrorKey] as? URL)
                ?? (nsError.userInfo["NSErrorFailingURLStringKey"] as? String).flatMap { URL(string: $0) }
                ?? lastRequestedURL
                ?? webView.url
                ?? parent.url

            if let cachedHTML = OfflineStorage.shared.getHTML(for: failingURL) {
                cancelTimeoutTimer()
                DispatchQueue.main.async {
                    self.parent.webState.isLoading = false
                    self.parent.webState.hasError = false
                    webView.loadHTMLString(cachedHTML, baseURL: failingURL)
                    webView.scrollView.refreshControl?.endRefreshing()
                }
                return
            }

            showError(for: failingURL, message: error.localizedDescription)
        }

        private func showError(for url: URL, message: String) {
            lastFailedURL = url
            DispatchQueue.main.async {
                self.parent.webState.isLoading = false
                self.parent.webState.hasError = true
                self.parent.webState.errorMessage = message
                if let currentWebView = self.webView {
                    currentWebView.scrollView.refreshControl?.endRefreshing()
                }
            }
        }
    }
}
