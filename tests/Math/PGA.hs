{- HSlice. 
 - Copyright 2020 Julia Longtin
 -
 - This program is free software: you can redistribute it and/or modify
 - it under the terms of the GNU Affero General Public License as published by
 - the Free Software Foundation, either version 3 of the License, or
 - (at your option) any later version.
 -
 - This program is distributed in the hope that it will be useful,
 - but WITHOUT ANY WARRANTY; without even the implied warranty of
 - MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 - GNU Affero General Public License for more details.

 - You should have received a copy of the GNU Affero General Public License
 - along with this program.  If not, see <http://www.gnu.org/licenses/>.
 -}

-- Shamelessly stolen from ImplicitCAD.

module Math.PGA (geomAlgSpec, proj2DGeomAlgSpec) where

-- Be explicit about what we import.
import Prelude (($))

-- Hspec, for writing specs.
import Test.Hspec (describe, Spec, it)

-- The numeric type in HSlice, and the type for a euclidian line segment.
import Graphics.Slicer (ℝ,Line(Line))

-- A euclidian point.
import Graphics.Slicer.Math.Definitions(Point2(Point2))

-- Our Geometric Algebra library.
import Graphics.Slicer.Math.GeometricAlgebra (GNum(GEZero, GEPlus), GVal(GVal), GVec(GVec), addValPair, subValPair, addVal, subVal, addVecPair, subVecPair, mulScalarVec, divVecScalar, innerProduct, outerProduct, scalarIze, (•), (∧))

-- Our 2D Projective Geometric Algebra library.
import Graphics.Slicer.Math.PGA (PPoint2(PPoint2), PLine2(PLine2), eToPPoint2, eToPLine2, join2PPoint2)

-- Our utility library, for making these tests easier to read.
import Math.Util ((-->))

-- Default all numbers in this file to being of the type ImplicitCAD uses for values.
default (ℝ)

geomAlgSpec :: Spec
geomAlgSpec = do
  describe "GVals" $ do
    -- 1e1+1e1 = 2e1
    it "adds two values with a common basis vector" $
      addValPair (GVal 1 [GEPlus 1]) (GVal 1 [GEPlus 1]) --> [GVal 2 [GEPlus 1]]
    -- 1e1+1e2 = e1+e2
    it "adds two values with different basis vectors" $
      addValPair (GVal 1 [GEPlus 1]) (GVal 1 [GEPlus 2]) --> [GVal 1 [GEPlus 1], GVal 1 [GEPlus 2]]
    -- 2e1-1e1 = e1
    it "subtracts two values with a common basis vector" $
      subValPair (GVal 2 [GEPlus 1]) (GVal 1 [GEPlus 1]) --> [GVal 1 [GEPlus 1]]
    -- 1e1-1e2 = e1-e2
    it "subtracts two values with different basis vectors" $
      subValPair (GVal 1 [GEPlus 1]) (GVal 1 [GEPlus 2]) --> [GVal 1 [GEPlus 1], GVal (-1) [GEPlus 2]]
    -- 1e1-1e1 = 0
    it "subtracts two identical values with a common basis vector and gets nothing" $
      subValPair (GVal 1 [GEPlus 1]) (GVal 1 [GEPlus 1]) --> []
    -- 1e0+1e1+1e2 = e0+e1+e2
    it "adds a value to a list of values" $
      addVal [GVal 1 [GEZero 1], GVal 1 [GEPlus 1]] (GVal 1 [GEPlus 2]) --> [GVal 1 [GEZero 1], GVal 1 [GEPlus 1], GVal 1 [GEPlus 2]]
    -- 2e1+1e2-1e1 = e1+e2
    it "subtracts a value from a list of values" $
      subVal [GVal 2 [GEPlus 1], GVal 1 [GEPlus 2]] (GVal 1 [GEPlus 1]) --> [GVal 1 [GEPlus 1], GVal 1 [GEPlus 2]]
    -- 1e1+1e2-1e1 = e2
    it "subtracts a value from a list of values, eliminating an entry with a like basis vector" $
      subVal [GVal 1 [GEPlus 1], GVal 1 [GEPlus 2]] (GVal 1 [GEPlus 1]) --> [GVal 1 [GEPlus 2]]
  describe "GVecs" $ do
    -- 1e1+1e1 = 2e1
    it "adds two (multi)vectors" $
      addVecPair (GVec [GVal 1 [GEPlus 1]]) (GVec [GVal 1 [GEPlus 1]]) --> GVec [GVal 2 [GEPlus 1]]
    -- 1e1-1e1 = 0
    it "subtracts a (multi)vector from another (multi)vector" $
      subVecPair (GVec [GVal 1 [GEPlus 1]]) (GVec [GVal 1 [GEPlus 1]]) --> GVec []
    -- 2*1e1 = 2e1
    it "multiplies a (multi)vector by a scalar" $
      mulScalarVec 2 (GVec [GVal 1 [GEPlus 1]]) --> GVec [GVal 2 [GEPlus 1]]
    -- 2e1/2 = e1
    it "divides a (multi)vector by a scalar" $
      divVecScalar (GVec [GVal 2 [GEPlus 1]]) 2 --> GVec [GVal 1 [GEPlus 1]]
    -- 1e1|1e2 = 0
    it "the dot product of two orthoginal basis vectors is nothing" $
      innerProduct (GVec [GVal 1 [GEPlus 1]]) (GVec [GVal 1 [GEPlus 2]]) --> GVec []
    it "the dot product of two vectors is comutative (a⋅b == b⋅a)" $
      innerProduct (GVec $ addValPair (GVal 1 [GEPlus 1]) (GVal 1 [GEPlus 2])) (GVec $ addValPair (GVal 2 [GEPlus 2]) (GVal 2 [GEPlus 2])) -->
      innerProduct (GVec $ addValPair (GVal 2 [GEPlus 1]) (GVal 2 [GEPlus 2])) (GVec $ addValPair (GVal 1 [GEPlus 2]) (GVal 1 [GEPlus 2]))
    -- 2e1|2e1 = 4
    it "the dot product of a vector with itsself is it's magnitude squared" $
      scalarIze (innerProduct (GVec [GVal 2 [GEPlus 1]]) (GVec [GVal 2 [GEPlus 1]])) --> (4, GVec [])
    -- (2e1^1e2)|(2e1^1e2) = -4
    it "the dot product of a bivector with itsself is the negative of magnitude squared" $
      scalarIze (innerProduct (GVec [GVal 2 [GEPlus 1, GEPlus 2]]) (GVec [GVal 2 [GEPlus 1, GEPlus 2]])) --> (-4, GVec [])
    -- 1e1^1e1 = 0
    it "the wedge product of two identical vectors is nothing" $
      outerProduct (GVec [GVal 1 [GEPlus 1]]) (GVec [GVal 1 [GEPlus 1]]) --> GVec []
    it "the wedge product of two vectors is anti-comutative (u∧v == -v∧u)" $
      outerProduct (GVec [GVal 1 [GEPlus 1]]) (GVec [GVal 1 [GEPlus 2]]) -->
      outerProduct (GVec [GVal (-1) [GEPlus 2]]) (GVec [GVal 1 [GEPlus 1]])

