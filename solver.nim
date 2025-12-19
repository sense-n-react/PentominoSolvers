# -*- coding:utf-8 -*-

#
# Pentomino Puzzle Solver with Nim
#
import os, sequtils, re, strutils, algorithm, strformat
import tables, sugar

const PIECE_DEF_DOC = """
+-------+-------+-------+-------+-------+-------+
|       |   I   |  L    |  N    |       |       |
|   F F |   I   |  L    |  N    |  P P  | T T T |
| F F   |   I   |  L    |  N N  |  P P  |   T   |
|   F   |   I   |  L L  |    N  |  P    |   T   |
|       |   I   |       |       |       |       |
+-------+-------+-------+-------+-------+-------+
|       | V     | W     |   X   |    Y  | Z Z   |
| U   U | V     | W W   | X X X |  Y Y  |   Z   |
| U U U | V V V |   W W |   X   |    Y  |   Z Z |
|       |       |       |       |    Y  |       |
+-------+-------+-------+-------+-------+-------+
"""

type
  Point = tuple[ x: int, y: int ]
  Fig   = seq[ Point ]

var PIECE_DEF = initTable[ char, Fig ]()

for y, line in PIECE_DEF_DOC.splitLines().pairs():
  for x, c in line.pairs():
    if $c =~ re"\w":
      PIECE_DEF.mgetOrPut( c, @[] ).add( ( x div 2, y ) )

var debug_flg = false

#############################################################
#
# Piece
#
type
  Piece = ref object
    id:   char
    figs: seq[ Fig ]
    next: Piece


proc newPiece( id: char, pc_def: Fig, next: Piece ): Piece =
  var figs: seq[ Fig ] = @[]
  for rf in 0 ..< 8:
    var fig = pc_def;
    for _ in 0 ..< rf mod 4: fig = fig.mapIt( ( -it.y, it.x ) ) # rotate
    if rf >= 4:              fig = fig.mapIt( ( -it.x, it.y ) ) # flip
    fig.sort( (a, b:Point) =>  cmp((a.y, a.x), (b.y, b.x)) )    # sort
    fig = fig.mapIt( ( it.x - fig[0].x, it.y - fig[0].y ) )     # normalize
    if fig notin figs: figs.add( fig )                          # uniq

  if debug_flg:
    var n = figs.len()
    echo fmt"{id}: ({n})"
    for pts in figs:
      var str = pts.mapIt( fmt"({it.x},{it.y})" ).join(", " )
      echo "\t", fmt"[ {str} ]"

  Piece( id: id, figs: figs, next: next )

#############################################################
#
# Board
#
type
  Board = ref object
    width:  int
    height: int
    cells:  seq[seq[char]]

let SPACE = ' '
method place( o: Board, x: int, y: int, fig: Fig, id: char ) {.base.}

proc newBoard( w, h: int ): Board =
  let cells = newSeqWith( h, newSeqWith( w, SPACE ) )
  result = Board( width: w, height: h, cells: cells )
  if w * h == 64:            # 8x8 or 4x16
    result.place( ( w div 2 ) - 1, ( h div 2 ) - 1,
                  @[ (0,0), (0,1), (1,0), (1,1) ], '@' )


method at( o:Board, x: int, y: int ): char {.base.} =
  if x >= 0 and x < o.width and y >= 0 and y < o.height:
    o.cells[y][x]
  else:
    '?'


method check( o: Board, x: int, y: int, fig: Fig ): bool {.base.} =
  fig.allIt( o.at( x + it.x, y + it.y ) == SPACE )


method place( o: Board, x: int, y: int, fig: Fig, id: char ) {.base.} =
  for pt in fig:
    o.cells[ y + pt.y ][ x + pt.x ] = id


method find_space( o: Board, xx: int, yy: int ): Point {.base.} =
  var ( x, y ) = ( xx, yy )
  while o.cells[ y ][ x ] != SPACE:
    inc( x )
    if x == o.width:
      x = 0
      inc( y )
  ( x, y )


let ELEMS = @[
  "    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---",
  "    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   "
].mapIt( it.split( ',' ) )

method render( o: Board ): string {.base.} =
  toSeq( 0 .. o.height ).map( proc (y: int) : string =
    var codes = toSeq( 0..o.width ).map( proc (x: int): int =
      var ids = @[(0,0),(0,1),(1,1),(1,0)].mapIt( o.at( x-it[0], y-it[1] ) )
      ( ( if ids[0] != ids[1]: 1 else: 0 ) +
        ( if ids[1] != ids[2]: 2 else: 0 ) +
        ( if ids[2] != ids[3]: 4 else: 0 ) +
        ( if ids[3] != ids[0]: 8 else: 0 ) ) )
    ELEMS.map( (elem: seq[string]) => codes.map( (c: int) => elem[c] ).join()
    ).join( "\n" )
  ).join( "\n" )


#############################################################
#
# Solver
#
type
  Solver = ref object
    board:     Board
    unused:    Piece
    solutions: int


proc newSolver( width:int, height:int ): Solver =
  let board = newBoard( width, height )

  var pc: Piece = nil
  for id in "FLINPTUVWXYZ".toSeq.reversed():
    pc = newPiece( id, PIECE_DEF[ id ], pc )

  var unused = newPiece( '!', @[], pc )    # dummy piece
  # limit the symmetry of 'F'
  pc.figs = pc.figs[ 0.. (if width == height: 0 else: 1) ]

  Solver( board: board, solutions: 0, unused: unused )


method solve( o: Solver, x: int, y: int ) {.base.} =
  if o.unused.next != nil:
    let ( x, y ) = o.board.find_space( x, y )
    var prev = o.unused
    while prev.next != nil:
      var pc = prev.next
      prev.next = pc.next
      for fig in pc.figs:
        if o.board.check( x, y, fig ):
          o.board.place( x, y, fig, pc.id )
          o.solve( x, y )                 # call recursively
          o.board.place( x, y, fig, SPACE )
      prev.next = pc
      prev      = pc
  else:
    inc( o.solutions )
    let cursup = if o.solutions > 1:
                   fmt"{'\x1b'}[{ o.board.height * 2 + 2 }A"
                 else:
                   ""
    echo cursup, o.board.render(), o.solutions

#############################################################

var (width, height) = (6, 10)

for arg in commandLineParams():
  if arg == "--debug":  debug_flg = true

  if arg =~ re"(\d+)\D(\d+)":
     let ( w, h ) = ( parseInt( matches[0] ), parseInt( matches[1] ) )
     if w >= 3 and h >= 3 and ( w * h == 60 or w * h == 64 ):
       ( width, height ) = ( w, h )

let solver = newSolver( width, height )
solver.solve( 0, 0 )
