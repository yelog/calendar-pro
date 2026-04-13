import AppKit
import Foundation

protocol URLHandling {
    @discardableResult
    func open(_ url: URL) -> Bool
}

struct WorkspaceURLHandler: URLHandling {
    @discardableResult
    func open(_ url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }
}

struct MeetingActionOpener {
    let urlHandler: URLHandling

    init(urlHandler: URLHandling = WorkspaceURLHandler()) {
        self.urlHandler = urlHandler
    }

    @discardableResult
    func open(_ action: MeetingAction) -> Bool {
        open(action.openPlan)
    }

    @discardableResult
    func open(_ plan: MeetingActionOpenPlan) -> Bool {
        switch plan {
        case .direct(let url):
            return urlHandler.open(url)
        case .ordered(let primary, let fallback):
            for url in primary where urlHandler.open(url) {
                return true
            }

            if let fallback {
                return urlHandler.open(fallback)
            }

            return false
        }
    }
}
