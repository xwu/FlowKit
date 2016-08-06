//
//  PolygonGate.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 7/9/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation

public struct PolygonGate : Gate {
  public typealias Vertex = (x: Float, y: Float)
  public static let maxVertexCount = 46340
  // `46340 * 46340 < Int32.max`, whereas `46341 * 46341 > Int(Int32.max)`

  public let dimensions: [String]
  public let vertices: [Vertex]

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
      var isFirstOffAxisVertexFound = false
      var firstOffAxisTest = false
      var skippedVerticesBeforeFirstOffAxisVertex = 0
      var firstOffAxisAdditionalTest = false
      var intersections = 0

      // Previous vertex coordinates minus coordinates of point to be
      // interrogated: initialize using last vertex
      var px = vx[vertexCount - 1] - xi, py = vy[vertexCount - 1] - yi
      inner: for i in 0..<vertexCount {
        let cx = vx[i] - xi, cy = vy[i] - yi
        // Current vertex coordinates minus coordinates of point to be
        // interrogated
        let pxcy = px * cy, cxpy = cx * py
        let test = (cy < 0) != (py < 0)
        // `test == true` if the edge joining the previous vertex to the current
        // vertex (both minus coordinates of the point to be interrogated)
        // crosses the x-axis

        // Check collinearity; gives a false negative if (`px`, `py`) or
        // (`cx`, `cy`) is at the origin, but that case is handled below
        if test && (pxcy == cxpy) {
          result[idx] = 1
          continue outer
        }

        if cy == 0 {
          if cx < 0 {
            skippedVertices -= 1
            continue inner
          }
          if cx > 0 {
            skippedVertices += vertexCount
            continue inner
          }
          // `cx == 0`
          result[idx] = 1
          continue outer
        }

        let additionalTest = (cy > py) ? (pxcy > cxpy) : (pxcy < cxpy)
        // `additionalTest == true` if the edge joining the previous vertex to
        // the current vertex (both minus coordinates of the point to be
        // interrogated) crosses the *positive* x-axis, provided that
        // `test == true` and `cy != 0`
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
        // `test == false` or `cy == 0`, and we have stipulated that
        // `test == true` and `cy != 0`

        if !isFirstOffAxisVertexFound {
          // Defer incrementing or decrementing `intersections` for the first
          // off-axis vertex we find until we know if we've got to take into
          // account any skipped vertices at the end of the array
          isFirstOffAxisVertexFound = true
          firstOffAxisTest = test
          skippedVerticesBeforeFirstOffAxisVertex = skippedVertices
          firstOffAxisAdditionalTest = additionalTest
        } else if test {
          if skippedVertices > 0 || (skippedVertices == 0 && additionalTest) {
            intersections += 1
          }
        }
        skippedVertices = 0
        px = cx
        py = cy
      }
      if !isFirstOffAxisVertexFound {
        // result[idx] = 0
        continue outer
      }
      // We've deliberately deferred incrementing or decrementing
      // `intersections` for the first off-axis vertex until now
      if firstOffAxisTest {
        skippedVertices += skippedVerticesBeforeFirstOffAxisVertex
        if skippedVertices > 0 ||
          (skippedVertices == 0 && firstOffAxisAdditionalTest) {
          intersections += 1
        }
      }
      // It's an even-odd algorithm, after all...
      result[idx] = Float(intersections % 2)
    }
    return Population(population, mask: result)
  }
}
