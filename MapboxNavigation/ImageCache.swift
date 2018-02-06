import Foundation

class ImageCache: BimodalImageCache {

    let memoryCache: NSCache<NSString, UIImage>
    let diskCacheURL: URL = {
        let fileManager = FileManager.default
        let basePath = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return basePath.appendingPathComponent("com.mapbox.directions.downloadedImages")
    }()

    let diskAccessQueue = DispatchQueue(label: "com.mapbox.directions.diskAccess")
    var fileManager: FileManager?

    init() {
        memoryCache = NSCache<NSString, UIImage>()
        memoryCache.name = "In-Memory Image Cache"

        diskAccessQueue.sync {
            fileManager = FileManager()
        }

        //TODO: register for UIApplicationDidReceiveMemoryWarningNotification and clear memory cache
    }

    deinit {
        // TODO: un-register for memory notifications
    }

    func store(_ image: UIImage?, forKey key: String?, toDisk: Bool, completion: NoArgBlock?) {
        guard let image = image, let key = key else {
            return
        }

        memoryCache.setObject(image, forKey: key as NSString, cost: cacheCostForImage(image))

        let dispatchCompletion = {
            if let completion = completion {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }

        if toDisk == true {
            diskAccessQueue.async {
                self.createCacheDirIfNeeded()

                let data = UIImagePNGRepresentation(image)
                let cacheURL = self.cacheURLWithKey(key)

                do {
                    try data?.write(to: cacheURL)
                } catch {
                    NSLog("================> Failed to write data to URL \(cacheURL)")
                    dispatchCompletion()
                }
                dispatchCompletion()
            }
        } else {
            dispatchCompletion()
        }
    }

    private func cachePathWithKey(_ key: String) -> String {
        return cacheURLWithKey(key).absoluteString
    }

    private func cacheURLWithKey(_ key: String) -> URL {
        return diskCacheURL.appendingPathComponent(key)
    }

    func imageFromCache(forKey key: String?) -> UIImage? {
        if let image = imageFromMemoryCache(forKey: key) {
            return image
        }
        return imageFromDiskCache(forKey: key)
    }

    func clearMemory() {
        memoryCache.removeAllObjects()
    }

    func clearDisk(onCompletion completion: NoArgBlock?) {
        self.diskAccessQueue.async {
            do {
                try self.fileManager!.removeItem(at: self.diskCacheURL)
            } catch {
                NSLog("================> Failed to remove cache dir: \(self.diskCacheURL)")
            }

            self.createCacheDirIfNeeded()

            if let completion = completion {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }

    private func imageFromMemoryCache(forKey key: String?) -> UIImage? {
        guard let key = key as NSString! else {
            return nil
        }
        return memoryCache.object(forKey: key)
    }

    private func imageFromDiskCache(forKey key: String?) -> UIImage? {
        do {
            let data = try Data.init(contentsOf: self.cacheURLWithKey(key!))
            //TODO: store in memory cache
            return UIImage.init(data: data)
        } catch {
            NSLog("================> Failed to load data at URL: \(self.cacheURLWithKey(key!))")
            return nil
        }
    }

    private func cacheCostForImage(_ image: UIImage) -> Int {
        return Int(image.size.height * image.size.width * image.scale * image.scale);
    }

    private func createCacheDirIfNeeded() {
        if fileManager!.fileExists(atPath: diskCacheURL.absoluteString) == false {
            do {
                try self.fileManager!.createDirectory(at: self.diskCacheURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                // TODO: unsure of the best strategy to catch/handle this case at the moment
                NSLog("================> Failed to create directory: \(diskCacheURL)")
            }
        }
    }
}
