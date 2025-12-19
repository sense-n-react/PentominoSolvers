// -*- coding:utf-8 -*-

//
// Pentomino Puzzle Solver with Dart
//

import 'dart:io';

////////////////////////////////////////////////////////

const String PIECE_DEF_DOC = '''
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
''';

Map<String, List<List<int>>> parsePieceDef() {
  var pieces = <String, List<List<int>>>{};

  PIECE_DEF_DOC.split('\n').asMap().forEach( (y, line) {
      line.split('').asMap().forEach( (x, s) {
          if ( s.trim().isNotEmpty ) {
            pieces.putIfAbsent( s, () => []).add( [x ~/ 2, y] );
          }
      });
  });
  return pieces;
}

///////////////////////////////////////////////////////
var debug_flag = false;

class Piece {
  String id;
  Piece? next;
  List<List<List<int>>> figs = [];

  Piece( this.id, List<List<int>> fig_def, this.next ) {
    if ( fig_def.length == 0 ) return;
    List<String> figs_str = [];
    figs = List.generate( 8, (r_f) {      // rotate & flip
        var fig = fig_def.map( (pt) {
            for ( var i = 0; i < r_f % 4; ++i ) {            // roate
              pt = [ -pt[1], pt[0] ];
            }
            return ( r_f < 4 )? pt : [ -pt[0], pt[1] ];      // flip
        }).toList()
        ..sort( (a, b) =>                                    // sort
          ( a[1] == b[1] )? a[0] - b[0] : a[1] - b[1]
        );
        var x0 = fig[0][0], y0 = fig[0][1];                  // normalize
        return fig.map( (pt) => [pt[0] - x0, pt[1] - y0] ).toList();
    })
    .where( (fig) {                                          // uniq
        if ( figs_str.indexOf( fig.toString() ) >= 0 ) { return false; }
        figs_str.add( fig.toString() );
        return true;
    }).toList();

    if ( debug_flag ) {
      print( "${id}: (${figs.length})" );
      for ( var fig in figs ) {
        print( "    ${fig}" );
      }
    }
  }

}  // class Piece


class Board {
  static const String SPACE = ' ';
  List<List<String>>  cells;
  int  width, height;

  Board( this.width, this.height )
  : cells = List.generate( height, (_) =>
    List.generate( width, (_) => SPACE, growable: false ), growable: false) {
    if ( width * height == 64 ) {
      place( width ~/ 2 - 1, height ~/ 2 - 1,
        [ [0,0], [0,1], [1,0], [1, 1] ], '@' );
    }
  }

  String at( int x, int y ) {
    return ( x >= 0 && x < width && y >= 0 && y < height )? cells[y][x] : '?';
  }

  bool check( int ox, int oy, List<List<int>> fig ) {
    return fig.every( (pt) => at(pt[0] + ox, pt[1] + oy ) == SPACE );
  }

  void place( int ox, int oy, List<List<int>> fig, String id ) {
    for ( var pt in fig ) {
      cells[pt[1] + oy][pt[0] + ox] = id;
    }
  }

  List<int> findSpace( int x, int y ) {
    while ( cells[y][x] != SPACE ) {
      if ( ++x  == width ) {
        x = 0;
        ++y;
      }
    }
    return [x, y];
  }

  //         2
  // (-1,-1) | (0,-1)
  //   ---4--+--1----
  // (-1, 0) | (0, 0)
  //         8
  static final List<List<String>> ELEMS = [
    //0      3     5    6    7     9    10   11   12   13   14   15
    "    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---",
    "    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   "
  ].map( (s) => s.split(',') ).toList();

  String render() {
    return List.generate( height + 1, (y) {
        var codes = List.generate( width + 1, (x) {
                       return ( ( at(x+0,y+0) != at(x+0,y-1) )? 1: 0 ) |
                              ( ( at(x+0,y-1) != at(x-1,y-1) )? 2: 0 ) |
                              ( ( at(x-1,y-1) != at(x-1,y+0) )? 4: 0 ) |
                              ( ( at(x-1,y+0) != at(x+0,y+0) )? 8: 0   );
                    });
        return ELEMS.map( (elem) => codes.map( (c) => elem[c] ) ).
                     map((e) => e.join(''));
    }).expand( (l) => l ).join("\n");
  }

}  // class Board


class Solver {
  int solutions = 0;
  Board board;
  Piece? unused;

  Solver( int width, int height )
  : board = Board( width, height ) {
    var piece_def = parsePieceDef();
    Piece? pc;
    for ( var id in 'FLINPTUVWXYZ'.split('').reversed ) {
      pc = Piece( id, piece_def[id]!, pc );
    }
    unused = Piece( '!', [], pc );
    // limit the symmetric of 'F'
    pc!.figs = pc.figs.take( ( width == height )? 1 : 2 ).toList();
  }

  void solve( int x, int y ) {
    if ( unused!.next != null ) {
      var space = board.findSpace( x, y );
      x = space[0];
      y = space[1];

      Piece prev = unused!;
      while ( true ) {
        Piece? pc = prev.next;
        if ( pc == null ) break;
        prev.next = pc.next;
        for ( var fig in pc.figs ) {
          if ( board.check( x, y, fig ) ) {
            board.place( x, y, fig, pc.id );
            solve( x, y );
            board.place( x, y, fig, Board.SPACE );
          }
        }
        prev = (prev.next = pc);
      }
    } else {
      solutions++;
      var curs_up = (solutions > 1)? "\x1b[${board.height * 2+ 2}A" : "";
      print( "${curs_up}${board.render()}${solutions}" );
    }
  }

}  // class Solver


void main( List<String> args ) {
  int width = 6, height = 10;
  for ( var arg in args ) {
    var matches = RegExp( r'^(\d+)\S(\d+)$' ).allMatches( arg );
    if ( matches.length == 1 ) {    // [ "12x5", "12", "5" ]
      var m = matches.elementAt(0);
      var w = int.parse( m[1]! ), h = int.parse( m[2]! );
      if ( w >= 3 &&  h >= 3 && ( w * h == 60 || w * h  == 64 ) ) {
        width  = w;
        height = h;
      }
    }
    if ( arg == "--debug" ) {
      debug_flag = true;
    }
  }

  var solver = Solver( width, height );
  solver.solve( 0, 0 );
}
