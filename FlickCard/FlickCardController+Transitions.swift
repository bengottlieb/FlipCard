//
//  FlickCardController+Container.swift
//  Bee
//
//  Created by Ben Gottlieb on 9/25/18.
//  Copyright © 2018 Stand Alone, Inc. All rights reserved.
//

import UIKit

extension FlickCardController {
	open func prepareToPresent(wrappingInNavigationController: Bool) -> UIViewController {
		self.removeFromParent()
		
		if !wrappingInNavigationController {
			self.transitioningDelegate = self
			return self
		}
		
		let parent = self.parent
		let superview = self.view.superview
		let frame = self.view.frame
		
		self.removeFromParent()
		self.view.removeFromSuperview()
		
		let nav = UINavigationController(rootViewController: self)
		nav.setNavigationBarHidden(true, animated: false)
		
		self.view.translatesAutoresizingMaskIntoConstraints = true
		self.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		parent?.addChild(nav)
		nav.view.frame = frame
		superview?.addSubview(nav.view)
		nav.transitioningDelegate = self
		
		return nav
	}
	
	func willBecomeFrontCard(in parent: FlickCardPileViewController, animated: Bool) {
		let controller = self
		
		controller.willMove(toParent: parent)
		controller.viewWillAppear(animated)
		parent.addChild(controller)
		controller.didMove(toParent: parent)
		controller.viewDidAppear(animated)
	}
	
	func didResignFrontCard(in pileView: FlickCardPileViewController, animated: Bool) {
		let controller = self
		
		controller.willMove(toParent: nil)
		controller.viewWillDisappear(animated)
		controller.removeFromParent()
		controller.didMove(toParent: nil)
		controller.viewDidDisappear(animated)
	}
}

extension FlickCardController: UIViewControllerTransitioningDelegate {
	public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		
		if self.animationController == nil { self.animationController = Presenter(forDismissing: false) }
		
		self.animationController.dismissing = false
		return self.animationController
	}
	
	public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		if self.animationController == nil { self.animationController = Presenter(forDismissing: false) }
		
		self.animationController.dismissing = true
		return self.animationController
	}
	
	class Presenter: NSObject, UIViewControllerAnimatedTransitioning {
		var zoomContainer: UIView!
		var dismissing: Bool
		var duration: TimeInterval
		
		func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval { return self.duration }
		
		init(forDismissing: Bool, duration: TimeInterval = 0.5) {
			self.duration = duration
			self.dismissing = forDismissing
			super.init()
		}
		
		func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
			let containerView = transitionContext.containerView
			let duration = self.transitionDuration(using: transitionContext)
			
			if self.dismissing {
				guard let toVC = transitionContext.toVC, let parent = toVC.topContainer, let fromVC = transitionContext.fromVC?.top as? FlickCardController, let zoomContainer = self.zoomContainer else {
					transitionContext.completeTransition(false)
					return
				}
				
				guard let (targetView, targetFrame) = parent.targetViewAndFrame(for: fromVC) else { return }
				if let background = toVC.view.snapshotView(afterScreenUpdates: true) { containerView.insertSubview(background, at: 0) }
				let finalFrame = targetView.convert(targetFrame, to: containerView)
				
				UIView.animateKeyframes(withDuration: duration, delay: 0, options: [.layoutSubviews, .calculationModeCubicPaced], animations: {
					UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.9, animations: {
						zoomContainer.frame = finalFrame
						parent.applyCardStyling(to: fromVC.view)
						self.zoomContainer.transform = CGAffineTransform(translationX: 0, y: 40)
					})
					UIView.addKeyframe(withRelativeStartTime: 0.9, relativeDuration: 0.1, animations: {
						self.zoomContainer.transform = .identity
					})
				}) { _ in
					transitionContext.completeTransition(true)
					fromVC.view.removeFromSuperview()
					fromVC.removeFromParent()
					parent.restore(fromVC, in: targetView)
				}
			} else {
				guard let toVC = transitionContext.toVC, toVC.top is FlickCardController else {
					transitionContext.completeTransition(false)
					return
				}
				
				let frame = toVC.view.convert(toVC.view.bounds, to: containerView)
				self.zoomContainer = UIView(frame: frame)
				
				toVC.view.frame = self.zoomContainer.bounds
				self.zoomContainer.addSubview(toVC.view)
				
				containerView.addSubview(self.zoomContainer)
				self.zoomContainer.leadingAnchor.constraint(equalTo: toVC.view.leadingAnchor).isActive = true
				self.zoomContainer.trailingAnchor.constraint(equalTo: toVC.view.trailingAnchor).isActive = true
				self.zoomContainer.topAnchor.constraint(equalTo: toVC.view.topAnchor).isActive = true
				self.zoomContainer.bottomAnchor.constraint(equalTo: toVC.view.bottomAnchor).isActive = true
				
				UIView.animateKeyframes(withDuration: duration, delay: 0, options: [.layoutSubviews, .calculationModeCubicPaced], animations: {
					UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.9, animations: {
						self.zoomContainer.frame = containerView.bounds
						self.zoomContainer.transform = CGAffineTransform(translationX: 0, y: -40)
					})
					UIView.addKeyframe(withRelativeStartTime: 0.9, relativeDuration: 0.1, animations: {
						self.zoomContainer.transform = .identity
					})
				}) { _ in
					transitionContext.completeTransition(true)
				}
			}
		}
	}
	
}

extension UIViewController {
	var root: UIViewController {
		if let nav = self as? UINavigationController, let first = nav.viewControllers.first { return first }
		return self
	}
	
	var topContainer: FlickCardContainerViewController? {
		if let me = self.top as? FlickCardContainerViewController { return me }
		for viewController in self.top.children {
			if let container = viewController as? FlickCardContainerViewController { return container }
		}
		return nil
	}
	
	var top: UIViewController {
		if let nav = self as? UINavigationController, let last = nav.viewControllers.last { return last }
		return self
	}
}

extension UIViewControllerContextTransitioning {
	var fromVC: UIViewController? { return self.viewController(forKey: UITransitionContextViewControllerKey.from) }
	var toVC: UIViewController? { return self.viewController(forKey: UITransitionContextViewControllerKey.to) }
}
