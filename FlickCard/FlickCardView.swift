//
//  FlickCard.View.swift
//  Cards
//
//  Created by Ben Gottlieb on 9/22/18.
//  Copyright © 2018 Ben Gottlieb. All rights reserved.
//

import UIKit

open class FlickCardView: UIView {
	public weak var card: FlickCard!
	
	static var cornerRadius: CGFloat = 10
	static var borderWidth: CGFloat = 1
	static var borderColor: UIColor = .black

	var stackView: FlickCardStackView?
	var cardController: FlickCardViewController!
	
	var panGestureRecognizer: UIPanGestureRecognizer?
	var dragStart = CGPoint.zero

	public override init(frame: CGRect) {
		super.init(frame: frame)
		self.didInit()
	}
	
	public required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		self.didInit()
	}
	
	open override func didMoveToSuperview() {
		super.didMoveToSuperview()
		if let stack = self.superview as? FlickCardStackView {
			self.stackView = stack
		}
	}
	
	func didInit() {
		self.layer.cornerRadius = FlickCardView.cornerRadius
		self.layer.borderColor = FlickCardView.borderColor.cgColor
		self.layer.borderWidth = FlickCardView.borderWidth
		
		self.percentageLifted = 0.0
	}

	func transformForAnimation(in parent: FlickCardStackView, location pt: CGPoint) {
		let angle = pt.x > parent.bounds.midX ? parent.maxDragRotation : -parent.maxDragRotation
		self.transform = CGAffineTransform(rotationAngle: angle)
		self.percentageLifted = 1.0
	}
}

extension CGPoint {
	var magnitudeFromOrigin: CGFloat {
		return sqrt(self.x * self.x + self.y * self.y)
	}
	
	func distance(to other: CGPoint) -> CGFloat {
		return sqrt(pow(other.x - self.x, 2) + pow(other.y - self.y, 2))
	}
}

extension UIPanGestureRecognizer {
	var isMovingOffscreen: Bool {
		guard let view = self.view else { return true }
		let velocity = self.velocity(in: self.view)
		let delta = self.translation(in: self.view)
		
		
		if velocity == .zero || delta.magnitudeFromOrigin < (view.bounds.width + view.bounds.height) / 10 { return false }

		return ((velocity.x >= 0) == (delta.x >= 0)) && ((velocity.y >= 0) == (delta.y >= 0))
	}
}