//
//  PolygonGate.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 7/9/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation

/**
  A polygon gate in two dimensions.

  The polygon is automatically closed, events on its boundary are considered to
  be in the gate, and the interior of the polygon is determined by the even–odd
  winding rule.
*/
public struct PolygonGate : Gate {
  public typealias Vertex = (x: Float, y: Float)

  /// The maximum supported number of vertices in a polygon.
  public static let maxVertexCount = 46340
  // `46340 * 46340 < Int32.max`, whereas `46341 * 46341 > Int(Int32.max)`

  public let dimensions: [String]

  /// The vertices of the polygon; edges are drawn between consecutive vertices.
  public let vertices: [Vertex]

  /**
    Create a (two-dimensional) polygon gate with the given dimensions and
    vertices.

    - Parameter dimensions: The dimensions to be gated. These names can be
      parameter short names (FCS terminology) or, equivalently, detector names
      (Gating-ML terminology), and they can be fluorochrome names (Gating-ML
      terminology) after compensation using a non-acquisition-defined matrix.
    - Parameter vertices: The vertices of the polygon; edges are drawn between
      consecutive vertices.
  */
  public init(dimensions: [String], vertices: [Vertex]) {
    precondition(dimensions.count == 2)
    precondition(vertices.count <= PolygonGate.maxVertexCount)
    self.dimensions = dimensions
    self.vertices = vertices
  }

  public func masking(_ population: Population) -> Population? {
    guard
      vertices.count > 1,
      let x = population.root.events[dimensions[0]],
      let y = population.root.events[dimensions[1]]
      else { return nil }

    let vertexCount = vertices.count
    // Vertex coordinates
    let vx = self.vertices.map { $0.x }
    let vy = self.vertices.map { $0.y }
    // Bounds
    let bx = (vx.min() ?? -Float.infinity, vx.max() ?? Float.infinity)
    let by = (vy.min() ?? -Float.infinity, vy.max() ?? Float.infinity)

    var result = [Float](repeating: 0, count: x.count)
    outer: for idx in 0..<x.count {
      // Coordinates of point to be interrogated
      let xi = x[idx], yi = y[idx]

      // First, check bounds
      if xi < bx.0 || xi > bx.1 || yi < by.0 || yi > by.1 {
        // result[idx] = 0
        continue outer
      }

      // Find the last off-axis vertex
      var isLastOffAxisVertexFound = false
      var skippedVerticesAfterLastOffAxisVertex = 0
      // See comment below about `skippedVertices`
      var lastOffAxisVertexIndex = vertexCount - 1

      // Previous vertex coordinates minus coordinates of point to be
      // interrogated: initialize using last off-axis vertex
      var px = Float.nan, py = Float.nan
      inner0: while lastOffAxisVertexIndex >= 0 {
        // Current vertex coordinates minus coordinates of point to be
        // interrogated
        let cx = vx[lastOffAxisVertexIndex] - xi
        let cy = vy[lastOffAxisVertexIndex] - yi

        if cy == 0 {
          if cx == 0 {
            result[idx] = 1
            continue outer
          }
          skippedVerticesAfterLastOffAxisVertex += cx < 0 ? -1 : vertexCount
          lastOffAxisVertexIndex -= 1
          continue inner0
        }

        isLastOffAxisVertexFound = true
        px = cx
        py = cy
        break
      }

      if !isLastOffAxisVertexFound {
        // If the point to be interrogated lies on an edge connecting two
        // vertices that have the same y-coordinate, then
        // `skippedVerticesAfterLastOffAxisVertex` will be positive but not a
        // multiple of `vertexCount`
        if skippedVerticesAfterLastOffAxisVertex > 0 &&
          skippedVerticesAfterLastOffAxisVertex % vertexCount > 0 {
          result[idx] = 1
        } // else { result[idx] = 0 }
        continue outer
      }

      var isFirstOffAxisVertexFound = false
      var skippedVertices = 0
      // We'll increment `skippedVertices` by `vertexCount` on skipping a
      // positive vertex and decrement it by 1 on skipping a negative vertex
      //
      // * If `skippedVertices > 0`, then at least one positive vertex was
      //   skipped
      // * If `skippedVertices < 0`, then at least one negative vertex was
      //   skipped without skipping any positive vertices
      //
      // Here, "positive" and "negative" vertices refer to the x-coordinate of
      // the vertex after subtracting the x-coordinate of the point to be
      // interrogated
      var intersections = 0

      var i = 0
      inner1: while i <= lastOffAxisVertexIndex {
        // Current vertex coordinates minus coordinates of point to be
        // interrogated
        let cx = vx[i] - xi, cy = vy[i] - yi

        if cy == 0 {
          if cx == 0 {
            result[idx] = 1
            continue outer
          }
          skippedVertices += cx < 0 ? -1 : vertexCount
          continue inner1
        }

        if !isFirstOffAxisVertexFound {
          isFirstOffAxisVertexFound = true
          skippedVertices += skippedVerticesAfterLastOffAxisVertex
        }
        // If the point to be interrogated lies on an edge connecting two
        // vertices that have the same y-coordinate, then `skippedVertices` will
        // be positive but not a multiple of `vertexCount`
        if skippedVertices > 0 && skippedVertices % vertexCount > 0 {
          result[idx] = 1
          continue outer
        }

        // Test if the edge joining the previous vertex to the current vertex
        // (both minus coordinates of the point to be interrogated) crosses the
        // x-axis
        if (cy < 0) != (py < 0) {
          let test = (cy - py) * (px * cy - cx * py)
          // `test > 0` if the edge joining the previous vertex to the current
          // vertex (both minus coordinates of the point to be interrogated)
          // crosses the *positive* x-axis, provided that `(cy < 0) != (py < 0)`
          // and `cy != 0`
          //
          // We must solve:
          //     cx - cy * (cx - px) / (cy - py) > 0
          //
          // Rearranging, we have:
          //                                  cx > cy * (cx - px) / (cy - py)
          //
          // If `(cy - py) > 0`, i.e. `cy > py`, then we have:
          //                      cx * (cy - py) > cy * (cx - px)
          //                   cx * cy - cx * py > cx * cy - px * cy
          //                            -cx * py > -px * cy
          //                             px * cy > cx * py
          //
          // If on the other hand `(cy - py) < 0`, i.e. `cy < py`, then we have:
          //                      cx * (cy - py) < cy * (cx - px)
          //                                    ...
          //                             px * cy < cx * py
          //
          // Note that `cy` cannot be equal to `py`, because in that case either
          // `(cy < 0) == (py < 0)`, and we stipulated `(cy < 0) != (py < 0)`

          // First, check collinearity; gives a false negative if (`px`, `py`)
          // or (`cx`, `cy`) is at the origin, but that case is already handled
          if test == 0 {
            result[idx] = 1
            continue outer
          }
          if (skippedVertices == 0 && test > 0) || skippedVertices > 0 {
            intersections += 1
          }
        }

        skippedVertices = 0
        px = cx
        py = cy
        i += 1
      }
      
      // It's an even-odd algorithm, after all...
      if intersections % 2 == 1 {
        result[idx] = 1
      } // else { result[idx] = 0 }
    }
    return Population(population, mask: result)
  }
}
