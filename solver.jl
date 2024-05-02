# -*- coding:utf-8 -*-

#
# Pentomino Puzzle Solver with Julia
#

PIECE_DEF_DOC = """
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
PIECE_DEF = Dict{ Char, Vector{Vector{Int64}} }()
for ( y, line ) in enumerate( split( PIECE_DEF_DOC, "\n" ) )
  for ( x, s ) in enumerate( split( line, "" ) )
    c = string( s, " " )[1]      # s may be ""
    if !haskey( PIECE_DEF, c ); PIECE_DEF[c] = []; end
    push!( PIECE_DEF[c], [ floor(x/2), y ] )
  end
end
# PIECE_DEF = Dict(
# 'F' => [[ 2, 3], [ 3, 3], [ 1, 4], [ 2, 4], [ 2, 5]],
# 'P' => [[18, 3], [19, 3], [18, 4], [19, 4], [18, 5]], 

##################################################################

using Printf
const SPACE = ' '

debug_flg = false

mutable struct Piece
  id::Char
  figs::Vector{Vector{ Vector{Int64} }}
  next::Union{Piece,Nothing}

  function Piece( id_, def_, next_ )
    figs = map( 1:8 ) do  r_f            # rotate & flip
      fig = map( deepcopy( def_ ) ) do xy
        for n = 1 : r_f % 4                                    # rotate
          xy = [ -xy[2], xy[1] ]
        end
        xy[1] = r_f > 4 ? -xy[1] : xy[1]                       # flip
        xy
      end

      sort!( fig, by = xy -> [ xy[2], xy[1] ] )                # sort
                                                               # normalize
      map( xy -> [ xy[1] - fig[1][1], xy[2] - fig[1][2] ], fig )
    end

    unique!( figs )                                            # uniq

    if debug_flg
      println( id_, ": (", length( figs ), ")" )
      for fig in figs
        println( fig )
      end
    end

    new( id_, figs, next_ )
  end

end

##################################################################

mutable struct Board
  cells
  width::Int
  height::Int

  function Board( width, height )
    cells = fill( SPACE, height, width )
    if width * height == 64       # 8x8  or 4x16
      cx, cy = Int(width / 2), Int(height / 2)
      cells[ cy    , cx ] = '@';  cells[ cy    , cx + 1 ] = '@'
      cells[ cy + 1, cx ] = '@';  cells[ cy + 1, cx + 1 ] = '@'
    end
    new( cells, width, height )
  end
end  # Board


function at( self::Board, x, y )
  if x >= 1 && x <= self.width && y >= 1 && y <= self.height
    return self.cells[ y, x ]
  else
    return '?'
  end
end


function check( self::Board, ox, oy, fig )
  return all( xy -> at( self, xy[1] + ox, xy[2] + oy ) == SPACE, fig )
end


function place( self::Board, ox, oy, fig, id )
  for xy in fig
    self.cells[ oy + xy[2], ox + xy[1] ] = id
  end
end


function find_space( self::Board, x, y )
  while at( self, x, y ) != SPACE
    x = ( x % self.width ) + 1
    if x == 1; y += 1; end
  end
  return [ x, y ]
end



#         2
# (-1,-1) | (0,-1)
#   ---4--+--1----
# (-1, 0) | (0, 0)
#         8
ELEMS = map( s -> split( s, ',' ),
       #   0      3     5    6    7     9    10   11   12   13   14   15
       [ "    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---",
         "    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   " ]
     )

function render( self::Board )
  join( collect( Iterators.flatten( map( 1 : self.height + 1 ) do y
    map( 1 : 2 ) do d
      join( map( 1 : self.width + 1 ) do x
        code = 1 +
            ( at( self, x+0, y+0 ) != at( self, x+0, y-1 )  ? 1 : 0 ) +
            ( at( self, x+0, y-1 ) != at( self, x-1, y-1 )  ? 2 : 0 ) +
            ( at( self, x-1, y-1 ) != at( self, x-1, y+0 )  ? 4 : 0 ) +
            ( at( self, x-1, y+0 ) != at( self, x+0, y+0 )  ? 8 : 0 )
        ELEMS[ d ][ code ]
      end )
     end
  end )), '\n' )
end

##################################################################

mutable struct Solver
  board::Board
  Unused::Piece
  solutions::Int

  function Solver( width, height )
    pc = nothing
    for id in reverse( "FLINPTUVWXYZ" )    # the first 'X' is dummy
      pc = Piece( id, PIECE_DEF[id], pc )
    end
    # limit the symmetry of 'F'
    pc.figs = pc.figs[1: ((width == height) ? 1 : 2)]
    new( Board( width, height ) ,Piece( '!', [], pc ), 0 )
  end
end


function solve( self::Solver, x, y )
  if self.Unused.next != nothing
    x, y = find_space( self.board, x, y )
    prev = self.Unused
    while ( pl = prev.next ) != nothing
      prev.next = pl.next
      for fig in pl.figs
        if check( self.board, x, y, fig )
          place( self.board, x, y, fig, pl.id )
          solve( self, x, y )
          place( self.board, x, y, fig, SPACE )
        end
      end
      prev = ( prev.next = pl )
    end
  else
    self.solutions += 1
    curs_up = self.solutions > 1 ? @sprintf("\033[%dA", self.board.height * 2 + 2) : ""

    @printf( "%s%s%d\n", curs_up, render( self.board ), self.solutions )
  end
end

##################################################################

width, height = 6, 10

for arg in ARGS
  if arg == "--debug"
    global debug_flg = true
  end
  m = match( r"(\d+)x(\d+)", arg )
  if m != nothing
    w, h = map( s -> parse(Int,s), m.captures )
    if w >= 3 && h >= 3 && ( w * h == 60 || w * h == 64 )
      global width, height = w, h
    end
  end
end

solver = Solver( width, height )
solve( solver, 0, 0 )