proj2DGeomAlgSpec :: Spec
proj2DGeomAlgSpec = do
  describe "Points" $ do
    -- ((1e0^1e1)+(-1e0^1e2)+(1e1+1e2))|((-1e0^1e1)+(1e0^1e2)+(1e1+1e2)) = -1
    it "the dot product of any two projective points is -1" $
      scalarIze (innerProduct (rawPPoint2 (1,1)) (rawPPoint2 (-1,-1))) --> (-1, GVec [])
  describe "Lines" $ do
    -- (-2e2)*2e1 = 4e12
    it "the intersection of a line along the X axis, and a line along the Y axis is the origin point" $
      (\(PLine2 a) -> a) (eToPLine2 (Line (Point2 (-1,0)) (Point2 (2,0)))) ∧ (\(PLine2 a) -> a) (eToPLine2 (Line (Point2 (0,-1)) (Point2 (0,2)))) --> GVec [GVal 4 [GEPlus 1, GEPlus 2]]
    -- (-2e0+1e1)^(2e0-1e2) = -1e01+2e02-e12
    it "the intersection of a line two points above the X axis, and a line two points to the right of the Y axis is at (2,2) in the upper right quadrant" $
      (\(PLine2 a) -> a) (eToPLine2 (Line (Point2 (2,0)) (Point2 (0,1)))) ∧ (\(PLine2 a) -> a) (eToPLine2 (Line (Point2 (0,2)) (Point2 (1,0)))) -->
      GVec [GVal (-2) [GEZero 1, GEPlus 1], GVal 2 [GEZero 1, GEPlus 2], GVal (-1) [GEPlus 1, GEPlus 2]]
    -- (2e0+1e1-1e2)*(2e0+1e1-1e2) = 2
    it "the geometric product of two overlapping lines is only a Scalar" $
      scalarIze ((\(PLine2 a) -> a) (eToPLine2 (Line (Point2 (-1,1)) (Point2 (1,1)))) • (\(PLine2 a) -> a) (eToPLine2 (Line (Point2 (-1,1)) (Point2 (1,1))))) --> (2.0, GVec [])
    it "A line constructed from a line segment is equal to one constructed from joining two points" $
      eToPLine2 (Line (Point2 (0,0)) (Point2 (1,1))) --> join2PPoint2 (eToPPoint2 (Point2 (1,1))) (eToPPoint2 (Point2 (0,0)))
  where
    rawPPoint2 (x,y) = (\(PPoint2 v) -> v) $ eToPPoint2 (Point2 (x,y))
