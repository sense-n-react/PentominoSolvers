-- -*- coding:utf-8 -*-

--
-- Pentomino Puzzle Solver with Haskell
--

import System.IO (hFlush, stdout)
import System.Environment (getArgs)
import Data.List (sort, sortBy, transpose, (\\), group)
import Data.Char (isDigit)
import qualified Data.Vector as V
import Control.Monad (guard, when, forM_)
import Text.Printf

piece_Doc :: [String]
piece_Doc =
    [
   "+-------+-------+-------+-------+-------+-------+",
   "|       |   I   |  L    |  N    |       |       |",
   "|   F F |   I   |  L    |  N    |  P P  | T T T |",
   "| F F   |   I   |  L    |  N N  |  P P  |   T   |",
   "|   F   |   I   |  L L  |    N  |  P    |   T   |",
   "|       |   I   |       |       |       |       |",
   "+-------+-------+-------+-------+-------+-------+",
   "|       | V     | W     |   X   |    Y  | Z Z   |",
   "| U   U | V     | W W   | X X X |  Y Y  |   Z   |",
   "| U U U | V V V |   W W |   X   |    Y  |   Z Z |",
   "|       |       |       |       |    Y  |       |",
   "+-------+-------+-------+-------+-------+-------+"
    ]

type Point = (Int, Int)
type Fig   = [Point]
type Piece = (Char, [Fig])

-- helper function
splitOn :: Char -> String -> [String]
splitOn _ "" = []
splitOn c s =
    let (w, rest) = break (== c) s
    in w : case rest of
             []     -> []
             (_:r)  -> splitOn c r

--
-- Pieces
--
parsePieces :: [Piece]
parsePieces =
    let coords = [ (c, (x `div` 2, y)) | (y, line) <-
                     zip [0..] piece_Doc, (x, c) <-
                     zip [0..] line, c >= 'A' && c <= 'Z' ]
        ids = distinct $ map fst coords
        getFig id = [ p | (c, p) <- coords, c == id ]
    in [ (id, allVariations $ getFig id ) | id <- ids ]

-- rotate, flip, normalize
allVariations :: Fig -> [Fig]
allVariations fig = distinct $ map normalize $
    let rotations f = take 4 $ iterate rotate f
    in rotations fig ++ rotations (flip fig)
  where
    rotate = map (\(x, y) -> (-y, x))
    flip   = map (\(x, y) -> (-x, y))
    normalize f =
        let sorted@( (x0, y0):_ ) =
              sortBy (\(x1, y1) (x2, y2) -> compare (y1, x1) (y2, x2) ) f
        in [ (x - x0, y - y0) | (x, y) <- sorted ]

-- uniq
distinct :: (Ord a) => [a] -> [a]
distinct = map (\(x:_) -> x) . group . sort

--
-- Board
--
data Board = Board
    { width  :: Int,
      height :: Int,
      cells  :: V.Vector Char
    }

init_board :: Int -> Int -> Board
init_board w h =
  Board
  { width  = w,
    height = h,
    cells  = V.generate (w * h) $ \i ->
        let ( x, y )  =  ( i `mod` w, i `div` w )
        in if w * h == 64 then
            let ( w2, h2 ) = ( w `div` 2, h `div` 2 )
            in if x `elem` [w2-1, w2] && y `elem` [h2-1, h2] then '@' else ' '
             else ' '
  }

at :: Board -> Int -> Int -> Char
at bd x y =
    if x >= 0 && x < width bd && y >= 0 && y < height bd
    then (cells bd) V.! (y * (width bd) + x)  else '?'

elems :: [[String]]
elems = [
  splitOn ',' "    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---",
  splitOn ',' "    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   "
  ]

render :: Board -> String
render bd =
    let at_ x y = at bd x y
        rows = do
            y <- [0..(height bd)]
            let codes = [ code x y | x <- [0..(width bd)] ]
                code x y =
                    (if at_ (x-0) (y-0) /= at_ (x-0) (y-1) then 1 else 0) +
                    (if at_ (x-0) (y-1) /= at_ (x-1) (y-1) then 2 else 0) +
                    (if at_ (x-1) (y-1) /= at_ (x-1) (y-0) then 4 else 0) +
                    (if at_ (x-1) (y-0) /= at_ (x-0) (y-0) then 8 else 0)
            [ concat [ (elems!!0) !! c | c <- codes ],
              concat [ (elems!!1) !! c | c <- codes ] ]
    in unlines rows

--
-- Solver core
--
solve :: Board -> [Piece] -> [Board]
solve bd []     = [bd] -- found a solution !
solve bd pieces =
    case V.elemIndex ' ' (cells bd) of
        Nothing -> [bd]
        Just idx -> do
            let ( x, y ) = ( idx `mod` (width bd), idx `div` (width bd) )
            (id, figs) <- pieces
            fig <- figs

            guard $ all (\(u, v) -> at bd (x + u) (y + v)  == ' ' ) fig

            let bd_  = bd { cells = (cells bd) V.// [
                              ( (x + u) + (y + v) * (width bd ), id) |
                              (u, v) <- fig ]
                          }
                rest = filter (\(i, _) -> i /= id) pieces
            solve bd_ rest

--
-- parse command line args
--
parseArgs :: [String] -> (Int, Int, Bool)
parseArgs args =
    let debug = "--debug" `elem` args
        w_h_str = [ s | s <- args, 'x' `elem` s ]
        def_sz  = (6,10)
        (w, h)  = case w_h_str of
            (x:_) -> case splitOn 'x' x of
                [ws, hs] ->
                    let (w_, h_) = ( read ws, read hs )
                    in if w_ * h_ `elem` [60, 64] then (w_, h_) else def_sz
                _ -> def_sz
            _ -> def_sz
    in ( w, h, debug )

--
-- main
--
main :: IO ()
main = do
    args <- getArgs
    let ( w, h, debug_flg ) = parseArgs args

    -- init Pieces
    let allPieces = parsePieces
    when debug_flg $ do
        forM_ allPieces $ \( id, figs ) -> do
            printf "%c: (%d)\n" id $ length figs
            forM_ (zip [1..] figs) $ \( n, fig ) -> do
                printf "    %s\n" $ show fig
    -- limit synmetrics of 'F'
    let pieces = map ( \(id, fs ) ->
                         if id == 'F'
                         then (id, take (if w == h then 1 else 2) fs)
                         else (id, fs) )
                 allPieces

    -- init Board
    let bd = init_board w h

    let solutions = solve bd pieces

    forM_ ( zip [1..] solutions ) $ \(i, solBoard) -> do
        when ( i > 1 ) $ printf "\ESC[%dA" ( 2 * h + 3 )
        printf "%s%s\n" (render solBoard) $ show i
        hFlush stdout
