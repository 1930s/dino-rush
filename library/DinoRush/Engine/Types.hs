module DinoRush.Engine.Types where

import qualified SDL
import qualified SDL.Mixer as Mixer
import qualified Animate

import Control.Lens
import Data.Text (Text)
import Data.Aeson (FromJSON, ToJSON)
import System.Random

type Animations key = Animate.Animations key (Animate.SpriteClip key) Seconds
type DrawSprite key m = Animate.SpriteClip key -> (Int, Int) -> m ()

newtype Lives = Lives Int
  deriving (Show, Eq, Num, Integral, Real, Ord, Enum)

newtype Percent = Percent Float
  deriving (Show, Eq, Num, Fractional, RealFrac, Real, Ord)

newtype Distance = Distance Integer
  deriving (Show, Eq, Num, Integral, Real, Ord, Enum, Random)

newtype Seconds = Seconds Float
  deriving (Show, Eq, Num, ToJSON, FromJSON, Fractional, Ord)

newtype Score = Score Int
  deriving (Show, Eq, Num, Integral, Real, Ord, Enum)

clamp :: Percent -> Percent -> Percent
clamp cur max' = if cur > max' then max' else cur