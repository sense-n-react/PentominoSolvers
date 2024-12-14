// -*- coding:utf-8 -*-

//
// Pentomino Puzzle Solver with Groovy
//

class G {
  static debug_flg = false

  static PIECE_DEF_DOC =
'''
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
'''

  static piece_def( String id ) {
    def pc_def = []
    PIECE_DEF_DOC.trim().split( "\n" ).eachWithIndex{ line, y ->
      line.eachWithIndex{ c, x ->
        if ( c == id )  pc_def << [ (int)(x/2), y ]
      }
    }
    return pc_def
  }
}

///////////////////////////////////////////////////////////

class Piece {
  String id
  List   figs
  Piece  next

  Piece( String id, List fig_def, Piece next_pc ) {
    this.id   = id
    this.next = next_pc
    figs = (0 ..< 8).collect { r_f ->              // rotate & flip
      def fig = fig_def.collect { x, y ->
        ( 0 ..< r_f % 4 ).each {
          (x, y) = [-y, x]                                    // rotate
        }
        r_f < 4 ? [x, y] : [-x, y]                            // flip
      }.sort { a, b ->                                        // sort
        a[1] == b[1] ? a[0] <=> b[0] : a[1] <=> b[1]
      }
      fig.collect { [it[0] - fig[0][0], it[1] - fig[0][1]] }  // normalize
    }.unique()                                                // uniq
    if ( G.debug_flg ) {
      println "${id}: (${figs.size()})"
      figs.each { println "    $it" }
    }
  }
}

///////////////////////////////////////////////////////////

class Board {
  int  width
  int  height
  List cells
  static final String SPACE = " "

  Board( int w, int h ) {
    width  = w
    height = h
    cells  = (0 ..< height).collect { (0 ..< width).collect { SPACE } }
    if ( w * h ==  64 ) {       // 8x8 or 4x16
      int cx = w / 2 - 1;  int cy = h / 2 - 1
      place( cx, cy, [ [0,0], [0,1], [1,0], [1,1] ], '@' )
    }
  }


  String at( int x, int y ) {
    return (x >= 0 && x < width && y >= 0 && y < height) ? cells[y][x] : "?"
  }


  def check( int ox, int oy, List fig ) {
    fig.every { at(it[0] + ox, it[1] + oy) == SPACE }
  }


  def place( int ox, int oy, List fig, String id ) {
    fig.each { cells[ it[1] + oy ][ it[0] + ox ] = id }
  }


  def find_space( int x, int y ) {
    while ( cells[ y ][ x ] != SPACE ) {
      if ( (x += 1) == width) {
        x = 0
        y++
      }
    }
    return [x, y]
  }

  //         2
  // (-1,-1) | (0,-1)
  //   ---4--+--1----
  // (-1, 0) | (0, 0)
  //         8
  static ELEMS = [
    //0     3     5    6    7     9    10   11   12   13   14   15
    "    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---",
    "    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   "
  ].collect{ it.split( ',' ) }.transpose()

  def render() {
    (0..height).collect { y ->
      (0..width).collect { x ->
        ELEMS[ ((at(x+0, y+0) != at(x+0, y-1)) ? 1 : 0) |
               ((at(x+0, y-1) != at(x-1, y-1)) ? 2 : 0) |
               ((at(x-1, y-1) != at(x-1, y+0)) ? 4 : 0) |
               ((at(x-1, y+0) != at(x+0, y+0)) ? 8 : 0) ]
      }.transpose().collect { it.join() }
    }.flatten().join( "\n" )
  }
}

///////////////////////////////////////////////////////////

class Solver {
  Board board
  int   solutions
  Piece Unused

  Solver( int w, int h ) {
    board     = new Board( w, h )
    solutions = 0

    def pc = null
    'FLINPTUVWXYZ'.reverse().each { id ->
      pc = new Piece( id, G.piece_def( id ), pc )
    }
    Unused = new Piece( '!', [], pc )        // dummy piece
    // limit the symmetry of 'F'
    pc.next.figs = pc.next.figs[0 ..< ((w == h)? 1: 2)]
  }


  def solve( int x, int y ) {
    if ( Unused.next) {
      ( x, y ) = board.find_space( x, y )
      def prev = Unused
      while ( prev.next != null ) {
        def pc = prev.next
        prev.next = pc.next
        pc.figs.each { fig ->
          if (board.check( x, y, fig ) ) {
            board.place( x, y, fig, pc.id )
            solve( x, y )
            board.place( x, y, fig, Board.SPACE )
          }
        }
        prev = ( prev.next = pc )
      }
    } else {
      solutions++
      def curs_up = (solutions > 1)? "\033[${board.height * 2 + 2}A" : ""
      printf( "%s%s%d\n", curs_up, board.render(), solutions )
    }
  }

}

def main() {
  int width  = 6
  int height = 10
  args.each { arg ->
    if (  arg == "--debug" ) { G.debug_flg = true }
    def m = arg =~ /^(\d+)\D(\d+)$/
    if ( m.find() ) {
      ( w, h ) = [ m[0][1].toInteger(), m[0][2].toInteger() ]
      if ( w >= 3 && h >= 3 && ( w * h == 60 || w * h == 64 ) ) {
        (width, height) = [ w, h ]
      }
    }
  }

  solver_ = new Solver( width, height )
  solver_.solve( 0, 0 )
}

main()
