//
// Copyright (C) 2019 Muhammad Tayyab Akram
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import TehreerCocoa
import UIKit

private enum SegueID {
    static let showTypefaces = "ShowTypefaces"
    static let showGlyphInfo = "ShowGlyphInfo"
}

class GlyphShapeView: UIView {
    var renderer: Renderer! {
        didSet { setNeedsDisplay() }
    }

    var glyphID: UInt16 = .zero {
        didSet { setNeedsDisplay() }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(),
              let renderer = renderer,
              let typeface = renderer.typeface else {
                return
        }

        let sizeByEm = renderer.typeSize / CGFloat(typeface.unitsPerEm)
        let fontAscent = CGFloat(typeface.ascent) * sizeByEm
        let fontDscent = CGFloat(typeface.descent) * sizeByEm
        let fontHeight = fontAscent + fontDscent

        let glyphBounds = renderer.computeBoundingBox(forGlyph: glyphID)
        let glyphX = round((bounds.width - glyphBounds.width) / 2.0 - glyphBounds.minX)
        let glyphY = round((bounds.height - fontHeight) / 2.0 + fontAscent)

        context.translateBy(x: glyphX, y: glyphY)
        renderer.drawGlyphs(in: context, glyphIDs: [glyphID], offsets: [.zero], advances: [.zero])
        context.translateBy(x: -glyphX, y: -glyphY)
    }
}

class GlyphPreviewCell: UICollectionViewCell {
    @IBOutlet private weak var glyphIDLabel: UILabel!
    @IBOutlet private weak var glyphShapeView: GlyphShapeView!

    func configure(with renderer: Renderer, glyphID: UInt16) {
        glyphIDLabel.text = String(format: "%04X", glyphID)
        glyphShapeView.renderer = renderer
        glyphShapeView.glyphID = glyphID
    }
}

class TypefaceGlyphsViewController: UIViewController, UIScrollViewDelegate, UICollectionViewDataSource, UICollectionViewDelegate {
    @IBOutlet private weak var collectionView: UICollectionView!
    @IBOutlet private weak var typefaceLabel: UILabel!
    @IBOutlet private weak var headerTopConstraint: NSLayoutConstraint!

    private var renderer = Renderer()

    override func viewDidLoad() {
        super.viewDidLoad()

        renderer.renderScale = UIScreen.main.scale
        renderer.typeSize = 28.0

        selectTypeface(TypefaceManager.default.availableTypefaces.first)
    }

    private func selectTypeface(_ typeface: Typeface!) {
        typefaceLabel.text = typeface.familyName
        renderer.typeface = typeface

        collectionView.reloadData()
        collectionView.setContentOffset(.zero, animated: false)
    }

    // MARK: - UIScrollViewDelegate

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        var safeInsets = UIEdgeInsets.zero
        if #available(iOS 11.0, *) {
            safeInsets = collectionView.safeAreaInsets
        }

        let topInset = collectionView.contentInset.top + safeInsets.top
        let contentOffset = collectionView.contentOffset

        headerTopConstraint.constant = max(.zero, -(contentOffset.y + topInset))
    }

    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return renderer.typeface.glyphCount
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "\(GlyphPreviewCell.self)", for: indexPath) as! GlyphPreviewCell
        cell.configure(with: renderer, glyphID: UInt16(indexPath.row))

        return cell
    }

    // MARK: UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        performSegue(withIdentifier: SegueID.showGlyphInfo, sender: indexPath.row)
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case SegueID.showTypefaces:
            let typefacesViewController = segue.destination as! AvailableTypefacesViewController
            typefacesViewController.setup(selectedTypeface: renderer.typeface, onSelectionChanged: {
                self.selectTypeface(typefacesViewController.selectedTypeface)
            })

        case SegueID.showGlyphInfo:
            let infoViewController = segue.destination as! GlyphInfoViewController
            infoViewController.setup(typeface: renderer.typeface, glyphID: sender as! UInt16)

        default: break
        }
    }
}
