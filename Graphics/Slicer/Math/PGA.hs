{-
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

{- The purpose of this file is to hold projective geometric algebraic arithmatic. -}

-- for adding Generic and NFData to our types.
{-# LANGUAGE DeriveGeneric, DeriveAnyClass #-}

module Graphics.Slicer.Math.PGA(PPoint2(PPoint2), PLine2(PLine2), eToPPoint2, canonicalizePPoint2, eToPLine2, combineConsecutiveLines, Intersection(Collinear, LColinear, Parallel, AntiParallel, HitStartPointL2, HitEndPointL2, IntersectsAt, NoIntersection), lineIntersection, lineIntersectsAt, plinesIntersectAt, dualPPoint2, dualPLine2, dual2DGVec, join2PPoint2, translatePerp, flipPLine2, pointOnPerp, angleBetween, lineIsLeft) where

import Prelude (Eq, Show, (==), ($), filter, (*), (-), Bool, (&&), last, init, (++), length, (<$>), otherwise, (>), (<=), (+), foldl, sqrt, head, null, negate, (/))

import GHC.Generics (Generic)

import Control.DeepSeq (NFData)

import Data.List.Ordered (sort, foldt)

import Data.Maybe (Maybe(Just, Nothing), fromJust)

import Graphics.Slicer.Definitions (ℝ)

import Graphics.Slicer.Math.Definitions(Point2(Point2), addPoints)

import Graphics.Slicer.Math.Line(Line(Line))

import Graphics.Slicer.Math.GeometricAlgebra (GNum(G0, GEPlus, GEZero), GVal(GVal), GVec(GVec), (⎣), (⎤), (•), {- (⋅), (∧),-} addVal, addVecPair, divVecScalar, scalarPart, vectorPart, mulScalarVec)

-- Our 2D plane coresponds to a Clifford algebra of 2,0,1.

-- Don't check for corner cases, junt get the intersection point if it exists.

-- The result of a line intersection in 2 dimensions.
data Intersection =
  Collinear
  | LColinear Line Line
  | Parallel
  | AntiParallel
  | IntersectsAt Point2
  | NoIntersection
  | HitStartPointL2 Line Line Point2
  | HitEndPointL2 Line Line Point2
  deriving (Show)

-- Wrapper, for line segment using code
lineIntersectsAt :: Line -> Line -> Intersection
lineIntersectsAt l1 l2 = case plinesIntersectAt (eToPLine2 l1) (eToPLine2 l2) of
                           Collinear -> LColinear l1 l2
                           a         -> a

-- | Entry point when you know that the two PLine2s intersect.
plinesIntersectAt :: PLine2 -> PLine2 -> Intersection
plinesIntersectAt pl1 pl2
  | meet2PLine2 pl1 pl2       == PPoint2 (GVec []) = Collinear
  | scalarPart (rawPLine pl1 ⎣ rawPLine pl2) ==  1 = Parallel
  | scalarPart (rawPLine pl1 ⎣ rawPLine pl2) == -1 = AntiParallel
  | otherwise                                      = IntersectsAt intersection
  where
    rawPLine (PLine2 a) = a
    intersection = intersectPLines pl1 pl2

-- | Check if/where two line segments intersect.
lineIntersection :: Line -> Line -> Intersection
lineIntersection l1 l2@(Line p2 s2)
  | meet2PLine2 (eToPLine2 l1) (eToPLine2 l2) == PPoint2 (GVec [])         = LColinear l1 l2
  | onSegment l1 intersection && onSegment l2 intersection && intersection == p2 = HitStartPointL2 l1 l2 intersection
  | onSegment l1 intersection && onSegment l2 intersection && intersection == addPoints p2 s2 = HitEndPointL2 l1 l2 intersection
  | onSegment l1 intersection && onSegment l2 intersection = IntersectsAt intersection
  | scalarPart (rawPLine (eToPLine2 l1) ⎣ rawPLine (eToPLine2 l2)) ==  1 = Parallel
  | scalarPart (rawPLine (eToPLine2 l1) ⎣ rawPLine (eToPLine2 l2)) == -1 = Parallel
  | otherwise = NoIntersection
  where
    rawPLine (PLine2 a) = a
    intersection = intersectionPoint l1 l2

-- Check if the second line's direction is on the 'left' side of the first line, assuming they intersect.
lineIsLeft :: Line -> Line -> Maybe Bool
lineIsLeft line1 line2
  | dualAngle dnpl1 dnpl2 == 0 = Nothing
  | otherwise                  = Just $ dualAngle dnpl1 dnpl2 > 0
  where
    npl1 = normalizePLine2 $ eToPLine2 line1
    npl2 = normalizePLine2 $ eToPLine2 line2
    dnpl1 = forceBasis [[GEZero 1, GEPlus 1], [GEZero 1, GEPlus 2], [GEPlus 1, GEPlus 2]] $ dualPLine2 npl1
    dnpl2 = forceBasis [[GEZero 1, GEPlus 1], [GEZero 1, GEPlus 2], [GEPlus 1, GEPlus 2]] $ dualPLine2 npl2

dualAngle :: GVec -> GVec -> ℝ
dualAngle ln1 ln2 = valOf 0 $ getVals [GEZero 1, GEZero 1, GEPlus 1, GEPlus 2] $ (\(GVec a) -> a) $ ln1 ⎤ ln2

angleBetween :: PLine2 -> PLine2 -> ℝ
angleBetween pl1 pl2 =  scalarPart $ pv1 ⎣ pv2
  where
    (PLine2 pv1) = forcePLine2Basis (normalizePLine2 pl1)
    (PLine2 pv2) = forcePLine2Basis (normalizePLine2 pl2)

-- | Combine consecutive lines. expects lines with their end points connecting, EG, a contour generated by makeContours.
combineConsecutiveLines :: [Line] -> [Line]
combineConsecutiveLines lines
  | length lines > 1 = combineEnds $ foldt combine [last lines] ((:[]) <$> init lines)
  | otherwise = lines
  where
    combine :: [Line] -> [Line] -> [Line]
    combine  l1       [] = l1
    combine  []       l2 = l2
    combine [l1] [l2]    = if canCombineLines l1 l2 then [combineLines l1 l2] else l1 : [l2]
    combine [l1] (l2:ls) = if canCombineLines l1 l2 then combineLines l1 l2 : ls else l1:l2:ls
    combine  l1  [l2]    = if canCombineLines (last l1) l2 then init l1 ++ [combineLines (last l1) l2] else l1 ++ [l2]
    combine  l1  (l2:ls) = if canCombineLines (last l1) l2 then init l1 ++ combineLines (last l1) l2 : ls else l1 ++ l2:ls
    combineEnds :: [Line] -> [Line]
    combineEnds  []      = []
    combineEnds  [l1]    = [l1]
    combineEnds  (l1:ls)
      | length ls > 1 = if canCombineLines (last ls) l1 then init ls ++ [combineLines (last ls) l1] else l1:ls
      | otherwise = combine [l1] ls
    -- Combine lines (p1 -- p2) (p3 -- p4) to (p1 -- p4). We really only want to call this
    -- if p2 == p3 and the lines are parallel (see canCombineLines)
    combineLines :: Line -> Line -> Line
    combineLines (Line p _) (Line p1 s1) = llineFromEndpoints p (addPoints p1 s1)
    -- | Create a euclidian line given it's endpoints.
    llineFromEndpoints :: Point2 -> Point2 -> Line
    llineFromEndpoints p1@(Point2 (x1,y1)) (Point2 (x2,y2)) = Line p1 (Point2 (x2-x1,y2-y1))
    -- | determine if two euclidian line segments are on the same projective line, and if they share a middle point.
    canCombineLines :: Line -> Line -> Bool
    canCombineLines l1@(Line p1 s1) l2@(Line p2 _) = sameLine && sameMiddlePoint
      where
        sameLine = meet2PLine2 (eToPLine2 l1) (eToPLine2 l2) == PPoint2 (GVec [])
        sameMiddlePoint = p2 == addPoints p1 s1

-- | given the result of intersectionPoint, find out whether this intersection point is on the given segment, or not.
onSegment :: Line -> Point2 -> Bool
onSegment (Line p s) i =
  sqNormOfPLine2 (join2PPoint2 (eToPPoint2 p) (eToPPoint2 i)) <= segmentLength &&
  sqNormOfPLine2 (join2PPoint2 (eToPPoint2 i) (eToPPoint2 (addPoints p s))) <= segmentLength
  where
    segmentLength = sqNormOfPLine2 (join2PPoint2 (eToPPoint2 p) (eToPPoint2 (addPoints p s)))

-- Find the point where two Line segments (might) intersect.
intersectionPoint :: Line -> Line -> Point2
intersectionPoint l1 l2 = intersectPLines (eToPLine2 l1) (eToPLine2 l2)

-- Find out where two lines intersect
intersectPLines :: PLine2 -> PLine2 -> Point2
intersectPLines pl1 pl2 = Point2 (negate $ valOf 0 $ getVals [GEZero 1, GEPlus 2] pPoint
                                 ,         valOf 0 $ getVals [GEZero 1, GEPlus 1] pPoint)
  where
    pPoint = (\(PPoint2 (GVec vals)) -> vals) $ intersectionOf pl1 pl2

-- Find out where two lines intersect
intersectionOf :: PLine2 -> PLine2 -> PPoint2
intersectionOf pl1 pl2 = canonicalizePPoint2 $ meet2PLine2 pl1 pl2

-- | A projective point in 2D space.
newtype PPoint2 = PPoint2 GVec
  deriving (Eq, Generic, NFData, Show)

-- | A projective line in 2D space.
newtype PLine2 = PLine2 GVec
  deriving (Eq, Generic, NFData, Show)

-- our join operator, which is the meet operator operating in the dual space.
(∨) :: GVec -> GVec -> GVec
(∨) a b = dual2DGVec $ dual2DGVec a ⎤ dual2DGVec b

-- | our join function.
join :: GVec -> GVec -> GVec
join v1 v2 = v1 ∨ v2

-- | a typed join function. join two points, returning a line.
join2PPoint2 :: PPoint2 -> PPoint2 -> PLine2
join2PPoint2 (PPoint2 v1) (PPoint2 v2) = PLine2 $ join v1 v2

-- | A typed meet function. two lines meet at a point.
meet2PLine2 :: PLine2 -> PLine2 -> PPoint2
meet2PLine2 pl1 pl2 = PPoint2 $ pv1 ⎤ pv2
  where
    (PLine2 pv1) = forcePLine2Basis pl1
    (PLine2 pv2) = forcePLine2Basis pl2

-- | A type stripping meet finction.
meet2PPoint2 :: PPoint2 -> PPoint2 -> GVec
meet2PPoint2 pp1 pp2 = pv1 ⎤ pv2
  where
    (PPoint2 pv1) = forcePPoint2Basis pp1
    (PPoint2 pv2) = forcePPoint2Basis pp2

-- | Create a 2D projective point from a 2D euclidian point.
eToPPoint2 :: Point2 -> PPoint2
eToPPoint2 (Point2 (x,y)) = PPoint2 $ GVec $ foldl addVal [GVal 1 [GEPlus 1, GEPlus 2]] [ GVal (-x) [GEZero 1, GEPlus 2], GVal y [GEZero 1, GEPlus 1] ]

idealPPoint2 :: PPoint2 -> PPoint2
idealPPoint2 (PPoint2 (GVec vals)) = PPoint2 $ GVec $ foldl addVal []
                                     [
                                       GVal (valOf 0 $ getVals [GEZero 1, GEPlus 1] vals) [GEZero 1, GEPlus 1]
                                     , GVal (valOf 0 $ getVals [GEZero 1, GEPlus 2] vals) [GEZero 1, GEPlus 2]
                                     ]

-- | Create a 2D Euclidian point from a 2D Projective point.
ppointToPoint2 :: PPoint2 -> Maybe Point2
ppointToPoint2 (PPoint2 (GVec vals)) = if infinitePoint
                                      then Nothing
                                      else Just $ Point2 (xVal, yVal)
  where
    xVal = negate $ valOf 0 $ getVals [GEZero 1, GEPlus 2] vals
    yVal =          valOf 0 $ getVals [GEZero 1, GEPlus 1] vals
    infinitePoint = 0 == valOf 0 (getVals [GEPlus 1, GEPlus 2] vals)

-- | Create a 2D projective line from a pair of euclidian endpoints.
eToPLine2 :: Line -> PLine2
eToPLine2 (Line (Point2 (x1,y1)) (Point2 (x,y))) = PLine2 $ GVec $ foldl addVal [] [ GVal c [GEZero 1], GVal a [GEPlus 1], GVal b [GEPlus 2] ]
  where
    x2=x1+x
    y2=y1+y
    a=y2-y1
    b=x1-x2
    c=y1*x2-x1*y2

-- | Convert from a PPoint2 to it's associated PLine.
dualPPoint2 :: PPoint2 -> GVec
dualPPoint2 (PPoint2 vec) = dual2DGVec vec

-- | Convert from a PLine to it's associated projective point.
dualPLine2 :: PLine2 -> GVec
dualPLine2 (PLine2 vec) = dual2DGVec vec

reverse :: GVec -> GVec
reverse vec = GVec $ foldl addVal []
              [
                GVal           realVal                                                [G0]
              , GVal (         valOf 0 $ getVals [GEZero 1] vals)                     [GEZero 1]
              , GVal (         valOf 0 $ getVals [GEPlus 1] vals)                     [GEPlus 1]
              , GVal (         valOf 0 $ getVals [GEPlus 2] vals)                     [GEPlus 2]
              , GVal (negate $ valOf 0 $ getVals [GEZero 1, GEPlus 1] vals)           [GEZero 1, GEPlus 1]
              , GVal (negate $ valOf 0 $ getVals [GEZero 1, GEPlus 2] vals)           [GEZero 1, GEPlus 2]
              , GVal (negate $ valOf 0 $ getVals [GEPlus 1, GEPlus 2] vals)           [GEPlus 1, GEPlus 2]
              , GVal (negate $ valOf 0 $ getVals [GEZero 1, GEPlus 1, GEPlus 2] vals) [GEZero 1, GEPlus 1, GEPlus 2]
              ]
  where
    realVal     = scalarPart vec
    (GVec vals) = vectorPart vec

dual2DGVec :: GVec -> GVec
dual2DGVec vec = GVec $ foldl addVal []
                 [
                   GVal           realVal                                                [GEZero 1, GEPlus 1, GEPlus 2]
                 , GVal (         valOf 0 $ getVals [GEZero 1] vals)                     [GEPlus 1, GEPlus 2]
                 , GVal (negate $ valOf 0 $ getVals [GEPlus 1] vals)                     [GEZero 1, GEPlus 2]
                 , GVal (         valOf 0 $ getVals [GEPlus 2] vals)                     [GEZero 1, GEPlus 1]
                 , GVal (         valOf 0 $ getVals [GEZero 1, GEPlus 1] vals)           [GEPlus 2]
                 , GVal (negate $ valOf 0 $ getVals [GEZero 1, GEPlus 2] vals)           [GEPlus 1]
                 , GVal (         valOf 0 $ getVals [GEPlus 1, GEPlus 2] vals)           [GEZero 1]
                 , GVal (         valOf 0 $ getVals [GEZero 1, GEPlus 1, GEPlus 2] vals) [G0]
                 ]
  where
    realVal     = scalarPart vec
    (GVec vals) = vectorPart vec

-- | Extract a value from a vector.
-- FIXME: throw a failure when we get more than one match.
getVals :: [GNum] -> [GVal] -> Maybe GVal
getVals num vs = if null matches then Nothing else Just $ head matches
  where
    matches = filter (\(GVal _ n) -> n == num) vs

-- return the value of a vector, OR a given value, if the vector requested is not found.
valOf :: ℝ -> Maybe GVal -> ℝ 
valOf r Nothing = r
valOf _ (Just (GVal v _)) = v

forceBasis :: [[GNum]] -> GVec -> GVec
forceBasis numsets (GVec vals) = GVec $ forceVal vals <$> sort numsets
  where
    forceVal has needs = GVal (valOf 0 $ getVals needs has) needs

-- | ensure all of the '0' components exist on a PLine2.
forcePLine2Basis :: PLine2 -> PLine2
forcePLine2Basis ln@(PLine2 pvec@(GVec gvals)) = if length gvals == 3
                                                 then ln
                                                 else PLine2 $ forceBasis [[GEZero 1], [GEPlus 1], [GEPlus 2]] pvec

-- | ensure all of the '0' components exist on a PLine2.
forcePPoint2Basis :: PPoint2 -> PPoint2
forcePPoint2Basis pt@(PPoint2 pvec@(GVec gvals)) = if length gvals == 3
                                                   then pt
                                                   else PPoint2 $ forceBasis [[GEZero 1, GEPlus 1], [GEZero 1, GEPlus 2], [GEPlus 1, GEPlus 2]] pvec

-- Normalization of euclidian points is really just cannonicalization.
canonicalizePPoint2 :: PPoint2 -> PPoint2
canonicalizePPoint2 (PPoint2 vec@(GVec vals)) = PPoint2 $ divVecScalar vec $ valOf 1 $ getVals [GEPlus 1, GEPlus 2] vals


-- The idealized norm of a euclidian projective point.
idealNormPPoint2 :: PPoint2 -> ℝ
idealNormPPoint2 (PPoint2 (GVec vals)) = sqrt (x*x+y*y)
  where
    x = negate $ valOf 0 $ getVals [ GEZero 1, GEPlus 2] vals
    y =          valOf 0 $ getVals [ GEZero 1, GEPlus 1] vals

-- Normalize a PLine2. 
normalizePLine2 :: PLine2 -> PLine2
normalizePLine2 pl@(PLine2 vec) = PLine2 $ divVecScalar vec $ normOfPLine2 pl 

normOfPLine2 :: PLine2 -> ℝ
normOfPLine2 pline = sqrt $ sqNormOfPLine2 pline

sqNormOfPLine2 :: PLine2 -> ℝ
sqNormOfPLine2 (PLine2 (GVec vals)) = a*a+b*b
  where
    a = valOf 0 $ getVals [GEPlus 1] vals
    b = valOf 0 $ getVals [GEPlus 2] vals

-- reverse a line. same line, but the other direction.
flipPLine2 :: PLine2 -> PLine2
flipPLine2 (PLine2 (GVec vals)) = PLine2 $ GVec $ foldl addVal []
                                  [
                                    GVal (negate $ valOf 0 $ getVals [GEZero 1] vals) [GEZero 1]
                                  , GVal (negate $ valOf 0 $ getVals [GEPlus 1] vals) [GEPlus 1]
                                  , GVal (negate $ valOf 0 $ getVals [GEPlus 2] vals) [GEPlus 2]
                                  ]

-- | Translate a line a given amound along it's perpendicular bisector.
translatePerp :: PLine2 -> ℝ -> PLine2
translatePerp pl1 d = PLine2 $ addVecPair m $ rawPLine pl1
  where
    m = GVec [GVal (d*normOfPLine2 pl1) [GEZero 1]]
    rawPLine (PLine2 a) = a


-- | find a point a given distance along a line perpendicularly bisecting this line at a given point.
pointOnPerp :: Line -> Point2 -> ℝ -> Point2
pointOnPerp line point d = fromJust $ ppointToPoint2 $ canonicalizePPoint2 $ PPoint2 $ (motor•pvec)•reverse motor
  where
    (PLine2 lvec) = forcePLine2Basis $ normalizePLine2 $ eToPLine2 line
    (PPoint2 pvec) = forcePPoint2Basis $ canonicalizePPoint2 $ eToPPoint2 point
    -- FIXME: the dot product should be doing this. -- lvec ⋅ pvec
    (PLine2 perpLine) = forcePLine2Basis $ PLine2 $ vectorPart $ lvec ⎤ pvec
    motor = forceBasis [[G0], [GEPlus 1, GEPlus 2], [GEZero 1, GEPlus 1], [GEZero 1, GEPlus 2]] $ addVecPair (mulScalarVec (d/2) $ perpLine • gaI) (GVec [GVal 1 [G0]])
    -- I, in this geometric algebra system.
    gaI :: GVec
    gaI = GVec [GVal 1 [GEZero 1, GEPlus 1, GEPlus 2]]


