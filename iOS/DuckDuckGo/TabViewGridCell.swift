//
//  TabViewGridCell.swift
//  DuckDuckGo
//
//  Copyright © 2017 DuckDuckGo. All rights reserved.
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
import DuckPlayer

class TabViewGridCell: TabViewCell {

    struct Constants {
        
        static let swipeToDeleteAlpha: CGFloat = 0.5
        
        static let cellCornerRadius: CGFloat = 8.0
        static let cellHeaderHeight: CGFloat = 38.0
        static let cellLogoSize: CGFloat = 68.0
        
    }
    
    static let reuseIdentifier = "TabViewGridCell"

    @IBOutlet weak var background: UIView!
    @IBOutlet weak var border: UIView!
    @IBOutlet weak var favicon: UIImageView!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var removeButton: UIButton!
    @IBOutlet weak var unread: UIImageView!
    @IBOutlet weak var preview: UIImageView!
    @IBOutlet weak var selectionIndicator: UIImageView!

    weak var previewAspectRatio: NSLayoutConstraint?
    @IBOutlet var previewTopConstraint: NSLayoutConstraint?
    @IBOutlet var previewBottomConstraint: NSLayoutConstraint?
    @IBOutlet var previewTrailingConstraint: NSLayoutConstraint?
    
    override func setupSubviews() {
        super.setupSubviews()

        unread.tintColor = .cornflowerBlue
    }
    
    private func updatePreviewToDisplay(image: UIImage) {
        let imageAspectRatio = image.size.height / image.size.width
        let containerAspectRatio = (background.bounds.height - TabViewGridCell.Constants.cellHeaderHeight) / background.bounds.width
        
        let strechContainerVerically = containerAspectRatio < imageAspectRatio
        
        if let constraint = previewAspectRatio {
            preview.removeConstraint(constraint)
        }
        
        previewTopConstraint?.constant = Constants.cellHeaderHeight
        previewBottomConstraint?.isActive = !strechContainerVerically
        previewTrailingConstraint?.isActive = strechContainerVerically
        
        previewAspectRatio = preview.heightAnchor.constraint(equalTo: preview.widthAnchor, multiplier: imageAspectRatio)
        previewAspectRatio?.isActive = true
    }
    
    private func updatePreviewToDisplayLogo() {
        if let constraint = previewAspectRatio {
            preview.removeConstraint(constraint)
            previewAspectRatio = nil
        }
        
        previewTopConstraint?.constant = 0
        previewBottomConstraint?.isActive = true
        previewTrailingConstraint?.isActive = true
    }
    
    private static var unreadImageAsset: UIImageAsset {

        func unreadImage(for style: UIUserInterfaceStyle) -> UIImage {
            let color = ThemeManager.shared.currentTheme.tabSwitcherCellBackgroundColor.resolvedColor(with: .init(userInterfaceStyle: style))
            let image = UIImage.stackedIconImage(withIconImage: UIImage(named: "TabUnread")!,
                                                 borderWidth: 6.0,
                                                 foregroundColor: .cornflowerBlue,
                                                 borderColor: color)
            return image
        }

        let asset = UIImageAsset()

        asset.register(unreadImage(for: .dark), with: .init(userInterfaceStyle: .dark))
        asset.register(unreadImage(for: .light), with: .init(userInterfaceStyle: .light))

        return asset
    }
    
    static let logoImage: UIImage = {
        let image = UIImage(named: "Logo")!
        let renderFormat = UIGraphicsImageRendererFormat.default()
        renderFormat.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: Constants.cellLogoSize,
                                                            height: Constants.cellLogoSize),
                                               format: renderFormat)
        return renderer.image { _ in
            image.draw(in: CGRect(x: 0,
                                  y: 0,
                                  width: Constants.cellLogoSize,
                                  height: Constants.cellLogoSize))
        }
    }()
    
    override func update(withTab tab: Tab,
                         isSelectionModeEnabled: Bool,
                         preview: UIImage?) {
        accessibilityElements = [ title as Any, removeButton as Any ]
        
        self.tab = tab
        self.isSelectionModeEnabled = isSelectionModeEnabled
        
        if !isDeleting {
            isHidden = false
        }
        isCurrent = delegate?.isCurrent(tab: tab) ?? false
        
        decorate()

        updateCurrentTabBorder(border)

        if let link = tab.link {
            removeButton.accessibilityLabel = UserText.closeTab(withTitle: link.displayTitle, atAddress: link.url.host ?? "")
            title.accessibilityLabel = UserText.openTab(withTitle: link.displayTitle, atAddress: link.url.host ?? "")
            title.text = tab.link?.displayTitle
        }
        
        unread.isHidden = tab.viewed

        if tab.link == nil {
            updatePreviewToDisplayLogo()
            self.preview.image = Self.logoImage
            self.preview.contentMode = .center
            
            title.text = UserText.homeTabTitle
            favicon.image = UIImage(named: "Logo")
            unread.isHidden = true
            self.preview.isHidden = !tab.viewed
            title.isHidden = !tab.viewed
            favicon.isHidden = !tab.viewed
            removeButton.isHidden = !tab.viewed
            
        } else {
            
            // Duck Player videos
            if let url = tab.link?.url, url.isDuckPlayer {
                favicon.image = UIImage(named: "DuckPlayerURLIcon")
            } else {
                favicon.loadFavicon(forDomain: tab.link?.url.host, usingCache: .tabs)
            }
            
            if let preview = preview {
                self.updatePreviewToDisplay(image: preview)
                self.preview.contentMode = .scaleAspectFill
                self.preview.image = preview
            } else {
                self.preview.image = nil
            }
            
            removeButton.isHidden = false
            
        }

        updateUIForSelectionMode(removeButton, selectionIndicator)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            setBorderColor()
        }
    }

    private func decorate() {
        let theme = ThemeManager.shared.currentTheme
        setBorderColor()
        unread.image = Self.unreadImageAsset.image(with: .current)

        background.backgroundColor = theme.tabSwitcherCellBackgroundColor
        title.textColor = theme.tabSwitcherCellTextColor
    }

    private func setBorderColor() {
        border.layer.borderColor = ThemeManager.shared.currentTheme.tabSwitcherCellBorderColor.cgColor
    }

}
