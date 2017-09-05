// Copyright (c) 2017 Token Browser, Inc
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import Foundation
import UIKit
import SweetUIKit

protocol BrowseCellSelectionDelegate: class {
    func seeAll(for contentSection: BrowseContentSection)
    func didSelectItem(at indexPath: IndexPath, collectionView: SectionedCollectionView)
}

class SectionedCollectionView: UICollectionView {
    var section: Int = 0
}

class BrowseCell: UICollectionViewCell {

    let horizontalInset: CGFloat = 10

    weak var selectionDelegate: BrowseCellSelectionDelegate?

    private lazy var layout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        layout.estimatedItemSize = UICollectionViewFlowLayoutAutomaticSize

        return layout
    }()

    private(set) lazy var collectionView: SectionedCollectionView = {
        let view = SectionedCollectionView(frame: .zero, collectionViewLayout: self.layout)
        view.delaysContentTouches = false
        view.isPagingEnabled = false
        view.backgroundColor = nil
        view.isOpaque = false
        view.alwaysBounceHorizontal = true
        view.showsHorizontalScrollIndicator = true
        view.contentInset = UIEdgeInsets(top: 0, left: self.horizontalInset, bottom: 0, right: self.horizontalInset)
        view.delegate = self
        view.register(BrowseAppCell.self)

        return view
    }()

    private(set) lazy var titleLabel: UILabel = {
        let view = UILabel()
        view.font = Theme.regular(size: 17)
        view.textColor = Theme.darkTextColor

        return view
    }()

    private lazy var seeAllButton: UIButton = {
        let view = UIButton()
        view.titleLabel?.font = Theme.regular(size: 17)
        view.setTitleColor(Theme.tintColor, for: .normal)
        view.setTitle(Localized("browse-more-button"), for: .normal)
        view.addTarget(self, action: #selector(seeAllButtonTapped(_:)), for: .touchUpInside)

        return view
    }()

    lazy var divider: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.borderColor

        return view
    }()

    var contentSection: BrowseContentSection? {
        didSet {
            guard let contentSection = contentSection else { return }
            titleLabel.text = contentSection.title
        }
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        contentView.clipsToBounds = true
        backgroundColor = Theme.viewBackgroundColor

        addSubviewsAndConstraints()
    }

    private func addSubviewsAndConstraints() {
        contentView.addSubview(collectionView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(seeAllButton)
        contentView.addSubview(divider)

        collectionView.edges(to: contentView)

        titleLabel.origin(to: contentView, insets: CGVector(dx: 15, dy: 20))

        seeAllButton.top(to: contentView, offset: 8)
        seeAllButton.right(to: contentView, offset: -15)
        seeAllButton.height(44)

        divider.height(Theme.borderHeight)
        divider.left(to: self, offset: 15)
        divider.right(to: self)
        divider.bottom(to: contentView)
    }

    func seeAllButtonTapped(_: UIButton) {
        guard let contentSection = contentSection else { return }

        selectionDelegate?.seeAll(for: contentSection)
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        titleLabel.text = nil
    }
}

extension BrowseCell: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        if let collectionView = collectionView as? SectionedCollectionView {
            selectionDelegate?.didSelectItem(at: indexPath, collectionView: collectionView)
        }
    }
}
