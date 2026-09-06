import AppKit
import WebKit

final class SwipeVerifier: NSObject, WKNavigationDelegate {
    private let webView: WKWebView
    private let outputURL: URL
    private var loadedFixture = false

    init(webView: WKWebView, outputURL: URL) {
        self.webView = webView
        self.outputURL = outputURL
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if !loadedFixture {
            loadedFixture = true
            let now = Int(Date().timeIntervalSince1970 * 1_000)
            let fixture: [String: Any] = [
                "version": 1,
                "activeNoteId": "first",
                "theme": "light",
                "notes": [
                    ["id": "first", "content": "第一条文稿\n正文内容", "createdAt": now, "updatedAt": now],
                    ["id": "second", "content": "不会重叠\n删除按钮与文字必须完全分开", "createdAt": now - 1_000, "updatedAt": now - 1_000],
                ],
            ]
            let data = try! JSONSerialization.data(withJSONObject: fixture)
            let json = String(data: data, encoding: .utf8)!
            let encoded = try! JSONEncoder().encode(json)
            let quotedJSON = String(data: encoded, encoding: .utf8)!
            webView.evaluateJavaScript("localStorage.setItem('moment-workspace-v1', \(quotedJSON)); location.reload()")
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            let revealScript = """
            (() => {
              const shell = document.querySelectorAll('.note-item-shell')[1];
              if (!shell) throw new Error('fixture note was not rendered');
              shell.dataset.testRevealed = 'true';
              const style = document.createElement('style');
              style.textContent = `
                .note-item-shell[data-test-revealed] .note-item-delete {
                  width: 62px !important;
                  transition: none !important;
                }
                .note-item-shell[data-test-revealed] .note-item {
                  border-radius: 0 9px 9px 0;
                }
              `;
              document.head.appendChild(style);
            })()
            """
            webView.evaluateJavaScript(revealScript) { _, error in
                if let error {
                    fputs("Swipe injection failed: \(error)\n", stderr)
                    NSApplication.shared.terminate(nil)
                    return
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.verifyAndSnapshot()
                }
            }
        }
    }

    private func verifyAndSnapshot() {
        let measureScript = """
        (() => {
          const shell = document.querySelectorAll('.note-item-shell')[1];
          const action = shell.querySelector('.note-item-delete').getBoundingClientRect();
          const content = shell.querySelector('.note-item').getBoundingClientRect();
          return JSON.stringify({
            actionWidth: action.width,
            actionRight: action.right,
            contentLeft: content.left,
            overlap: Math.max(0, action.right - content.left),
          });
        })()
        """
        webView.evaluateJavaScript(measureScript) { [self] result, error in
            if let error {
                fputs("Measurement failed: \(error)\n", stderr)
                NSApplication.shared.terminate(nil)
                return
            }
            print(result as? String ?? "missing measurement")
            webView.takeSnapshot(with: nil) { image, error in
                if let error {
                    fputs("Snapshot failed: \(error)\n", stderr)
                    NSApplication.shared.terminate(nil)
                    return
                }
                guard
                    let tiff = image?.tiffRepresentation,
                    let bitmap = NSBitmapImageRep(data: tiff),
                    let png = bitmap.representation(using: .png, properties: [:])
                else {
                    fputs("Snapshot encoding failed\n", stderr)
                    NSApplication.shared.terminate(nil)
                    return
                }
                try! png.write(to: outputURL)
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

guard CommandLine.arguments.count == 3, let pageURL = URL(string: CommandLine.arguments[1]) else {
    fputs("usage: verify-swipe.swift <url> <output.png>\n", stderr)
    exit(2)
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

let configuration = WKWebViewConfiguration()
let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 980, height: 680), configuration: configuration)
let window = NSWindow(
    contentRect: webView.frame,
    styleMask: [.borderless],
    backing: .buffered,
    defer: false
)
window.contentView = webView

let verifier = SwipeVerifier(webView: webView, outputURL: URL(fileURLWithPath: CommandLine.arguments[2]))
webView.navigationDelegate = verifier
webView.load(URLRequest(url: pageURL))
app.run()
