//-*- coding:utf-8 -*-

//
// Pentomino Puzzle Solver with Swift
//

import Foundation

var dbg_flag: Bool = false

let PIECE_DEF_DOC = """
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
func piece_def( _ id: String ) -> [[Int]] {
    var def : [[Int]] = []
    var x : Int = 0,  y : Int = 0
    for ch in PIECE_DEF_DOC.map( {String( $0 ) } ) {
        if ( ch == id )   { def.append( [ x/2, y ] ) }
        if ( ch == "\n" ) { y += 1;   x = 0 }
        else              { x += 1          }
    }
    return def
}

///////////////////////////////////////////////////////////

class Piece {
    class Fig : Equatable {
        var pts: [[Int]]

        init( _ pts: [[Int]] ) {  self.pts = pts  }

        static func ==( a: Fig, b: Fig ) -> Bool { return a.pts == b.pts }

        func to_s() -> String {
            return "[" +
              pts.map{ pt in
                  String( format: "(%d,%d)", pt[0], pt[1] )
              }.joined(separator: ", ") +
              "]"
        }

    }

    var id : String
    var figs : [Fig]
    var next : Piece?

    init( id : String, def: [[Int]], next: Piece? ) {
        self.id   = id
        self.figs = []
        self.next = next

        for r_f in  0 ..< 8  {     // rotate & flip
            var pts = def.map{
                var xy: [Int] = $0 // copy
                for _ in 0 ..< r_f % 4 { xy = [ -xy[1], xy[0] ] }  // rotate
                if  r_f >= 4           { xy = [ -xy[0], xy[1] ] }  // flip
                return xy
            }.sorted( by: { (a:[Int], b:[Int]) -> Bool in          // sort
                          a[1] == b[1] ? (a[0] < b[0]) : (a[1] < b[1])
                      }
            )
            if pts.count > 0 {
                let o = pts[0]                                     // normalize
                pts = pts.map{ xy in [ xy[0] - o[0], xy[1] - o[1] ] }
            }
            let fig = Fig( pts )
            if figs.firstIndex( of: fig ) == nil {                 // uniq
                figs.append( fig )
            }
        }
        if dbg_flag {
            print( "\(id): (\(figs.count)) " )
            for fig in figs {
                print( "\t", fig.to_s() )
            }
        }
    }
}


///////////////////////////////////////////////////////////

class Board {
    var cells: [[String]]
    var width : Int,  height : Int
    let SPACE = " "

    init( _ width: Int, _ height: Int ) {
        self.width  = width
        self.height = height
        self.cells  = Array( repeating:
                               Array( repeating: SPACE, count: width ),
                             count: height )
        if width * height == 64 {
            let cx = width / 2, cy = height / 2
            cells[ cy - 1 ][ cx - 1 ] = "?"; cells[ cy - 1 ][ cx ] = "?"
            cells[ cy     ][ cx - 1 ] = "?"; cells[ cy     ][ cx ] = "?"
        }
    }


    func at( _ x:Int, _ y:Int ) -> String {
        return  ( x >= 0 && x < width && y >= 0 && y < height ) ?
          cells[ y ][ x ] : "?"
    }


    func check( _ x:Int, _ y:Int, _ fig:Piece.Fig ) -> Bool {
        return fig.pts.allSatisfy{ pt in at( x + pt[0], y + pt[1] ) == SPACE }
    }


    func place( _ x:Int, _ y:Int, _ fig: Piece.Fig, id:String ) {
        for pt in fig.pts { cells[ y + pt[1] ][ x + pt[0] ] = id  }
    }


    func find_space( _ xy: inout[Int] ) {
        var x = xy[0],  y = xy[1]
        while cells[ y ][ x ] != SPACE {
            x = (x + 1) % width
            if x == 0 { y += 1 }
        }
        xy[0] = x;  xy[1] = y
    }

    //         2
    // (-1,-1) | (0,-1)
    //     4 --+-- 1
    // (-1, 0) | (0, 0)
    //         8
    let ELEMS = [
      //0        3     5     6    7      9    10   11   12   13   14   15
      "    , , ,+---, ,----,+   ,+---, ,+---,|   ,+---,+   ,+---,+   ,+---",
      "    , , ,    , ,    ,    ,    , ,|   ,|   ,|   ,|   ,|   ,|   ,|   "
    ].map{ $0.split( separator: ",").map{ String($0) } }

    func render() -> String {
        return ( 0 ... height ).map { y in
            ( 0 ..< 2 ).map { d in
                ( 0 ... width ).map { x in
                    let code =
                      ( ( at( x+0, y+0 ) != at( x+0, y-1 ) ) ? 1 : 0 ) |
                      ( ( at( x+0, y-1 ) != at( x-1, y-1 ) ) ? 2 : 0 ) |
                      ( ( at( x-1, y-1 ) != at( x-1, y+0 ) ) ? 4 : 0 ) |
                      ( ( at( x-1, y+0 ) != at( x+0, y+0 ) ) ? 8 : 0 )
                    return ELEMS[ d ][ code ]
                }.joined()
            }
        }.flatMap{ $0 }.joined( separator: "\n" )
    }
}


///////////////////////////////////////////////////////////

class Solver {
    var board: Board
    var Unused: Piece?
    var solutions: Int

    init( _ width: Int, _ height: Int ) {
        board = Board( width, height )

        var pc: Piece? = nil
        // the first 'X' is dummy
        for id in ("FLINPTUVWXYZ".map({ String( $0 ) })).reversed() {
            pc = Piece( id: id, def: piece_def( id ), next: pc )
        }
        Unused   = Piece( id: "!", def: [], next: pc )    // duemy piece
        // limit the symmetry of 'F'
        pc!.figs = Array( pc!.figs[0..<((width == height) ? 1 : 2) ] )
        solutions = 0
    }

    func solve( _ x: Int,  _ y: Int ) {
        var prev: Piece = Unused!
        if prev.next != nil {
            var xy = [ x, y ]
            board.find_space( &xy )
            let x = xy[0]
            let y = xy[1]
            while let pc = prev.next {
                prev.next = pc.next
                for fig in pc.figs {
                    if board.check( x, y, fig ) {
                        board.place( x, y, fig, id: pc.id )
                        solve( x, y )
                        board.place( x, y, fig, id: board.SPACE )
                    }
                }
                prev.next = pc
                prev = pc
            }
        } else {
            solutions += 1
            let curs_up = solutions > 1 ?
              String( format: "\u{001b}[%dA", board.height * 2 + 2 ) : ""
            print( curs_up + board.render(), solutions )
        }
    }
}

///////////////////////////////////////////////////////////

signal( SIGINT, { signal in
                    NSLog( "Got signal: \(signal)" )
                    exit( 1 )
                })
var width  =  6
var height = 10

for arg in CommandLine.arguments {
    if arg == "--debug" {
        dbg_flag = true
    }
    let sz = arg.split( separator: "x").map{ Int( $0 ) ?? 0 }
    if sz.count == 2 && sz[0] >= 3 && sz[1] >= 3 &&
         ( sz[0] * sz[1] == 60 || sz[0] * sz[1] == 64 ) {
        width  = sz[0]
        height = sz[1]
    }
}

let solver = Solver( width, height )
solver.solve( 0, 0 )
