//
//  FlickCardController.swift
//  FlickCard
//
//  Created by Ben Gottlieb on 10/1/18.
//  Copyright © 2018 Ben Gottlieb. All rights reserved.
//

import UIKit

open class FlickCardController: UIViewController {
	public typealias ID = String
	
	open var id: ID!

	public var listViewHeight: CGFloat? { return nil }

	var containerController: FlickCardContainerViewController?
	var originalFrame: CGRect?
	var zoomContainer: UIView!
	var isZoomedToFullScreen: Bool { return self.view.bounds == self.parent?.view.bounds }
	var animationController: Presenter!
	var isInsideContainer: Bool { return self.parent == self.containerController }
}
