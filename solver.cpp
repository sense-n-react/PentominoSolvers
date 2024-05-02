// -*- coding:utf-8 -*-

//
// Pentomino Puzzle Solver with C++ (c++17)
//

const char* PIECE_DEF_DOC =R"(
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
)";


#include <iostream>
#include <algorithm>
#include <vector>
#include <sstream>
#include <map>

namespace std {
  std::string to_string( const char &c ) { return "'" + string(1, c) + "'"; }
  std::string to_string( const std::string &s ) { return s; }

  template< typename C >
  std::string
  join( const C& v,
        const char* delim = nullptr,
        const char* bracket = nullptr ) {
    std::string str;
    if ( !v.empty() ) {
      if ( delim == nullptr )  delim = "";
      auto it = v.begin();
      str += to_string( *it );
      while ( ++it != v.end() ) { str += delim + to_string( *it ); }
    }
    return bracket? ( bracket[0] + str + bracket[1] ) : str;
  }

  template<typename C>
  std::string
  to_string( const C &v ) {
    return join( v, ", ", "[]" );
  }

}


std::vector<std::string>
split( const std::string &s, char delim, bool f = true )
{
  std::vector<std::string> elems;
  std::stringstream ss(s);
  std::string item;
  while (getline(ss, item, delim)) {
    if ( f || !item.empty()) {
      elems.push_back(item);
    }
  }
  return elems;
}

/////////////////////////////////////////////////////////////

struct Point
{
  int x, y;

  Point( int x_ = 0 , int y_ = 0 ) : x( x_ ), y( y_ )  { }
};

bool
operator==( const Point &a, const Point &b )
{
  return a.y == b.y && a.x == b.x;
}


std::string
to_string( const Point &pt )
{
  return to_string( std::vector<int>( {pt.x, pt.y} ) );
}

using Fig  = std::vector<Point>;

///////////////////////////////////////////////////////////////

std::map<char,Fig> make_piece_def()
{
  std::map<char,Fig> fig_def;
  Point xy{ 0, 0 };
  for ( auto c : std::string( PIECE_DEF_DOC ) ) {
    if ( std::isalpha( c ) )  fig_def[ c ].push_back( { xy.x / 2, xy.y } );
    xy = ( c == '\n' )? Point{ 0, xy.y + 1 } : Point{ xy.x + 1, xy.y };
  }
  return fig_def;
}

std::map<char,Fig> PIECE_DEF = make_piece_def();

///////////////////////////////////////////////////////////////

bool debug_flg = false;

class Piece
{
public:
  std::vector<Fig> figs;
  char    id;
  Piece*  next = nullptr;

  Piece( char id_, const Fig& def_, Piece *next_ )
    : id ( id_ ), next( next_ )
  {
    for ( auto r_f = 0; r_f < 8; ++r_f ) {   // rotate and flip
      Fig fig = def_;            // copy

      for ( auto &p : fig ) {    // p: reference
        for ( auto n = 0; n < r_f % 4; ++n ) { p = { -p.y, p.x }; } // rotate
        if ( r_f >= 4 )                      { p = { -p.x, p.y }; } // flip
      }

      std::sort( fig.begin(), fig.end(),                            // sort
                 []( const auto&a, const auto&b ) {
                   return (a.y != b.y)? (a.y < b.y) : (a.x < b.x);
                 });

      for ( auto it = fig.rbegin(); it != fig.rend(); ++it ) {      // normalize
        it->x -= fig[0].x;
        it->y -= fig[0].y;
      }

      if ( std::find( figs.begin(), figs.end(), fig ) == figs.end() ) { // uniq
        figs.push_back( fig );
      }
    }

    if ( debug_flg ) {
      std::cout << id << " : (" << figs.size() << ")" << std::endl;
      for ( auto &fig : figs ) {
        std::cout << "    " << std::to_string( fig ) << std::endl;
      }
    }
  }

};  // class Piece

//         2
// (-1,-1) | (0,-1)
//   ---4--+--1----
// (-1, 0) | (0, 0)
//         8
const std::vector<std::string> ELEMS[2] = {
  //     0      3     5    6    7     9    10   11   12   13   14   15
  split("    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---", ','),
  split("    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   ", ',')
};

class Board
{
public:
  static constexpr char SPACE = ' ';

  int   width, height;
  std::vector<std::vector<char>> cells;

