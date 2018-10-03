//
//  FlickCardPileView.swift
//  Cards
//
//  Created by Ben Gottlieb on 9/22/18.
//  Copyright © 2018 Ben Gottlieb. All rights reserved.
//

import UIKit

public protocol FlickCardPileViewDelegate: class {
	func willRemoveFromPile(card: FlickCard, to: CGPoint?, viaFlick: Bool)
	func didRemoveFromPile(card: FlickCard, to: CGPoint?, viaFlick: Bool)
	func willRemoveLastCardFromPile()
	func didRemoveLastCardFromPile()
}

open class FlickCardPileViewController: FlickCardParentViewController {
	@IBOutlet var pileView: PileView!
	
	public enum Arrangment { case single, tight, loose, scattered, tiered(offset: CGFloat, alphaStep: CGFloat) }
	public var maxDragRotation: CGFloat = 0.2
	public var maxDragScale: CGFloat = 1.05
	public var dragAcceleration: CGFloat = 1.25
	public var returnFlickedCardsToBackOfPile = false
	public var arrangement: Arrangment = .tiered(offset: -20, alphaStep: 0.05) { didSet { self.updateUI() }}
	public var avoidKeyboard = false { didSet { if self.avoidKeyboard != oldValue { self.updateKeyboardNotifications() }}}
	public var numberOfVisibleCards = 5 { didSet { self.updateUI() }}
	public private(set) var cards: [FlickCard] = []
	public weak var flickCardPileViewDelegate: FlickCardPileViewDelegate?
	open var defaultCardCenter: CGPoint { return CGPoint(x: self.firstCardFrame.midX, y: self.firstCardFrame.midY) }
	public var cardInset = UIEdgeInsets.zero
	public var topCard: FlickCard? { return self.cards.first }
	public var visibleCards: [FlickCard] { return Array(self.cards[0..<(min(self.cards.count, self.numberOfVisibleCards))]) }
	
	var keyboardInsets = UIEdgeInsets.zero
	var draggingView: UIView!
	var dragStartPoint = CGPoint.zero

	var cardViewControllers: [FlickCardViewController] = []
	var panGestureRecognizer: UIPanGestureRecognizer!
	var cardsNeedLayout = false { didSet { if self.cardsNeedLayout { self.pileView.setNeedsLayout() }}}
	var firstCardIsInteracting: Bool { return self.state == .draggingTopCard }
	weak var animatingCardView: UIView?
	weak var lastFrontCard: FlickCard?
	var pendingCards: [PendingCard] = []
	override open func targetView(for card: FlickCard) -> UIView? { return self.pileView }

	override public func restore(_ controller: FlickCardViewController, in targetView: UIView) {
		self.addChild(controller)
		targetView.addSubview(controller.view)
		controller.view.frame = self.firstCardFrame
		controller.didMove(toParent: self)
		self.state = .idle
	}

	open override func viewDidLoad() {
		super.viewDidLoad()
		if self.pileView == nil {
			self.pileView = PileView(frame: self.view.bounds)
			self.view.insertSubview(self.pileView, at: 0)
			self.pileView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		}
		self.pileView.pileViewController = self
	}
	
	func load(cards: [FlickCard], animated: Bool = false) {
		if animated {
			for card in cards {
				self.add(card: card, toTop: false, animated: true, from: nil, duration: 0.2) { }
			}
		} else {
			self.cards += cards
			self.updateUI()
		}
	}
	
	override public func applyCardStyling(to view: FlickCardView) {
		view.layer.cornerRadius = self.cardCornerRadius
		view.layer.borderColor = self.cardBorderColor.cgColor
		view.layer.borderWidth = self.cardBorderWidth
	}
	


	func updateUI() {
		let visible = self.visibleCards
		
		for controller in self.cardViewControllers {
			if controller.card == nil || !visible.contains(controller.card) {
				controller.view.removeFromSuperview()
				if let index = self.cardViewControllers.index(of: controller) { self.cardViewControllers.remove(at: index) }
			}
		}
		
		
		self.cardViewControllers = self.visibleCards.map { card in
			if let controller = self.viewController(for: card ) { return controller }
			let controller = card.buildCardViewController(ofSize: self.firstCardFrame.size)
			self.applyCardStyling(to: controller.cardView)
			self.pileView.addSubview(controller.view)
			return controller
		}
		
		self.gesturesEnabled = self.cards.count > 0
		for i in 0..<self.visibleCards.count {
			guard let view = self.viewController(for: self.cards[i])?.view else { continue }
			
			if i == 0 {
				self.pileView.bringSubviewToFront(view)
			} else {
				view.removeFromSuperview()
				self.pileView.insertSubview(view, belowSubview: self.cardViewControllers[i - 1].view)
			}
		}

		self.cardsNeedLayout = true
		
		let frontCard = self.cardViewControllers.first?.card
		if !self.firstCardIsInteracting {
			if frontCard != self.lastFrontCard {
				self.lastFrontCard?.didResignFrontCard(in: self, animated: true)
				frontCard?.willBecomeFrontCard(in: self, animated: true)
				self.lastFrontCard = frontCard
			}
		}
	}
	
