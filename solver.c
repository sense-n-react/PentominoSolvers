// -*- coding:utf-8 -*-

//
// Pentomino Puzzle Solver with C
//

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define debug(a)        (void) (debug_flg? printf a : 0)
#define numOf(a)        (size_t)( (sizeof(a)/sizeof(*a)) )
#define new( p, T )     T* p = malloc(sizeof(T)); memset(p,0,sizeof(T))

const char* PIECE_DEF[] = {
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
};

typedef struct { int   x, y;  } Point;
typedef struct { Point pt[5]; } Fig;

const Fig *
piece_def( int id )
{
  static Fig fig;
  int  n = 0;
  for ( int y = 0; y < numOf(PIECE_DEF); ++y ) {
    for ( int x = 0; PIECE_DEF[y][x] != 0; ++x ) {
      if ( PIECE_DEF[y][x] == id && n < numOf(fig.pt) ) {
        fig.pt[n].x = x/2;
        fig.pt[n].y = y;
        n++;
      }
    }
  }
  return &fig;
}


//
// for debuging
// "[ ( 2,-1),( 0, 0),( 1, 0),( 2, 0),( 1, 1) ]"
//
const char*
fig_to_s( const Fig *fig )
{
  static char buf[80];
  sprintf( buf, "[ (%2d,%2d),(%2d,%2d),(%2d,%2d),(%2d,%2d),(%2d,%2d) ]",
           fig->pt[0].x, fig->pt[0].y,  fig->pt[1].x, fig->pt[1].y,
           fig->pt[2].x, fig->pt[2].y,  fig->pt[3].x, fig->pt[3].y,
           fig->pt[4].x, fig->pt[4].y
           );

 return buf;
}

/////////////////////////////////////////////////////////////

int debug_flg = 0;

typedef struct Piece
{
  char id;

  Fig  figs[8];             /* calced from base_fig[] */
  Fig  *fig_end;

  struct Piece *next;
} Piece;


int
cmp_point( const void *a, const void *b )
{
  const Point *p1 = (const Point *)a;
  const Point *p2 = (const Point *)b;
  return ( p1->y == p2->y )? ( p1->x - p2->x ) : ( p1->y - p2->y );
}

Piece *
new_piece( char id, const Fig *fig_def, Piece *next_ )
{
  new( this, Piece );

  this->next    = next_;
  this->id      = id;
  this->fig_end = this->figs;
  if ( fig_def == NULL ) return this;

  for ( int r_f = 0; r_f < 8; ++r_f ) {                  // rotate & flip
    Fig fig;

    for ( int i = 0; i < numOf(fig.pt); ++i ) {
      Point xy = fig_def->pt[i];
      for ( int r = 0; r < r_f % 4; ++r ) {              // rotate
        int  t = xy.x;
        xy.x = -xy.y;
        xy.y = t;
      }
      if ( r_f >= 4 )   xy.x = -xy.x;                    // flip
      fig.pt[i] = xy;
    }
                                                         // sort
    qsort( fig.pt, numOf(fig.pt), sizeof(fig.pt[0]), cmp_point );

    for ( int i = numOf(fig.pt) - 1; i >= 0; --i ) {     // normalize
      fig.pt[i].x -= fig.pt[0].x;
      fig.pt[i].y -= fig.pt[0].y;
    }

    {                                                    // uniq
      const Fig *f;
      for ( f = this->figs; f < this->fig_end; ++f ) {
        if ( memcmp( f, &fig, sizeof(fig) ) == 0 ) break;
      }
      if ( f == this->fig_end ) {
        * this->fig_end++ = fig;   // struct copy
      }
    }
  }

  debug(( "%c: (%d)\n", this->id, (int)(this->fig_end - this->figs) ));
  for ( const Fig *fig = this->figs; fig < this->fig_end; ++fig ) {
    debug(( "   %s\n", fig_to_s( fig ) ));
  }

  return this;
}

/////////////////////////////////////////////////////////////

#define SPACE   ' '

typedef struct Board
{
  int width, height;
  int **cells;

} Board;


char
at( const Board *this, int x, int y )
{
  if ( x >= 0 && x < this->width && y >= 0 && y < this->height )
    return this->cells[ y ][ x ];
  else
    return '?';
}


int
check( const Board *this, const Point* o, const Fig* fig )
{
  for ( size_t i = 0; i < numOf(fig->pt); ++i ) {
    if ( at( this, o->x + fig->pt[i].x, o->y + fig->pt[i].y ) != SPACE )
      return 0;
  }
  return !0;
}


void
place( Board *this, const Point* o, const Fig* fig, char id )
{
  for ( size_t i = 0; i < numOf(fig->pt); ++i ) {
    this->cells[ o->y + fig->pt[i].y ][ o->x + fig->pt[i].x ] = id;
  }
}


