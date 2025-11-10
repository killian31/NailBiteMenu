import Foundation
import Combine

final class HabitTracker: ObservableObject {
    
    @Published var detections: [Date] = []
    
    private let storageURL: URL

    init() {
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Could not find Application Support directory.")
        }
        
        let appDirectoryURL = appSupportURL.appendingPathComponent("NailBiteMenu", isDirectory: true)
        
        self.storageURL = appDirectoryURL.appendingPathComponent("nailbite_stats.json")
        
        do {
            try FileManager.default.createDirectory(at: appDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Error creating app support directory: \(error)")
        }
        
        loadDetections()
    }
    
    func addDetection(at date: Date = Date()) {
        detections.append(date)
        saveDetections()
    }
    
    func clearAllData() {
        detections = []
        saveDetections()
    }

    private func loadDetections() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            print("No stats file found, starting fresh.")
            return
        }
        
        do {
            let data = try Data(contentsOf: storageURL)
            let loadedDetections = try JSONDecoder().decode([Date].self, from: data)
            
            DispatchQueue.main.async {
                self.detections = loadedDetections
                print("Successfully loaded \(loadedDetections.count) detections.")
            }
        } catch {
            print("Failed to load or decode stats file: \(error)")
        }
    }
    
    private func saveDetections() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let data = try JSONEncoder().encode(self.detections)
                try data.write(to: self.storageURL, options: .atomic)
            } catch {
                print("Failed to save stats file: \(error)")
            }
        }
    }
}