	var gesturesEnabled: Bool = false {
		didSet {
			self.pileView.isUserInteractionEnabled = self.gesturesEnabled
			if self.gesturesEnabled {
				if self.panGestureRecognizer != nil { return }
				
				self.panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panned))
				self.pileView.addGestureRecognizer(self.panGestureRecognizer!)
			} else {
				if let pan = self.panGestureRecognizer { self.pileView.removeGestureRecognizer(pan) }
				self.panGestureRecognizer = nil
			}
		}
	}
	
	func startDragging(card: FlickCard) {
		self.state = .draggingTopCard
		self.updateUI()
		UIView.animate(withDuration: 0.1) {
			self.pileView.layoutIfNeeded()
		}
	}
	
	func addReturnedCard(_ card: FlickCard) {
		self.cards.append(card)
		self.updateUI()
	}
	
	func finishDragging(card: FlickCard, to: CGPoint?, removed: Bool) {
		if removed {
			self.willRemove(card: card, to: to, viaFlick: true)
			self.remove(card: card)
		}
		self.state = .idle
		DispatchQueue.main.async { self.updateUI() }
	}
	
	struct PendingCard {
		let card: FlickCard
		let animated: Bool
		let toTop: Bool
		let source: CGPoint?
		let duration: TimeInterval
		let completion: (() -> Void)?
	}
	
	func add(card: FlickCard, toTop: Bool = false, animated: Bool = false, from source: CGPoint? = nil, duration: TimeInterval = 0.2, completion: (() -> Void)?) {
		if self.cards.contains(card) { return }
		
		
		self.pendingCards.append(PendingCard(card: card, animated: animated, toTop: toTop, source: source, duration: duration, completion: completion))
		self.handlePendingCards()
	}
	
	func handlePendingCards() {
		guard self.state == .idle, let first = self.pendingCards.first else { return }
		self.pendingCards.removeFirst()
		
		var newCards = self.cards
		if first.toTop { newCards.insert(first.card, at: 0) } else { newCards.append(first.card) }
		if first.animated {
			let cardController = first.card.buildCardViewController(ofSize: self.firstCardFrame.size)
			let cardView = cardController.cardView
			cardView.center = first.source ?? CGPoint(x: self.pileView.bounds.width / 2, y: -self.pileView.bounds.height)
			if first.toTop { self.pileView.addSubview(cardView) } else { self.pileView.insertSubview(cardView, at: 0) }
			self.state = .addingCards
			cardView.transformForAnimation(in: self, location: cardView.center)
			UIView.animate(withDuration: first.duration, animations: {
				cardView.center = self.defaultCardCenter
				cardView.percentageLifted = 0
			}) { _ in
				self.state = .idle
				self.cardViewControllers.append(cardController)
				self.cards = newCards
				self.updateUI()
				first.completion?()
				self.handlePendingCards()
			}
		} else {
			self.cards = newCards
			self.updateUI()
			first.completion?()
			DispatchQueue.main.async { self.handlePendingCards() }
		}
	}
	
	func animateCardOut(_ card: FlickCard, to destination: CGPoint?, duration: TimeInterval = 0.2) {
		if let cardViewController = self.viewController(for: card) {
			let cardView = cardViewController.cardView
			let dest = destination ?? CGPoint(x: self.pileView.bounds.width * 1, y: self.pileView.bounds.height * -1)
			
			self.willRemove(card: card, to: destination, viaFlick: false)
			self.animatingCardView = cardView
			self.remove(card: card)
			self.state = .animatingTopCardOut
			self.updateUI()
			UIView.animate(withDuration: 0.1, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [.curveEaseIn], animations: {
					cardView.transform = CGAffineTransform(translationX: 10, y: 30)
			}) { _ in
					UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [.curveEaseIn], animations: {
					self.pileView.layoutIfNeeded()
					cardView.center = dest
					cardView.transformForAnimation(in: self, location: dest)
				}) { _ in
					self.state = .idle
					cardView.removeFromSuperview()
					self.updateUI()
					self.didRemove(card: card, to: destination, viaFlick: false)
				}
			}
		}
	}
	
	func remove(card: FlickCard) {
		if let index = self.cards.index(of: card) { self.cards.remove(at: index) }
		if let controller = self.viewController(for: card) {
			if let index = self.cardViewControllers.index(of: controller) { self.cardViewControllers.remove(at: index) }
		}
	}
	
	func willRemove(card: FlickCard, to: CGPoint?, viaFlick: Bool) {
		self.flickCardPileViewDelegate?.willRemoveFromPile(card: card, to: to, viaFlick: viaFlick)
		if self.cards.count == 1 {
			self.flickCardPileViewDelegate?.willRemoveLastCardFromPile()
		}
	}
	
	func didRemove(card: FlickCard, to: CGPoint?, viaFlick: Bool) {
		self.flickCardPileViewDelegate?.didRemoveFromPile(card: card, to: to, viaFlick: viaFlick)
		if self.cards.count == 0 {
			self.flickCardPileViewDelegate?.didRemoveLastCardFromPile()
		}
	}
	
	func viewController(for card: FlickCard) -> FlickCardViewController? {
		for controller in self.cardViewControllers { if controller.card == card { return controller }}
		return nil
	}
	
	func calculateAlpha(for card: FlickCard, at position: Int) -> CGFloat {
		switch self.arrangement {
		case .tiered(_, let alphaStep):
			return 1.0 - CGFloat(position) * alphaStep
			
		default:
			return 1
		}
	}
	
	func calculateTransform(for card: FlickCard, at position: Int) -> CGAffineTransform {
		if position == 0 { return .identity }
		
		let seed = card.id.hashValue % 10
		
		switch self.arrangement {
		case .single: return .identity
		case .tight:
			return CGAffineTransform(translationX: 0, y: (5 * CGFloat(position)))

		case .loose:
			return CGAffineTransform(rotationAngle: CGFloat(seed) * 0.015 * (seed % 2 == 0 ? -1 : 1))

		case .scattered:
			return CGAffineTransform(rotationAngle: CGFloat(seed) * 0.05 * (seed % 2 == 0 ? -1 : 1))

		case .tiered(let offset, _):
			let factor = 1.0 - CGFloat(position) * 0.05
			let scale = CGAffineTransform(scaleX: factor, y: factor)
			let offsetFactor = 1 - (self.keyboardInsets.bottom / self.pileView.bounds.height)
			let translation = -1 * CGFloat(position) * offset
			let translate = CGAffineTransform(translationX: 0, y: translation * offsetFactor * 1.2)
			return scale.concatenating(translate)
		}
		
	}
}


