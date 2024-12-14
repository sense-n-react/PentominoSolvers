// -*- coding:utf-8 -*-

//
// Pentomino Puzzle Solver with Squirrel
//

PIECE_DEF_DOC <- @"
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
"
function piece_def( id )
{
  local ret = []
  local x = 0, y = 0;
  foreach( c in PIECE_DEF_DOC ) {
    if ( c.tochar() == id   ) { ret.append( [ x / 2, y ] );  }

    if ( c.tochar() == "\n" ) { y++; x = 0; }
    else                      { x++;        }
  }
  return ret;
}


function join( a, delim )
{
  return ( a.len() == 0 ) ? "" : a.reduce( @(p,c) p + delim + c )
}


function fig_to_s( fig )
{
  return format( "[%s]",
    join( fig.map( @(pt)  format( "(%2d,%2d)", pt[0], pt[0] ) ), "," )
  );
}

////////////////////////////////////////////////////////////////

debug_flg <- false

class Piece
{
  id    = null
  figs  = null
  next  = null

  constructor( id_, fig_def_, next_ )
  {
    id   = id_
    next = next_
    figs = []

    local figs_str = ""
    for ( local r_f = 0; r_f < 8; r_f++ ) {   // rotate and flip
      local fig = []
      foreach( xy_ in fig_def_ ) {
        local xy = [ xy_[0], xy_[1] ];
        for ( local i = 0; i < r_f % 4; i++ ) {            // rotate
          xy = [ -xy[1], xy[0] ]
        }
        if ( r_f >= 4 ) {                                  // flip
          xy = [ -xy[0], xy[1] ]
        }
        fig.append( xy )
      }
      fig.sort( @( p, q )                                  // sort
        (p[1] == q[1])? (p[0] - q[0]) : (p[1] - q[1] )
      )
      fig = fig.map( @( pt )                               // normalize
        [ pt[0] - fig[0][0], pt[1] - fig[0][1] ]
      )
      if ( figs_str.find( fig_to_s( fig ) ) == null ) {    // uniq
        figs.append( fig )
        figs_str += fig_to_s(fig)
      }
    }

    if ( debug_flg ) {
      print( format( "%s: (%d)\n%s\n",
          id_, figs.len(),
          join( figs.map( @(f) "    " + fig_to_s( f ) ), "\n" )
        ))
    }
  }
}

////////////////////////////////////////////////////////////////

class Board
{
  SPACE  = " "

  width  = null
  height = null
  cells  = null

  constructor( w, h )
  {
    width  = w
    height = h

    cells = array( height, [] )
    foreach( idx, _ in cells ) { cells[ idx ] = array( width, SPACE ) }
    if ( w * h == 64 ) {        // 8x8 or 4x16
      place( w/2 - 1, h/2 - 1,  [ [0,0], [0,1], [1,0], [1,1] ], "@" )
    }
  }


  function at( x, y )
  {
    return ( x >= 0 && x < width  && y >= 0 && y < height )? cells[y][x] : "?"
  }


  function check( ox, oy, fig )
  {
    foreach( pt in fig ) {
      if ( at( ox + pt[0], oy + pt[1] ) != SPACE ) return false
    }
    return true;
  }


  function place( ox, oy, fig, pc_id )
  {
    foreach( pt in fig ) { cells[ oy + pt[1] ][ ox + pt[0] ] = pc_id }
  }


  function find_space( x, y )
  {
    while ( SPACE != cells[ y ][ x ] ) {
      if ( ++x == width ) {
        x = 0
        ++y
      }
    }
    return [ x, y ]
  }

  //         2
  // (-1,-1) | (0,-1)
  //   ---4--+--1----
  // (-1, 0) | (0, 0)
  //         8
  ELEMS = [
    "    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---",
    "    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   "
  ].map( @( s )  split( s, "," ) )

  function render()
  {
    local lines = []
    for ( local y = 0; y <= height; y++ ) {
      for ( local d = 0; d < 2; d++ ) {
        local line = ""
        for(  local x = 0; x <= width; x++ ) {
          local code = 0
          if ( at( x+0, y+0 ) != at( x+0, y-1 ) ) code += 1
          if ( at( x+0, y-1 ) != at( x-1, y-1 ) ) code += 2
          if ( at( x-1, y-1 ) != at( x-1, y+0 ) ) code += 4
          if ( at( x-1, y+0 ) != at( x+0, y+0 ) ) code += 8

          line = line + ELEMS[d][ code ]
        }
        lines.append( line )
      }
    }
    return join( lines, "\n" )
  }

}

////////////////////////////////////////////////////////////////

class Solver
{
  solutions = 0
  board     = null
  Unused    = null

  constructor( width, height )
  {
    board     = Board( width, height )
    solutions = 0

    local pc = null
    foreach( id in split( "F L I N P T U V W X Y Z", " " ).reverse() ) {
      pc = Piece( id, piece_def( id ), pc )
    }
    Unused = Piece( "!", [], pc )
    // limit the symmetry of 'F'
    pc.figs = pc.figs.slice( 0, ( width == height )? 1 : 2 )
  }


  function solve( x, y )
  {
    if ( Unused.next != null ) {
      local xy = board.find_space( x, y )
      local x = xy[0], y = xy[1]
      local prev = Unused
      local pc
      while ( ( pc = prev.next) != null ) {
        prev.next = pc.next
        foreach( fig in pc.figs ) {
          if ( board.check( x, y, fig ) ) {
            board.place( x, y, fig, pc.id )
            solve( x y )
            board.place( x, y, fig, board.SPACE )
          }
        }
        prev = ( prev.next = pc )
      }
    }
    else {
      solutions += 1
      local curs_up = ( solutions > 1 )? format( "\x1b[%dA", board.height * 2 + 2 ) : ""

      print( format( "%s%s%d\n", curs_up,  board.render(), solutions ) )
    }
  }

}

////////////////////////////////////////////////////////////////

local width = 6, height = 10
foreach ( av in vargv ) {
  if ( av == "--debug" ) { debug_flg = true }

  local arry = regexp( @"^(\d+)\D(\d+)$" ).capture( av )
  if ( arry != null ) {
    local sz = arry.map( @(v) av.slice(v.begin, v.end).tointeger() ).slice(1,3)
    if ( sz[0] >= 3 && sz[1] >= 3 &&
       (sz[0] * sz[1] == 60 || sz[0] * sz[1] == 64 ) ) {
      width  = sz[0]
      height = sz[1]
    }
  }
}

solver <- Solver( width, height )
solver.solve( 0, 0 )
