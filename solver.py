# -*- coding:utf-8 -*-

#
# Pentomino Puzzle Solver with Python
#

import sys
import re
import math
from functools import reduce

class list_( list ) :
  def __init__( self, arg ) : super().__init__( arg )

  # re-define some functions as class method
  def flatten(self)   : return list_( [ e for inner in self for e in inner ] )
  def transpose(self) : return list_( map( list, zip( *self ) ) )
  def filter(self,fn) : return list_( filter(fn, self ) )
  def map(self,fn )   : return list_( map(fn, self ) )
  def map_idx(self,fn): return list_( map(fn, self, range( len(self) ) ) )
  def reduce(self,fn,ini) : return reduce(fn, self, ini)

##################################################

PIECE_DEF = list_( ('''
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

''').split( "\n" ) ).map_idx(
  lambda line, y : list_( line ).map_idx(
    lambda s, x : [ s, math.floor( x / 2 ), y ]
  )
).flatten().reduce(
  lambda h, sxy :
  h.update( { sxy[0]: (h[sxy[0]] if sxy[0] in h else []) + [sxy[1:]] } ) or h,
  {}
)
# --> Dic: { 'F': [[ 2, 3], [ 3, 3], [ 1, 4], [ 2, 4], [ 2, 5]],
#            'P': [[17, 3], [18, 3], [17, 4], [18, 4], [17, 5]],

##################################################

debug_flg       = False

class Piece:
  def __init__( self, id, fig_def, next_pc ):
    self.id   = id
    self.next = next_pc
    self.figs = []

    for r_f in range( 8 ):                           # rotate & flip
      fig = list_([])
      for x, y in fig_def:
        for r in range( r_f % 4 ) : x, y = -y, x     # rotate
        if r_f >= 4  : x = -x                        # flip
        fig.append( [x,y] )

      fig.sort( key=lambda pt: [ pt[1], pt[0] ] )    # sort

      fig = fig.map( lambda pt:                      # normalize
                     [ pt[0] - fig[0][0], pt[1] - fig[0][1] ] )
      if not fig in self.figs :                      # uniq
        self.figs.append( fig )

    global debug_flg
    if debug_flg :
      print( "%c: (%d)" % ( id, len( self.figs ) ) )
      for fig in self.figs :
        print( "    %s" % fig )

##################################################

class Board :
  SPACE  = ' '

  def __init__( self, w ,h ):
    self.width  = w
    self.height = h
    self.cells  = []
    for y in range( self.height ) :
      self.cells.append( [ Board.SPACE ] * self.width )
    if w * h == 64 :                 # 8x8 or 4x16
      self.place( int(w/2), int(h/2), [ [0,0], [0,1], [1,0], [1,1] ], '@' )
    return


  def at( self, x, y ):
    if x >= 0 and x < self.width and y >=0 and y < self.height :
      return self.cells[ y ][ x ]
    return '?'


  def check( self, ox, oy, fig ) :
    return all( self.at( x + ox, y + oy ) == Board.SPACE for x,y in fig )


  def place( self, ox, oy, fig, id ) :
    for x,y in fig :
      self.cells[ y + oy ][ x + ox ] = id
    return


  def find_space( self, x, y ) :
    while Board.SPACE != self.cells [ y ][ x ] :
      x += 1
      if x == self.width :
        x  = 0
        y += 1
    return [ x, y ]

  #         2
  # (-1,-1) | (0,-1)
  #   ---4--+--1----
  # (-1, 0) | (0, 0)
  #         8
  ELEMS = list_( [
    # 0      3     5    6    7     9    10   11   12   13   14   15
    '    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---',
    '    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   '
  ] ).map( lambda s : s.split( "," ) ).transpose()

  def render(self) :
    return "\n".join(
      list_( range( self.height + 1 ) ).map(
        lambda y :
        list_( range( self.width + 1 ) ).map(
          lambda x :
          Board.ELEMS[ ( 1 if self.at(x+0,y+0) != self.at(x+0,y-1) else 0 ) |
                       ( 2 if self.at(x+0,y-1) != self.at(x-1,y-1) else 0 ) |
                       ( 4 if self.at(x-1,y-1) != self.at(x-1,y+0) else 0 ) |
                       ( 8 if self.at(x-1,y+0) != self.at(x+0,y+0) else 0 )  ]
        ).transpose().map( lambda e : "".join( e ) )
      ).flatten()
    )


##################################################

class Solver :

  def __init__( self, width ,height ):
    self.solutions  = 0
    self.Unused       = None
    self.board      = Board( width, height )

    pc = None
    for id in reversed( 'FILNPTUVWXYZ' ) :
      pc = Piece( id, PIECE_DEF[ id ], pc )
    self.Unused = Piece( '!', [], pc )    # dummy piece
    # limit the symmetry of 'F'
    pc.figs = pc.figs[0:1] if width == height else pc.figs[0:2]

  def solve( self, x, y ) :
    if self.Unused.next != None :
      x, y = self.board.find_space( x, y )
      prev = self.Unused
      while prev.next != None :
        pc        = prev.next
        prev.next = pc.next
        for fig in pc.figs :
          if self.board.check( x, y, fig ) :
            self.board.place( x, y, fig, pc.id )
            self.solve( x, y )
            self.board.place( x ,y, fig, Board.SPACE )
        prev.next = pc
        prev      = pc
        continue  # while
    else :
      self.solutions += 1
      curs_up = "\033[%dA" % (self.board.height * 2 + 2) if self.solutions > 1 else ""
      print( "%s%s%d" % ( curs_up, self.board.render(), self.solutions ) )
    #sys.stdin.readline()
    return

##################################################

width, height = [6,10]
for arg in sys.argv[1:] :
  if arg == "--debug" : debug_flg = True
  sz = list( map(int, re.findall( r"\d+", arg )) )
  if len( sz ) == 2 and sz[0] >= 3 and sz[1] >= 3 and \
     ( sz[0] * sz[1] == 60 or sz[0] * sz[1] == 64 ) :
    width, height = sz

solver = Solver( width, height )
solver.solve(0,0)
