import AppKit
import ScreenCaptureKit

/// Captura de miniaturas de janelas via ScreenCaptureKit (macOS 14+). Exige Screen Recording.
/// Sem permissão ou em erro, devolve nil e o card mostra só ícone + título.
final class PreviewService {
    static let shared = PreviewService()
    private var cache: [CGWindowID: (image: CGImage, at: Date)] = [:]
    private let ttl: TimeInterval = 1.0
    private var inFlight: Set<CGWindowID> = []
    private var contentCache: (content: SCShareableContent, at: Date)?

    /// Lista de janelas capturáveis, reutilizada por 1 s para não enumerar o sistema a cada card.
    private func shareableContent() async throws -> SCShareableContent {
        if let c = contentCache, Date().timeIntervalSince(c.at) < ttl { return c.content }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        await MainActor.run { contentCache = (content, Date()) }
        return content
    }

    func cached(_ id: CGWindowID) -> CGImage? {
        guard let c = cache[id], Date().timeIntervalSince(c.at) < ttl else { return nil }
        return c.image
    }

    /// Captura assíncrona; o completion roda na main thread.
    func capture(_ id: CGWindowID, maxSize: CGSize, completion: @escaping (CGImage?) -> Void) {
        if let img = cached(id) { completion(img); return }
        guard PermissionGate.screenRecording, !inFlight.contains(id) else { completion(nil); return }
        inFlight.insert(id)
        Task { [weak self] in
            var result: CGImage? = nil
            do {
                let content = try await self?.shareableContent()
                if let win = content?.windows.first(where: { $0.windowID == id }) {
                    let filter = SCContentFilter(desktopIndependentWindow: win)
                    let config = SCStreamConfiguration()
                    let scale = min(maxSize.width / max(win.frame.width, 1), maxSize.height / max(win.frame.height, 1), 1)
                    config.width = max(Int(win.frame.width * scale * 2), 2)
                    config.height = max(Int(win.frame.height * scale * 2), 2)
                    config.showsCursor = false
                    config.ignoreShadowsSingleWindow = true
                    result = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                }
            } catch {
                Log.warn("preview falhou para uma janela (\(error.localizedDescription))")
            }
            let image = result
            await MainActor.run {
                self?.inFlight.remove(id)
                if let image = image { self?.cache[id] = (image, Date()) }
                completion(image)
            }
        }
    }

    func purge() { cache.removeAll() }
}