void
find_space( const Board *this, const Point* o, Point *result )
{
  int x = o->x;
  int y = o->y;
  while ( this->cells[ y ][ x ] != SPACE ) {
    if ( ++x == this->width ) { x = 0;  ++y; }
  }
  result->x = x;
  result->y = y;
}


Board *
new_board( int w, int h )
{
  new( this, Board );

  this->width  = w;
  this->height = h;

  this->cells = malloc( sizeof(int*) * h );

  for ( int i = 0; i < h; ++i ) {
    this->cells[ i ] = malloc( sizeof(int) * w );
    for ( int j = 0; j < w; ++j ) {
      this->cells[ i ][ j ] = SPACE;
    }
  }
  if ( w * h == 64 ) {     // 8x8 or 4x16
    Fig hole = {{ {0,0},{0,1},{1,0},{1,1},{1,1} }};
    Point  o = { w/2 -1, h/2 - 1 };
    place( this, &o, &hole, '@' );
  }
  return this;
}

//         2
// (-1,-1) | (0,-1)
//   ---4--+--1----
// (-1, 0) | (0, 0)
//         8
const char* ELEMS[2][16] = {
  { "    ", "", "", "+---", "", "----", "+   ", "+---", "", "+---", "|   ", "+---", "+   ", "+---", "+   ", "+---" },
  { "    ", "", "", "    ", "", "    ", "    ", "    ", "", "|   ", "|   ", "|   ", "|   ", "|   ", "|   ", "|   " }
};

const char *
render( const Board *this )
{
  static char result[ 1024 ];   // may be enough size
  result[0] = 0;
  for ( int y = 0; y <= this->height; y++ ) {
    for ( int d = 0; d < 2; d++ ) {
      for ( int x = 0; x <= this->width; x++ ) {
        int code =
          ( ( at( this, x+0, y+0 ) != at( this, x+0, y-1 ) )? 1 : 0 ) |
          ( ( at( this, x+0, y-1 ) != at( this, x-1, y-1 ) )? 2 : 0 ) |
          ( ( at( this, x-1, y-1 ) != at( this, x-1, y+0 ) )? 4 : 0 ) |
          ( ( at( this, x-1, y+0 ) != at( this, x+0, y+0 ) )? 8 : 0 );
        strcat( result, ELEMS[ d ][ code ] );
      }
      strcat( result, "\n" );
    }
  }

  return result;
}

/////////////////////////////////////////////////////////////

typedef struct Solver
{
  int   solutions;
  Board *board;
  Piece *Unused;

} Solver;


Solver*
new_solver( int width, int height )
{
  new( this, Solver );

  this->solutions = 0;
  this->board     = new_board( width, height );

  Piece *pc = NULL;
  char *ids = "FILNPTUVWXYZ";
  for ( int i = strlen( ids ) - 1; i >= 0; --i ) {
    int id = (int) ids[i];
    pc = new_piece( id, piece_def( id ), pc );
  }
  this->Unused = new_piece( '!', NULL, pc );     // dumy piece
  // limit the symmetry of 'F'
  pc->fig_end = pc->figs + ((width == height)? 1 : 2 );

  return this;
}


void
solve( Solver *this, const Point *xy_ )
{
  if ( this->Unused->next != NULL ) {
    Point xy;
    find_space( this->board, xy_, &xy );
    Piece *prev = this->Unused;
    Piece *pc;
    while ( ( pc = prev->next ) != NULL ) {
      prev->next = pc->next;

      for ( const Fig *fig = pc->figs; fig < pc->fig_end; ++fig ) {
        if ( check( this->board, &xy, fig ) ) {
          place( this->board, &xy, fig, pc->id );
          solve( this, &xy );
          place( this->board, &xy, fig, SPACE );
        }
      }

      prev = ( prev->next = pc );
    }
  }
  else {
    this->solutions++;
    char curs_up[16] = {0};

    if ( this->solutions > 1 ) {
      sprintf( curs_up, "\033[%dA", this->board->height * 2 + 3 );
    }
    printf( "%s%s%d\n", curs_up, render( this->board ), this->solutions );
    fflush(stdout);
  }
}


/////////////////////////////////////////////////////////////

int
main( int ac, char *av[] )
{
  int width = 6,  height = 10;
  for ( int i = 1; i < ac; ++i ) {
    if ( strcmp( "--debug", av[i] ) == 0 )  debug_flg = !0;
    int  w = 0, h = 0;
    char c = 0;
    sscanf( av[i], "%d%c%d", &w, &c, &h );
    if ( w >= 3 && h >= 3 && ( w * h == 60 || w * h == 64 ) ) {
      width  = w;
      height = h;
    }
  }

  Solver *solver = new_solver( width, height );
  Point zero = { 0, 0 };
  solve( solver, &zero );

  return 0;
}
