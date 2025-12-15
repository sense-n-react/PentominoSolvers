// -*- coding:utf-8 -*-

//
// Pentomino Puzzle Solver with Scala
//

import scala.collection.mutable.ArrayBuffer

////////////////////////////////////////////////////////////

def transpose[T](list: List[List[T]]): List[List[T]] =
  list.head.indices.map(i => list.map(_(i))).toList

////////////////////////////////////////////////////////////

val PIECE_DEF: Map[Char, List[List[Int]]] =
  """
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
    .split( "\n" )
    .zipWithIndex
    .flatMap { case ( line, y ) =>
      line.toCharArray.zipWithIndex.map { case (id, x) =>
        id -> List( x / 2, y )
      }
    }
    .groupMapReduce(_._1)( p => List( p._2 ) )( _ ++ _ )

////////////////////////////////////////////////////////////

case class Point( x: Int = 0, y: Int = 0 ) {
  override def toString: String = s"($x,$y)"
}

type Fig = List[Point]

var debugFlg = false

////////////////////////////////////////////////////////////

class Piece( val id: Char, figDef: List[List[Int]], var next: Piece | Null ) {
  var figs: ArrayBuffer[Fig] = ArrayBuffer()

  for ( r <- 0 until 8) {                // rotate & flip
    val fig = figDef.map { p =>
      var pt = Point( p(0), p(1) )
      for ( _ <- 0 until (r % 4)) pt = Point( -pt.y, pt.x )   // rotate
      if  ( r >= 4 )              pt = Point( -pt.x, pt.y )   // flip
      pt
    }.sortBy( p => p.x + p.y * 100 )                         // sort

    val norm = fig.map( p =>                                 // normalize
      Point( p.x - fig.head.x, p.y - fig.head.y )
    )

    if ( !figs.exists( _.toString == norm.toString ) ) {     // uniq
      figs += norm
    }
  }

  if ( debugFlg ) {
    println( s"$id: (${figs.size})" )
    figs.foreach( println )
  }

} // class Piece

////////////////////////////////////////////////////////////

class Board( val width: Int, val height: Int ) {
  val SPACE = ' '

  val cells: Array[Array[Char]] = Array.fill( height, width )( SPACE )

  if ( width * height == 64 ) {
    place(
      Point( width / 2 - 1, height / 2 - 1 ),
      List( Point(0, 0), Point(0, 1), Point(1, 0), Point(1, 1) ),
      '@'
    )
  }

  def at( x: Int, y: Int ): Char =
    if ( x >= 0 && x < width && y >= 0 && y < height ) cells(y)(x)
    else '?'


  def check( o: Point, fig: Fig ): Boolean =
    fig.forall( p => at(o.x + p.x, o.y + p.y) == SPACE)


  def place( o: Point, fig: Fig, id: Char ): Unit =
    fig.foreach( p => cells( o.y + p.y )( o.x + p.x ) = id )


  def find_space( start: Point ): Point = {
    var ( x, y ) = ( start.x, start.y )
    while ( cells(y)(x) != SPACE) {
      x = (x + 1) % width
      if (x == 0) y += 1
    }
    Point(x, y)
  }

  //         2
  // (-1,-1) | (0,-1)
  //  ----4--+--1----
  // (-1, 0) | (0, 0)
  //         8
  val ELEMS = transpose(
    List(
      //0      3     5    6    7     9    10   11   12   13   14   15
      "    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---",
      "    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   "
    ).map( _.split( "," ).toList )
  )

  def render(): String =
    ( 0 to height ).flatMap { y =>
      transpose(
        ( 0 to width ).map { x =>
          ELEMS(
              ( if ( at( x-0, y-0 ) != at( x-0, y-1 ) ) 1 else 0 ) +
              ( if ( at( x-0, y-1 ) != at( x-1, y-1 ) ) 2 else 0 ) +
              ( if ( at( x-1, y-1 ) != at( x-1, y-0 ) ) 4 else 0 ) +
              ( if ( at( x-1, y-0 ) != at( x-0, y-0 ) ) 8 else 0 )
          )
        }.toList
      ).map( _.mkString("") )
    }.mkString( "\n" )

} // class Board

////////////////////////////////////////////////////////////

class Solver( val width: Int, val height: Int ) {
  var unused: Piece | Null = null
  val board                = Board( width, height )
  var solutions            = 0

  var pc: Piece | Null = null
  for ( id <- "FLINPTUVWXYZ".reverse ) {
    pc = new Piece( id, PIECE_DEF(id), pc )
  }
  unused = new Piece( '!', Nil, pc )    // dummy piece

  // limit the symmetry of 'F'
  pc.nn.figs = pc.nn.figs.take( if ( width == height ) 1 else 2 )


  def solve( xy_ : Point ): Unit = {

    if ( unused.nn.next != null ) {
      val xy   = board.find_space( xy_ )
      var prev = unused.nn
      while ( prev.next != null ) {
        val p = prev.next.nn
        prev.next = p.next
        for ( fig <- p.figs ) {
          if ( board.check( xy, fig ) ) {
            board.place( xy, fig, p.id )
            solve( xy )                            // call recursively
            board.place( xy, fig, board.SPACE )
          }
        }
        prev.next = p
        prev      = p
      }
    } else {
      solutions += 1
      var curs_up = if (solutions > 1) "\u001b[%dA".format(board.height * 2 + 2) else ""
      println( "%s%s%d".format( curs_up, board.render(), solutions ) )
    }
  }
}

////////////////////////////////////////////////////////////

@main def main( args: String* ): Unit = {
  var ( width, height ) = ( 6, 10 )

  args.foreach {
    case "--debug" => debugFlg = true
    case s =>
      val r = raw"(\d+)\D(\d+)".r
      s match {
        case r( w, h ) =>
          val ( ww, hh ) = ( w.toInt, h.toInt )
          if ( ww >= 3 && hh >= 3 && ( ww * hh == 60 || ww * hh == 64 ) ) {
            width  = ww
            height = hh
          }
        case _ =>
      }
  }

  val solver = Solver( width, height )
  solver.solve( Point( 0, 0 ) )
}
