//
//  FaviconsHelper.swift
//  DuckDuckGo
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import UIKit
import Core
import Kingfisher
import Common
import DesignResourcesKit

struct FaviconsHelper {

    private static let tld: TLD = AppDependencyProvider.shared.storageCache.tld

    static func loadFaviconSync(forDomain domain: String?,
                                usingCache cacheType: FaviconsCacheType,
                                useFakeFavicon: Bool,
                                preferredFakeFaviconLetters: String? = nil) -> (image: UIImage?, isFake: Bool) {

        // Handle special cases first
        if domain == "player" {
            let image = UIImage(named: "DuckPlayerURLIcon")
            image?.accessibilityIdentifier = "DuckPlayerURLIcon"
            return (image, false)
        }

        if URL.isDuckDuckGo(domain: domain) {
            let image = UIImage(named: "Logo")
            image?.accessibilityIdentifier = "Logo"
            return (image, false)
        }

        // Check cache and resource availability
        guard let cache = Favicons.Constants.caches[cacheType],
              let resource = Favicons.shared.defaultResource(forDomain: domain) else {
            return createFallbackResult(domain: domain,
                                      useFakeFavicon: useFakeFavicon,
                                      preferredLetters: preferredFakeFaviconLetters)
        }

        // Try memory cache first
        if let cachedImage = cache.retrieveImageInMemoryCache(forKey: resource.cacheKey) {
            return (cachedImage, false)
        }

        // Try loading from disk with proper error handling
        do {
            let url = cache.diskStorage.cacheFileURL(forKey: resource.cacheKey)

            guard FileManager.default.fileExists(atPath: url.path) else {
                return createFallbackResult(domain: domain,
                                          useFakeFavicon: useFakeFavicon,
                                          preferredLetters: preferredFakeFaviconLetters)
            }

            let data = try Data(contentsOf: url, options: [.uncached])
            guard let image = UIImage(data: data) else {
                Logger.general.error("Failed to create image from data for domain: \(domain ?? "unknown")")
                return createFallbackResult(domain: domain,
                                          useFakeFavicon: useFakeFavicon,
                                          preferredLetters: preferredFakeFaviconLetters)
            }

            // Store in memory cache with original expiry date
            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               let fileModificationDate = attributes[.modificationDate] as? Date {

                cache.store(image,
                           forKey: resource.cacheKey,
                           options: KingfisherParsedOptionsInfo([
                            .cacheMemoryOnly,
                            .diskCacheAccessExtendingExpiration(.none),
                            .memoryCacheExpiration(.date(fileModificationDate))
                           ]),
                           toDisk: false)
            }

            return (image, false)

        } catch {
            Logger.general.error("Failed to load favicon from disk for domain: \(domain ?? "unknown"), error: \(error)")
            return createFallbackResult(domain: domain,
                                      useFakeFavicon: useFakeFavicon,
                                      preferredLetters: preferredFakeFaviconLetters)
        }
    }

    static func loadFaviconSync(forDomain domain: String?,
                                usingCache cacheType: FaviconsCacheType,
                                useFakeFavicon: Bool,
                                preferredFakeFaviconLetters: String? = nil,
                                completion: ((UIImage?, Bool) -> Void)? = nil) {
        let result = loadFaviconSync(forDomain: domain, usingCache: cacheType, useFakeFavicon: useFakeFavicon, preferredFakeFaviconLetters: preferredFakeFaviconLetters)

        completion?(result.image, result.isFake)
    }

    static func createFakeFavicon(forDomain domain: String,
                                  size: CGFloat = 192,
                                  backgroundColor: UIColor = UIColor(baseColor: .gray70),
                                  bold: Bool = true,
                                  preferredFakeFaviconLetters: String? = nil,
                                  letterCount: Int = 2) -> UIImage? {

        let cornerRadius = size * 0.125
        let imageRect = CGRect(x: 0, y: 0, width: size, height: size)
        let padding = size * 0.16
        let labelFrame = CGRect(x: padding, y: padding, width: imageRect.width - (2 * padding), height: imageRect.height - (2 * padding))

        let renderer = UIGraphicsImageRenderer(size: imageRect.size)
        let icon = renderer.image { imageContext in
            let context = imageContext.cgContext

            context.setFillColor(backgroundColor.cgColor)
            context.addPath(CGPath(roundedRect: imageRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
            context.fillPath()

            let label = UILabel(frame: labelFrame)
            label.numberOfLines = 1
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.1
            label.baselineAdjustment = .alignCenters
            label.font = bold ? UIFont.boldAppFont(ofSize: size) : UIFont.appFont(ofSize: size)
            label.textColor = UIColor.white
            label.textAlignment = .center

            if let prefferedPrefix = preferredFakeFaviconLetters?.droppingWwwPrefix().prefix(letterCount).capitalized {
                label.text = prefferedPrefix
            } else {
                label.text = String(tld.eTLDplus1(domain)?.prefix(letterCount) ?? "#").capitalized
            }

            context.translateBy(x: padding, y: padding)

            label.layer.draw(in: context)
        }
         
        return icon.withRenderingMode(.alwaysOriginal)
    }

    // this function is now static and outside of Favicons, otherwise there is a circular dependency between
    // Favicons and NotFoundCachingDownloader
    public static func defaultResource(forDomain domain: String?, sourcesProvider: FaviconSourcesProvider) -> KF.ImageResource? {
        guard let domain = domain,
              let source = sourcesProvider.mainSource(forDomain: domain) else { return nil }

        let key = FaviconHasher.createHash(ofDomain: domain)
        return KF.ImageResource(downloadURL: source, cacheKey: key)
    }

    private static func createFallbackResult(domain: String?,
                                             useFakeFavicon: Bool,
                                             preferredLetters: String?) -> (UIImage?, Bool) {
        guard useFakeFavicon,
              let domain = domain else {
            return (nil, false)
        }

        let fakeFavicon = createFakeFavicon(forDomain: domain,
                                           backgroundColor: UIColor.forDomain(domain),
                                           preferredFakeFaviconLetters: preferredLetters)
        return (fakeFavicon, true)
    }

}
