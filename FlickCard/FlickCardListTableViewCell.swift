//
//  FlickCardListTableViewCell.swift
//  FlickCard
//
//  Created by Ben Gottlieb on 10/2/18.
//  Copyright © 2018 Ben Gottlieb. All rights reserved.
//

import UIKit

class FlickCardListTableViewCell: UITableViewCell {
	static let identifier = "FlickCardListTableViewCell"
	var card: FlickCard? { didSet { if self.card != oldValue || self.cardView?.superview != self.contentView { self.updateUI() }}}
	var cardView: FlickCardView?
	var heightConstraint: NSLayoutConstraint!
	var listViewController: FlickCardListViewController?
	override var backgroundColor: UIColor? { didSet { self.contentView.backgroundColor = self.backgroundColor }}
	
	func updateUI() {
		guard let insets = self.listViewController?.cardInset else { return }
		self.cardView?.removeFromSuperview()
		if self.heightConstraint == nil {
			self.heightConstraint = self.contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60)
			self.heightConstraint.isActive = true
		}
		
		guard let card = self.card else { return }
		self.cardView = card.viewController.cardView
		self.cardView?.cardParentController = self.listViewController

		if let controller = self.listViewController {
			self.backgroundColor = controller.tableView.backgroundColor
			self.cardView?.layer.cornerRadius = controller.cardCornerRadius
			self.cardView?.layer.borderWidth = controller.cardBorderWidth
			self.cardView?.layer.borderColor = controller.cardBorderColor.cgColor
			self.cardView?.layer.masksToBounds = true
		}
		
		self.contentView.addSubview(self.cardView!)
		self.cardView!.translatesAutoresizingMaskIntoConstraints = false
		self.cardView!.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: insets.left).isActive = true
		self.cardView!.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: -insets.right).isActive = true
		self.cardView!.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: insets.top).isActive = true
		self.cardView!.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -insets.bottom).isActive = true
		
		
	}
}
