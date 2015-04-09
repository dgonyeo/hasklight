module Hasklight.Animations.Spectrum where

import qualified Data.Vector as V
import GHC.Float
import Hasklight.LED

spectrum :: Color
         -> DisplaySize
         -> [Float]
         -> (Display,Animation)
spectrum c size bands = (colors,FFT $ spectrum c)
        where s' = fromIntegral size :: Double
              rangebounds = V.snoc (V.generate size (\x -> floor $ ((fromIntegral x) / s') ** 2 * (130) + 5)) 135
              ranges = V.map (\(x,y) -> if x /= y then (x,y) else (x,y+1)) $ V.zip rangebounds (V.tail rangebounds)
              values = V.map (\(x,y) -> (take (y-x) . drop x) bands) ranges
              strengths = V.map (\x -> (log (max (foldr (+) 0.0 x) 1) / 6) ^ (4 :: Int)) values
              colors = V.map (modC c . float2Double) strengths