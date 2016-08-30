//
//  Tree.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 8/27/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

internal final class Tree<T> {
  public var value: T
  public internal(set) var children: [Tree<T>] = []
  public internal(set) weak var parent: Tree<T>?

  public var previousSibling: Tree<T>? {
    guard
      let parent = parent,
      let i = (parent.children.index { $0 === self }),
      i > 0
      else { return nil }
    return parent.children[i - 1]
  }

  public var nextSibling: Tree<T>? {
    guard
      let parent = parent,
      let i = (parent.children.index { $0 === self }),
      i < parent.children.endIndex
      else { return nil }
    return parent.children[i + 1]
  }

  public var root: Tree<T> {
    var result = self
    while let parent = result.parent { result = parent }
    return result
  }

  public init(value: T) {
    self.value = value
  }

  public func appendChild(_ child: Tree<T>) {
    if let parent = child.parent { parent.removeChild(child) }
    children.append(child)
    child.parent = self
  }

  public func prependChild(_ child: Tree<T>) {
    if let parent = child.parent { parent.removeChild(child) }
    children.insert(child, at: 0)
    child.parent = self
  }

  public func removeChild(_ child: Tree<T>) {
    guard
      let i = (children.index { $0 === child })
      else { preconditionFailure() }
    let temporary = children.remove(at: i)
    temporary.parent = nil
  }

  public func removeAllChildren() {
    let temporary = children
    children.removeAll()
    temporary.forEach { $0.parent = nil }
  }

  public func sortChildren(
    by areInIncreasingOrder: (Tree<T>, Tree<T>) -> Bool
  ) {
    children.sort(by: areInIncreasingOrder)
  }

  public func insertSibling(_ sibling: Tree<T>) {
    guard let parent = parent else { preconditionFailure() }
    parent.appendChild(sibling)
  }

  public func descendant(
    where predicate: (Tree<T>) throws -> Bool
  ) rethrows -> Tree<T>? {
    for child in children {
      if try predicate(child) { return child }
    }
    return nil
  }

  public func ancestor(
    where predicate: (Tree<T>) throws -> Bool
  ) rethrows -> Tree<T>? {
    var temporary = self
    while let parent = temporary.parent {
      if try predicate(parent) { return parent }
      temporary = parent
    }
    return nil
  }
}
