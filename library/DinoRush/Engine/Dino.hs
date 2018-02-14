module DinoRush.Engine.Dino where

import qualified Safe
import qualified Animate
import Data.Text (Text)
import Linear (V2(..))
import KeyState

import DinoRush.Engine.Camera
import DinoRush.Engine.Frame
import DinoRush.Engine.Types
import DinoRush.Engine.Obstacle
import DinoRush.Engine.Input
import DinoRush.Engine.Step
import DinoRush.Engine.Physics

data DinoAction
  = DinoAction'Move
  | DinoAction'Duck
  | DinoAction'Jump
  | DinoAction'Hurt
  deriving (Show, Eq)

data DinoState = DinoState
  { dsAction :: DinoAction
  , dsHeight :: Maybe Percent
  , dsRecover :: Maybe Percent
  } deriving (Show, Eq)

data DinoKey
  = DinoKey'Idle
  | DinoKey'Move
  | DinoKey'Kick
  | DinoKey'Hurt
  | DinoKey'Sneak
  deriving (Show, Eq, Ord, Bounded, Enum)

instance Animate.KeyName DinoKey where
  keyName = dinoKey'keyName

dinoKey'keyName :: DinoKey -> Text
dinoKey'keyName = \case
  DinoKey'Idle -> "Idle"
  DinoKey'Move -> "Move"
  DinoKey'Kick -> "Kick"
  DinoKey'Hurt -> "Hurt"
  DinoKey'Sneak -> "Sneak"

dinoX :: Float
dinoX = 200

dinoY :: Num a => a
dinoY = 16 * 26 - 8

duckCamera :: Camera
duckCamera = Camera (V2 ((dinoX + screenWidth) / 2) ((screenHeight + dinoY) / 2)) (V2 2 2)

rightEdge :: Float
rightEdge = arenaWidth - (dinoX + 48)

dinoHeight :: Maybe Percent -> Int
dinoHeight p = truncate (dinoHeight' p)

dinoHeight' :: Maybe Percent -> Float
dinoHeight' (Just (Percent percent)) = sin (percent * pi) * (-32 * 4) + dinoY
dinoHeight' _ = dinoY

dinoAabb :: Maybe Percent -> Aabb
dinoAabb maybeHeight = Aabb (V2 dinoX y) (V2 (dinoX + 32) (y + 48))
  where
    y = dinoHeight' maybeHeight

distanceFromLastObstacle :: [(Float, ObstacleTag)] -> Float
distanceFromLastObstacle obstacles = case Safe.lastMay obstacles of
  Nothing -> rightEdge
  Just (dist, _) -> rightEdge - dist

stepDinoAction :: Input -> DinoState -> Step DinoAction
stepDinoAction input ds = case da of
  DinoAction'Move -> case ksStatus (iUp input) of
    KeyStatus'Pressed -> Step'Change da DinoAction'Jump
    KeyStatus'Held -> Step'Change da DinoAction'Jump
    _ -> case ksStatus (iDown input) of
      KeyStatus'Pressed -> Step'Change da DinoAction'Duck
      KeyStatus'Held -> Step'Change da DinoAction'Duck
      _ -> Step'Sustain DinoAction'Move
  DinoAction'Duck -> case ksStatus (iUp input) of
    KeyStatus'Pressed -> Step'Change da DinoAction'Jump
    KeyStatus'Held -> Step'Change da DinoAction'Jump
    _ -> case ksStatus (iDown input) of
      KeyStatus'Pressed -> Step'Sustain DinoAction'Duck
      KeyStatus'Held -> Step'Sustain DinoAction'Duck
      _ -> Step'Change da DinoAction'Move
  DinoAction'Jump -> case dsHeight ds of
    Nothing -> Step'Change da DinoAction'Move
    Just p -> if p < 1 then Step'Sustain da else Step'Change da DinoAction'Move
  DinoAction'Hurt -> case dsRecover ds of
    Nothing -> Step'Change da DinoAction'Move
    Just p -> if p < 1 then Step'Sustain da else Step'Change da DinoAction'Move
  where
    da = dsAction ds

stepDinoState :: Step DinoAction -> DinoState -> DinoState
stepDinoState stepDa ds = case stepDa of
    Step'Change _ da -> case da of
      DinoAction'Jump -> DinoState da (Just 0) recover
      DinoAction'Hurt -> DinoState da height (Just 0)
      _ -> DinoState nextAction height recover
    Step'Sustain _ -> DinoState nextAction height recover
  where
    nextAction
      | recover /= Nothing = DinoAction'Hurt
      | height /= Nothing = DinoAction'Jump
      | otherwise = smash stepDa
    height = case dsHeight ds of
      Just p -> if p < 1 then Just (clamp (p + 0.04) 0 1) else Nothing
      Nothing -> Nothing
    recover = case dsRecover ds of
      Just p -> if p < 1 then Just (clamp (p + 0.02) 0 1) else Nothing
      Nothing -> Nothing

stepDinoPosition :: Step DinoAction -> Animations DinoKey -> Animate.Position DinoKey Seconds -> Animate.Position DinoKey Seconds
stepDinoPosition (Step'Sustain _) animations pos = Animate.stepPosition animations pos frameDeltaSeconds
stepDinoPosition (Step'Change _ da) _ _ = case da of
  DinoAction'Move -> Animate.initPosition DinoKey'Move
  DinoAction'Duck -> Animate.initPosition DinoKey'Sneak
  DinoAction'Jump -> Animate.initPositionLoops DinoKey'Kick 0
  DinoAction'Hurt -> Animate.initPosition DinoKey'Hurt

stepSpeed :: Step DinoAction -> Percent -> Percent
stepSpeed dinoAction speed = clamp speed' 1 20
  where
    speed'
      | Step'Sustain DinoAction'Duck == dinoAction = speed - 0.1
      | otherwise = speed + 0.03