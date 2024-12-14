// -*- coding:utf-8 -*-

//
// Pentomino Puzzle Solver with JavaScript
//

"use strict";

Array.prototype.transpose = function() {
  return this[0]? this[0].map( (_, c) => this.map(r => r[c]) ) : [];
}

const PIECE_DEF =`
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

`.trim().split( /\n/ ).map( (ln, y) =>
  ln.split('').map( ( s, x ) =>
    [ s, Math.floor(x/2), y ]
  )
).flat().reduce( (h, [s, x, y] ) =>
  ( ( h[s] = (h[s] || []).concat( [[x,y]] ) ) && h ),
  {}
);
// --> Hash: { F: [ [  2, 2 ], [  3, 2 ], [  1, 3 ], [  2, 3 ], [  2, 4 ] ],
//             P: [ [ 17, 2 ], [ 18, 2 ], [ 17, 3 ], [ 18, 3 ], [ 17, 4 ] ],


//////////////////////////////////////////////////////

var debug_flg = false;

class Piece {

  constructor( id, fig_def, next_pc ) {
    this.id   = id;
    this.next = next_pc;
    this.figs = Array.from( {length:8}, ( _, r_f ) =>       // rotate & flip
      fig_def.map( ( [ x, y ] ) => {
        for ( let i = 0; i < r_f % 4; ++i ) { [x,y] = [-y,x] }   // rotate
        if  ( r_f >= 4 )                    { [x,y] = [-x,y] }   // flip
        return [ x, y ]
      }).sort( ( [x,y], [u,v] ) =>                               // sort
        ( y == v )? ( x - u ) : ( y - v )
      ).map( ( [x,y], _, [ [x0,y0] ] ) =>                        // normalize
        [ x - x0, y - y0 ]
      )
    ).filter( ( fig, idx, a ) =>                                 // uniq
      idx == a.findIndex( f => f.toString() == fig.toString() )
    );

    if ( debug_flg ) {
      console.log( "%s: (%d)", this.id, this.figs.length );
      for ( let fig of this.figs ) {
        console.log( "    [%s]", fig.map( pt => `(${pt})` ).join(", ") );
      }
    }
  }

} // class Piece

//////////////////////////////////////////////////////

class Board {
  static SPACE  = ' ';

  constructor( w, h ) {
    this.width  = w;
    this.height = h;
    this.cells  = Array( this.height ).fill( null ).
      map( _ => Array( this.width ).fill( Board.SPACE ) );
    if ( w * h == 64 ) {
      this.place( w/2-1, h/2-1, [ [0,0], [0,1], [1,0], [1,1] ], '@' );
    }
  }


  at( x, y ) {
    return ( x >= 0 && x < this.width &&
             y >= 0 && y < this.height )? this.cells[ y ][ x ] : "?";
  }


  check( ox, oy, fig ) {
    return fig.every( pt => this.at( pt[0] + ox, pt[1] + oy ) == Board.SPACE );
  }


  place( ox, oy, fig, id ) {
    for ( let pt of fig ) { this.cells[ pt[1] + oy ][ pt[0] + ox ] = id };
  }


  find_space( x, y ) {
    while ( this.cells[ y ][ x ] != Board.SPACE ) {
      x = ( x + 1 ) % this.width;
      if ( x == 0 )  ++y;
    }
    return [x,y];
  }

  //         2
  // (-1,-1) | (0,-1)
  //   ---4--+--1----
  // (-1, 0) | (0, 0)
  //         8
  static ELEMS = [
    //0      3     5    6    7     9    10   11   12   13   14   15
    "    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---",
    "    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   "
  ].map( s => s.split(/,/) ).transpose();

  render = () =>
    Array.from( {length: this.height + 1}, ( _, y ) =>
      Array.from( {length: this.width + 1}, ( _, x ) =>
        Board.ELEMS[ ( ( this.at(x+0,y+0) != this.at(x+0,y-1) )? 1: 0 ) |
                     ( ( this.at(x+0,y-1) != this.at(x-1,y-1) )? 2: 0 ) |
                     ( ( this.at(x-1,y-1) != this.at(x-1,y+0) )? 4: 0 ) |
                     ( ( this.at(x-1,y+0) != this.at(x+0,y+0) )? 8: 0 ) ]
      ).transpose().map( e => e.join('') )
    ).flat().join( "\n" )

}  // class Board

////////////////////////////////////////////////////////////////

class Solver {

  constructor( width, height ) {
    this.solutions = 0;
    this.board = new Board( width, height );

    let pc = null;
    for ( let id of 'FLINPTUVWXYZ'.split('').reverse() ) {
      pc = new Piece( id, PIECE_DEF[id], pc );
    };
    this.Unused  = new Piece( '!', [], pc );
    // limit the symmetric of 'F'
    pc.figs = pc.figs.slice( 0, ( width == height )? 1 : 2 );
  }


  solve( x, y ) {
    if ( this.Unused.next != null ) {
      [ x, y ] = this.board.find_space( x, y );
      let prev = this.Unused;
      let pc;
      while ( ( pc = prev.next ) != null ) {
        prev.next = pc.next;
        for ( let fig of pc.figs ) {
          if ( this.board.check( x, y, fig ) ) {
            this.board.place( x, y, fig, pc.id );
            this.solve( x, y );                         // call recursively
            this.board.place( x, y, fig, Board.SPACE ); // unplace
          }
        }
        prev = (prev.next = pc);
      }
    }
    else {
      this.solutions += 1;
      let curs_up = (this.solutions > 1)? `\x1b[${this.board.height * 2+ 2}A` : "";
      console.log( "%s%s%d", curs_up, this.board.render(), this.solutions );
    }
  }
}

////////////////////////////////////////////////////////////////


let width = 6, height = 10;
for ( let arg of process.argv ) {
  if ( arg == "--debug" )  debug_flg = true;
  let a = arg.match( /\d+/g );
  if ( a ) {
    let sz = a.map( s => parseInt(s) );
    if ( sz.length == 2 && sz[0] >= 3 && sz[1] >= 3 &&
         ( sz[0] * sz[1] == 60 || sz[0] * sz[1] == 64 ) ) {
      [ width, height ]  = sz
    }
  }
}

let solver = new Solver( width, height );
solver.solve( 0, 0 );
