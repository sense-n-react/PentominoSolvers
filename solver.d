// -*- coding:utf-8 -*-

//
// Pentomino Puzzle Solver with D
//

import std.stdio;
import std.string;
import std.conv;
import std.algorithm;
import std.array;
import std.container;
import std.regex;
import std.range;


immutable string PIECE_DEF_DOC = q{
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
};

struct Point { int x, y;    }
struct Fig   { Point[] pts; }

Fig[char] PIECE_DEF;
shared static this()
{
  foreach( y, line; PIECE_DEF_DOC.split( "\n" ) ) {
    foreach( x, c; line ) {
      if ( c !in PIECE_DEF ) { PIECE_DEF[c] = Fig();  }
      PIECE_DEF[c].pts ~= Point( cast(int)(x / 2), cast(int)y);
    }
  }
}

bool debug_flag = false;

//////////////////////////////////////////////////////////

class Piece
{
  char   id;
  Fig[]  figs;
  Piece  next;

  this( char id_, Fig def_, Piece next_ )
  {
    id   = id_;
    next = next_;
    if ( def_.pts.length == 0 ) return;

    foreach( r_f; 0 .. 8 ) {                 // rotate and flip
      auto fig = Fig( def_.pts.dup );        // copy
      foreach( ref xy; fig.pts ) {           // reference
        foreach( _; 0 .. r_f % 4 ) { xy   = Point( -xy.y, xy.x ); } // rotate
        if     ( r_f >= 4 )        { xy.x = -xy.x;  }               // flip
      }
      fig.pts.sort!( (a, b) => a.y != b.y ? a.y<b.y : a.x<b.x );    // sort
      foreach_reverse( ref pt; fig.pts ) {                          // normalize
        pt.x -= fig.pts[0].x;
        pt.y -= fig.pts[0].y;
      }
      if ( ! figs.canFind( fig ) ) {
        figs ~= fig;
      }
    }
    if ( debug_flag ) {
      writefln( "%c: (%d)", id, figs.length );
      foreach( fig; figs ) {
        writeln( "   ", fig.pts.map!( pt => [ pt.x, pt.y ] ) );
      }
    }
  } // this

} // class Piece


class Board
{
  static immutable char SPACE = ' ';
  static string[][]     ELEMS;

  int        width, height;
  char[][]   cells;

  this( int w, int h )
  {
    width  = w;
    height = h;
    cells  = new char[][h];
    foreach( i; 0 .. h ) {
      cells[i]   = new char[w];
      cells[i][] = SPACE;            // all elements
    }

    if ( w * h == 64 ) {     // 8x8 or 4x16
      place( Point( w / 2 - 1, h / 2 - 1 ),
             Fig( [ Point(0,0), Point(0,1), Point(1,0), Point(1,1) ] ),
             '@' );
    }
  } // this

  char at( int x, int y )
  {
    return ( x >= 0 && x < width && y >= 0 && y < height )? cells[y][x] : '?';
  }


  bool check( Point o, Fig fig )
  {
    return fig.pts.all!( pt => at( o.x + pt.x, o.y + pt.y ) == SPACE );
  }


  void place( Point o, Fig fig, char id )
  {
    foreach ( pt; fig.pts ) {
      cells[ o.y + pt.y ][ o.x + pt.x ] = id;
    }
  }


  Point find_space( ref Point xy )
  {
    auto x = xy.x,  y = xy.y;
    while ( cells[ y ][ x ] != SPACE ) {
      if ( ++x == width ) { x = 0;  ++y; }
    }
    return Point( x, y );
  }


  static this()
  {
    ELEMS = [
       "    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---",
       "    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   "
       ].map!( s => s.split(',') ).array.transposed.map!( r => r.array ).array;
  }

  string render()
  {
    return iota( height + 1 ).map!( y =>
      iota( width + 1 ).map!( x =>
        Board.ELEMS[ ( (at(x+0, y+0) != at(x+0, y-1)) ? 1 : 0 ) |
                     ( (at(x+0, y-1) != at(x-1, y-1)) ? 2 : 0 ) |
                     ( (at(x-1, y-1) != at(x-1, y+0)) ? 4 : 0 ) |
                     ( (at(x-1, y+0) != at(x+0, y+0)) ? 8 : 0 ) ]
      ).array.transposed.map!( elems => elems.join )
    ).joiner.join( "\n" );
  }

}  // class Board


class Solver
{
  int   solutions;
  Board board;
  Piece Unused;

  this( int width, int height )
  {
    solutions = 0;
    board     = new Board( width, height );

    Piece pc = null;
    foreach_reverse( c; "FILNPTUVWXYZ" ) {
      pc = new Piece( c, PIECE_DEF[c], pc );
    }
    Unused  = new Piece( '!', Fig(), pc );       // dumy piece
    // limit the symmetry of 'F'
    pc.figs = pc.figs[ 0 .. (width == height)? 1 : 2 ];
  }


  void solve( ref Point xy_ )
  {
    Piece prev = Unused;
    if ( prev.next !is null ) {
      Point xy = board.find_space( xy_ );
      Piece pc = null;
      while ( (pc = prev.next) !is null ) {
        prev.next = pc.next;
        foreach ( fig; pc.figs ) {
          if ( board.check( xy, fig ) ) {
            board.place( xy, fig, pc.id );
            solve( xy );
            board.place( xy, fig, Board.SPACE );
          }
        }
        prev = (prev.next = pc);
      }
    }
    else {
      ++solutions;
      auto curs_up =
        (solutions > 1)? format( "\033[%dA", board.height * 2 + 2 ) :  "";
      writeln( curs_up, board.render(), solutions );
    }
  }

}  // class Solver


void main( string[] args )
{
  int width = 6, height = 10;
  foreach ( arg; args[1 .. $] ) {
    auto m = match( arg, r"^(\d+)\S(\d+)$" );
    if ( m ) {
      int w = m.captures[1].to!int;
      int h = m.captures[2].to!int;
      if ( w >= 3 && h >= 3 && ( w * h == 60 || w * h == 64 ) ) {
        width  = w;
        height = h;
      }
    }
    if ( arg == "--debug" ) {
      debug_flag = true;
    }
  }

  auto solver = new Solver( width, height );
  auto zero   = Point(0,0);
  solver.solve( zero );
}
