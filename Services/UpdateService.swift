import Foundation
import os.log

struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let body: String
    let htmlUrl: String
    let assets: [Asset]
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case assets
    }
    
    struct Asset: Codable {
        let browserDownloadUrl: String
        let name: String
        
        enum CodingKeys: String, CodingKey {
            case browserDownloadUrl = "browser_download_url"
            case name
        }
    }
}

class UpdateService: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ReportBuddy", category: "UpdateService")
    static let shared = UpdateService()
    
    @Published var updateAvailable = false
    @Published var latestVersion: String?
    @Published var releaseNotes: String?
    @Published var downloadURL: String?
    
    private let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let githubAPI = "https://api.github.com/repos/philsaino/ReportBuddy/releases/latest"
    
    func checkForUpdates() async {
        do {
            guard let url = URL(string: githubAPI) else {
                logger.error("URL API GitHub non valido")
                return
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            
            await MainActor.run {
                let latestVersion = release.tagName.replacingOccurrences(of: "v", with: "")
                if compareVersions(latestVersion, isGreaterThan: currentVersion) {
                    self.updateAvailable = true
                    self.latestVersion = latestVersion
                    self.releaseNotes = release.body
                    if let dmgAsset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }) {
                        self.downloadURL = dmgAsset.browserDownloadUrl
                    } else {
                        self.downloadURL = release.htmlUrl
                    }
                }
            }
        } catch {
            logger.error("Errore nel controllo aggiornamenti: \(error.localizedDescription)")
        }
    }
    
    private func compareVersions(_ version1: String, isGreaterThan version2: String) -> Bool {
        let v1Components = version1.split(separator: ".").compactMap { Int($0) }
        let v2Components = version2.split(separator: ".").compactMap { Int($0) }
        
        let maxLength = max(v1Components.count, v2Components.count)
        let v1Padded = v1Components + Array(repeating: 0, count: maxLength - v1Components.count)
        let v2Padded = v2Components + Array(repeating: 0, count: maxLength - v2Components.count)
        
        for i in 0..<maxLength {
            if v1Padded[i] > v2Padded[i] {
                return true
            } else if v1Padded[i] < v2Padded[i] {
                return false
            }
        }
        return false
    }
} 