  Board( int w, int h )
  {
    width  = w;
    height = h;
    cells.assign( height, std::vector<char>( width, SPACE ) );
    if ( w * h == 64 ) {    // 8x8 or 4x16
      cells[ h/2 - 1 ][ w/2 - 1 ] = '@';  cells[ h/2 - 1 ] [ w/2 ] = '@';
      cells[ h/2     ][ w/2 - 1 ] = '@';  cells[ h/2     ] [ w/2 ] = '@';
    }
  }

  char
  at( int x, int y )
  {
    return (x >= 0 && x < width && y >= 0 && y < height)? cells[ y ][ x ] : '?';
  }


  bool
  check( const Point &o, const Fig &fig )
  {
    for ( const auto &pt : fig ) {
      if ( at( o.x + pt.x, o.y + pt.y ) != SPACE ) return false;
    }
    return true;
  }


  void
  place( const Point &o, const Fig &fig, char id )
  {
    for ( const auto &pt : fig ) {
      cells[ o.y + pt.y ][ o.x + pt.x ] = id;
    }
  }


  Point
  find_space( const Point &xy  )
  {
    auto x = xy.x;
    auto y = xy.y;

    while ( cells[ y ][ x ] != SPACE ) {
      if ( ++x == width )  { x = 0;  ++y; }
    }

    return Point( x, y );
  }


  std::string
  render()
  {
    std::vector<std::string> lines;

    for ( auto y = 0; y <= height; ++y ) {
      for ( auto d = 0; d < 2; ++d ) {
        lines.push_back( "" );
        for ( auto x = 0; x <= width; ++x ) {
          int code =
            ( ( at( x+0, y+0 ) != at( x+0, y-1 ) )? 1 : 0 ) |
            ( ( at( x+0, y-1 ) != at( x-1, y-1 ) )? 2 : 0 ) |
            ( ( at( x-1, y-1 ) != at( x-1, y+0 ) )? 4 : 0 ) |
            ( ( at( x-1, y+0 ) != at( x+0, y+0 ) )? 8 : 0 );
          lines.back() += ELEMS[ d ][ code ];
        }
      }
    }

    return join( lines, "\n" );
  }

}; // class Board


class Solver
{
  int    solutions;
  Board  &board;
  Piece  *Unused;

public:
  Solver( int width, int height ) :
    solutions( 0 ), board( *new Board(width, height) )
  {
    Piece *pc = nullptr;
    std::string ids( "FLINPTUVWXYZ" );   // the first 'X' is dummy
    for ( auto it = ids.rbegin(); it != ids.rend(); ++it ) {
      pc = new Piece( *it, PIECE_DEF[ *it ], pc );
    }
    Unused = new Piece( '!', Fig{}, pc );         // dumy piece
    // limit the symmetry of 'F'
    pc->figs.resize( (width == height)? 1 : 2);
  }


  void
  solve( const Point& xy_ )
  {
    if ( Unused->next != nullptr ) {
      auto xy = board.find_space( xy_ );
      Piece *prev = Unused;
      while ( Piece *pc = prev->next ) {
        prev->next = pc->next;
        for ( const auto &fig : pc->figs ) {
          if ( board.check( xy, fig ) ) {
            board.place( xy, fig, pc->id );
            solve( xy );
            board.place( xy, fig, Board::SPACE );
          }
        }
        prev = ( prev->next = pc );
      }
    }
    else {
      ++solutions;

      std::string curs_up = "";
      if ( solutions > 1 ) {
        curs_up = "\033[" + std::to_string( board.height * 2 + 2 ) + "A";
      }
      std::cout << curs_up << board.render() << solutions << std::endl;
    }
  }

};  // class Solver

int
main( int argc, char *argv[] )
{
  int width = 6,  height = 10;
  for ( auto i = 1; i < argc; ++i ) {
    if ( std::string( argv[i] ) == "--debug" ) debug_flg = true;
    if ( std::string( argv[i] ) == "-d"      ) debug_flg = true;
    int  w = 0, h = 0;
    char c = 0;
    std::istringstream( argv[i] ) >> w >> c >> h;
    if ( w >= 3 && h >= 3 && ( w * h == 60 || w * h == 64 ) ) {
      width  = w;
      height = h;
    }
  }

  Solver solver( width, height );
  solver.solve( Point( 0, 0 ) );

  return 0;
}
