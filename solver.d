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
import std.string;


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

struct Point { int x, y;   }
struct Fig   { Point[] pt; }

Fig[char] piece_defs;
shared static this()
{
  foreach( y, line; PIECE_DEF_DOC.split( "\n" ) ) {
    foreach( x, c; line ) {
      if ( c !in piece_defs ) { piece_defs[c] = Fig();  }
      piece_defs[c].pt ~= Point( cast(int)(x / 2), cast(int)y);
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

  this( char id, Fig fig_def, Piece next )
  {
    this.id      = id;
    this.next    = next;
    if ( fig_def.pt.length is 0 ) return;

    foreach( r_f; 0 .. 8 ) {          // rotate and flip
      Fig fig;
      foreach( xy; fig_def.pt ) {
        foreach( _; 0 .. r_f % 4 ) { xy   = Point( -xy.y, xy.x ); } // rotate
        if     ( r_f >= 4 )        { xy.x = -xy.x;  }               // flip
        fig.pt ~= xy;
      }
      fig.pt.sort!( (a, b) => a.y != b.y ? a.y < b.y : a.x < b.x ); // sort
      foreach_reverse( i; 0 .. fig.pt.length ) {                    // normalize
        fig.pt[i].x -= fig.pt[0].x;
        fig.pt[i].y -= fig.pt[0].y;
      }
      if ( this.figs.canFind( fig ) == false ) {
        this.figs ~= fig;
      }
    }
    if ( debug_flag ) {
      writeln( format( "%c: (%d)", id, figs.length )  );
      foreach( fig; figs ) {
        writeln( "   ", fig.pt.map!( pt => [pt.x,pt.y] ) );
      }
    }
  } // this

} // class Piece


class Board
{
  static immutable char SPACE = ' ';
  static string[][] ELEMS;

  int width, height;
  char[][]   cells;

  this( int w, int h )
  {
    width  = w;
    height = h;
    cells  = new char[][h];
    foreach( i; 0 .. h ) {
      cells[i]   = new char[w];
      cells[i][] = SPACE;
    }

    if ( w * h == 64 ) {     // 8x8 or 4x16
      place( Point( w / 2 - 1, h / 2 - 1 ),
             Fig([ Point(0,0), Point(0,1), Point(1,0), Point(1,1) ] ),
             '@' );
    }
  } // this

  char at( int x, int y )
  {
    return (x >= 0 && x < width && y >= 0 && y < height) ? cells[y][x] : '?';
  }


  bool check( Point o, Fig fig )
  {
    return fig.pt.all!( pt => at( o.x + pt.x, o.y + pt.y ) == SPACE );
  }


  void place( Point o, Fig fig, char id )
  {
    foreach ( pt; fig.pt ) {
      cells[o.y + pt.y][o.x + pt.x] = id;
    }
  }


  Point find_space( ref Point xy_ )
  {
    auto x = xy_.x,  y = xy_.y;
    while ( cells[ y ][ x ] != SPACE ) {
      if ( ++x == this.width ) { x = 0;  ++y; }
    }
    return Point( x, y );
  }

  static this()
  {
    ELEMS =
      [
       "    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---",
       "    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   "
       ].map!( s => s.split( "," ) ).array;
  }

  string render()
  {
    string[] result;
    foreach( y; 0 .. height + 1 ) {
      foreach( d; 0 .. 2 ) {
        result ~= "";
        foreach( x; 0 .. width + 1 ) {
          int code =
            ( (at(x + 0, y + 0) != at(x + 0, y - 1)) ? 1 : 0 ) |
            ( (at(x + 0, y - 1) != at(x - 1, y - 1)) ? 2 : 0 ) |
            ( (at(x - 1, y - 1) != at(x - 1, y + 0)) ? 4 : 0 ) |
            ( (at(x - 1, y + 0) != at(x + 0, y + 0)) ? 8 : 0 );
          result[ result.length -1 ] ~= Board.ELEMS[d][code];
        }
      }
    }
    return result.join( "\n" );
  }

}  // class Board


class Solver
{
  int solutions;
  Board board;
  Piece Unused;

  this( int width, int height )
  {
    solutions = 0;
    board     = new Board(width, height);
    Piece pc  = null;
    string ids = "FILNPTUVWXYZ";
    foreach_reverse( c; ids ) {
      pc = new Piece( c, piece_defs[c], pc );
    }
    pc.figs = pc.figs[ 0 .. (width == height)? 1 : 2 ];
    Unused = new Piece( '!', Fig(), pc );
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
      auto curs_up = "";
      if ( solutions > 1 ) {
        curs_up = format( "\033[%dA", board.height * 2 + 2 );
      }
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
      if ( w >= 3 && h >= 3 && (w * h == 60 || w * h == 64) ) {
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
