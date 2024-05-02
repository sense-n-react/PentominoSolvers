// -*- coding:utf-8 -*-

//
// Pentomino Puzzle Solver with Kotlin
//

import java.util.*

fun <T> transpose(list: List<List<T>>): List<List<T>> =
    list.first().mapIndexed { index, _ -> list.map { row -> row[index] } }

/////////////////////////////////////////////////////////////////


val PIECE_DEF = """
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
""".split( "\n" ).mapIndexed { y, ln ->
    ln.toCharArray().mapIndexed { x, id ->
        mapOf( id to listOf( x/2, y ) )
    }
}.flatten().
fold( emptyMap<Char,List<List<Int>>>() ) { hash, id_xy ->
    val id  = id_xy.keys.toList()[0]                    // 'F'
    var xys = listOf( id_xy[ id ]!! )                   // [[0,1]]
    if ( hash[ id ] != null ) xys = hash[ id ]!! + xys  // [[1,0],[0,1], ]
    hash + mapOf( id to xys )     // hash を mapOf(..) で上書き
}
/*
val PIECE_DEF = mapOf(
  'F' to listOf(listOf(1,0),listOf(0,1),listOf(1,1),listOf(1,2),listOf(2,2)),
  'L' to listOf(listOf(0,0),listOf(0,1),listOf(0,2),listOf(0,3),listOf(1,3)),
 */

/////////////////////////////////////////////////////////////////

class Point( val x:Int = 0, val y:Int = 0 )
{
    override public fun toString(): String = "($x,$y)"
}

typealias Fig = List<Point>

var debug_flg: Boolean = false

/////////////////////////////////////////////////////////////////

class Piece( val id: Char, fig_def:List<List<Int>>, var next: Piece? ) {
    val  figs = mutableListOf<Fig>()

    init {
        for ( r_f in 0 until 8 ) {                // rotate & flip
            val fig = fig_def.map {
                var pt = Point( it[0], it[1] )
                repeat( r_f % 4 ) { pt = Point( -pt.y, pt.x ) }  // rotate
                if    ( r_f >=4 ) { pt = Point( -pt.x, pt.y ) }  // flip
                pt
            }.sortedBy {                                         // sort
                it.x + it.y * 100
            }

            val norm = fig.map {                                 // normalize
                Point( it.x - fig[0].x, it.y - fig[0].y )
            }

            if ( figs.filter{ it.toString() == norm.toString() }.size == 0 ) {
                figs.add( norm )                                 // uniq
            }
        }
        if ( debug_flg ) {
            println( "%c: (%d)".format( id, figs.size ) )
            for ( fig in figs ) {
                println( fig.toString() )
            }
        }
    }
}


/////////////////////////////////////////////////////////////////

class Board( val width: Int, val height: Int ) {
    companion object {
        const val SPACE = ' '
    }
    val cells: ArrayList<ArrayList<Char>>
    init {
        cells = ArrayList<ArrayList<Char>>(
            MutableList( height ) {
                ArrayList( MutableList( width ) { SPACE } )
        })
        if ( width * height == 64 ) {   // 8x8 or 16x4
            val cx = width  / 2
            val cy = height / 2
            cells[cy-1][cx-1] = '@';  cells[cy-1][cx-0] = '@'
            cells[cy-0][cx-1] = '@';  cells[cy-0][cx-0] = '@'
        }
    }

    fun at( x: Int, y: Int ) : Char =
        if   ( x >= 0 && x < width  && y >= 0 && y < height ) cells[ y ][ x ]
        else '?'


    fun check( o: Point, fig: Fig ) :Boolean  =
        fig.all { at( o.x + it.x, o.y + it.y ) == SPACE }


    fun place( o: Point, fig: Fig, id: Char ) =
        fig.forEach{ pt -> cells[ o.y + pt.y ][ o.x + pt.x ] = id }


    fun find_space( xy: Point ): Point {
        var x = xy.x
        var y = xy.y
        while ( cells[ y ][ x ] != SPACE ) {
            x = ( x + 1 ) % width
            if ( x == 0 )  { y += 1 }
        }
        return Point( x, y )
    }


    //         2
    // (-1,-1) | (0,-1)
    //     4 --+-- 1
    // (-1, 0) | (0, 0)
    //         8
    val ELEMS = transpose(
        listOf(
            //0      3     5    6    7     9    10   11   12   13   14   15
            "    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---",
            "    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   "
        ).map { it.split( ',' ) }
    )

    fun render() : String =
        ( 0.. height ).toList().map { y ->
            transpose(
                ( 0.. width ).toList().map { x ->
                  ELEMS[ ( if ( at( x+0, y+0 ) != at( x+0, y-1 ) ) 1 else 0 ) +
                         ( if ( at( x+0, y-1 ) != at( x-1, y-1 ) ) 2 else 0 ) +
                         ( if ( at( x-1, y-1 ) != at( x-1, y+0 ) ) 4 else 0 ) +
                         ( if ( at( x-1, y+0 ) != at( x+0, y+0 ) ) 8 else 0 ) ]
            }).map { it.joinToString( "" ) }
        }.flatten().joinToString( "\n" )

}

/////////////////////////////////////////////////////////////////

class Solver( val width: Int, val height: Int ) {
    var Unused: Piece?  = null
    var board: Board  = Board( width, height )
    var solutions     = 0

    init {
        var pc: Piece? = null
        for ( id in "FLINPTUVWXYZ".reversed() ) {
            pc = Piece( id, PIECE_DEF[ id ]!!, pc )
        }
        Unused = Piece( '!', listOf(), pc )      // dummy piece
        // limit the symmetry of 'F'
        pc!!.figs.subList( if ( width == height ) 1 else 2,
                           pc.figs.size).clear()
    }

    fun solve( xy_: Point ) {

        if ( Unused!!.next != null ) {
            var xy   = board.find_space( xy_ )
            var prev = Unused!!
            while ( true ) {
                var pc = prev.next
                if ( pc == null ) { break }
                prev.next = pc.next
                for ( fig in pc.figs ) {
                    if ( board.check( xy, fig ) ) {
                        board.place( xy, fig, pc.id )
                        solve( xy )
                        board.place( xy, fig, Board.SPACE )
                    }
                }
                prev.next = pc
                prev      = pc
            }
        }
        else {
            solutions += 1
            var curs_up = if (solutions > 1) "\u001b[%dA".format(board.height * 2 + 2) else ""
            println( "%s%s%d".format( curs_up, board.render(),solutions ) )
        }
    }
}    

fun main( args:Array<String> ) {
    var width = 6
    var height = 10
    for ( arg in args ) {
        if ( arg == "--debug" )  { debug_flg = true }

        val m = "(\\d+)\\D(\\d+)".toRegex().find( arg )
        if ( m != null ) {
            val sz = m.groupValues.drop(1).map { it.toInt() }
            if ( sz[0] >= 3 && sz[1] >= 3 &&
                     (sz[0] * sz[1] == 60 || sz[0] * sz[1] == 64 ) ) {
                width  = sz[0]
                height = sz[1]
            }
        }
    }

    var solver  = Solver( width, height )
    solver.solve( Point(0, 0) )
}