extension FlickCardPileViewController {
	@objc(FlickCardPileViewControllerPileView) public class PileView: UIView {
		var pileViewController: FlickCardPileViewController!
		open override func layoutSubviews() {
			super.layoutSubviews()
			if self.pileViewController.cardsNeedLayout {
				let center = self.pileViewController.defaultCardCenter
				let firstIndex = self.pileViewController.firstCardIsInteracting ? 1 : 0
				let cardFrame = self.pileViewController.firstCardFrame
				
				if firstIndex < self.pileViewController.cardViewControllers.count {
					for i in firstIndex..<self.pileViewController.cardViewControllers.count {
						let card = self.pileViewController.cardViewControllers[i].card!
						if self.pileViewController.cardViewControllers[i] == self.pileViewController.animatingCardView { continue }
						self.pileViewController.cardViewControllers[i].view.bounds.size = cardFrame.size
						self.pileViewController.cardViewControllers[i].view.transform = self.pileViewController.calculateTransform(for: card, at: i - firstIndex)
						self.pileViewController.cardViewControllers[i].view.alpha = self.pileViewController.calculateAlpha(for: card, at: i - firstIndex)
						self.pileViewController.cardViewControllers[i].view.center = center
					}
				}
				
				if let animating = self.pileViewController.animatingCardView {
					self.pileViewController.pileView.bringSubviewToFront(animating)
				}
				self.pileViewController.cardsNeedLayout = false
			}
		}
		

	}
}