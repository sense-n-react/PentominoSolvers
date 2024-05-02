// -*- coding:utf-8 -*-

//
// Pentomino Puzzle Solver with JAVA
//

import java.io.*;
import java.util.List;
import java.util.Arrays;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Map;
import java.util.HashMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

///////////////////////////////////////////////////

public class Solver
{
    static String PIECE_DEF_DOC =
        "+-------+-------+-------+-------+-------+-------+\n" +
        "|       |   I   |  L    |  N    |       |       |\n" +
        "|   F F |   I   |  L    |  N    |  P P  | T T T |\n" +
        "| F F   |   I   |  L    |  N N  |  P P  |   T   |\n" +
        "|   F   |   I   |  L L  |    N  |  P    |   T   |\n" +
        "|       |   I   |       |       |       |       |\n" +
        "+-------+-------+-------+-------+-------+-------+\n" +
        "|       | V     | W     |   X   |    Y  | Z Z   |\n" +
        "| U   U | V     | W W   | X X X |  Y Y  |   Z   |\n" +
        "| U U U | V V V |   W W |   X   |    Y  |   Z Z |\n" +
        "|       |       |       |       |    Y  |       |\n" +
        "+-------+-------+-------+-------+-------+-------+\n"
    ;

    static Map<Character, ArrayList<Point>> piece_def = new HashMap<>();

    static boolean debug_flg = false;


    public static void main( String args[] ) throws IOException
    {
        var width  = 6;
        var height = 10;
        for ( var arg : args ) {
            if ( arg.equals( "--debug" ) )  debug_flg = true;

            Matcher m = Pattern.compile("^(\\d+)\\D(\\d+)$").matcher( arg );
            if ( m.find() ) {
                var w = Integer.parseInt( m.group(1) );
                var h = Integer.parseInt( m.group(2) );
                if ( w >= 3 && h >= 3 && ( w * h == 60 || w * h == 64 ) ) {
                    width  = w;
                    height = h;
                }
            }
        }

        var xy = new Point( 0, 0 );
        for ( var ch : PIECE_DEF_DOC.toCharArray() ) {
            if ( !piece_def.containsKey( ch ) ) {
                piece_def.put( ch, new ArrayList<Point>() );
            }
            piece_def.get( ch ).add( new Point( xy.x / 2, xy.y ) );
            if ( ch == '\n' ) { xy.x = 0;  xy.y ++; }
            else              { xy.x ++; }
        }
        //System.out.println( piece_def );

        Solver solver = new Solver ( width, height );
        solver.solve( new Point( 0, 0 ) );
    }


    Board board;
    Piece Unused;
    int   solutions;

    Solver( int width, int height )
    {
        board     = new Board( width, height );
        Unused    = null;
        solutions = 0;

        Piece pc = null;
        for ( var id: "ZYXWVUTPNILF".toCharArray() ) {
            pc = new Piece( id, Solver.piece_def.get(id), pc );
        }
        Unused = new Piece( '!', new ArrayList<Point>(), pc );    // dumy piece
        // limit the symmetry of 'F'
        var slice = ( width == height )? 1 : 2;
        pc.figs = new ArrayList<Fig>( pc.figs.subList( 0, slice ) );
    }

    void solve( Point xy_ )
    {
        if ( Unused.next != null ) {
            var xy   = board.find_space( xy_ );
            var prev = Unused;
            Piece pc;
            while( ( pc = prev.next ) != null ) {
                prev.next = pc.next;
                for ( var fig : pc.figs ) {
                    if ( board.check( xy, fig ) ) {
                        board.place( xy, fig, pc.id );
                        solve( xy );
                        board.place( xy, fig, board.SPACE );
                    }
                }
                prev = ( prev.next = pc );
            }
        }
        else {
            ++solutions;
            var curs_up = ( solutions > 1 ) ?
                ("\033[" + (board.height * 2 + 2) + "A") : "";
            System.out.println( curs_up + board.render() + solutions );
        }
    }
}

/////////////////////////////////////////////////////

class Point
{
    int x, y;

    Point()                 { x = 0;   y = 0;   }
    Point( int x_, int y_ ) { x = x_;  y = y_;  }
    Point( Point a )        { x = a.x; y = a.y; }

    Point set( int x_, int y_ ) { x = x_;  y = y_;  return this; }

    @Override
    public String toString()  { return "[" + x + "," + y + "]";  }
}

class Fig extends ArrayList<Point>{}

///////////////////////////////////////////////////

class Piece
{
    ArrayList<Fig>  figs = new ArrayList<Fig>();
    char    id;
    Piece   next = null;

    Piece( char id_, ArrayList<Point> fig_def_, Piece next_ )
    {
        this.id   = id_;
        this.next = next_;

        var org_fig = new Fig();
        for ( var xy : fig_def_ ) {
            org_fig.add( xy );
        }

        for ( var r_f = 0; r_f < 8; ++r_f ) {               // rotate & flip
            var fig = new Fig();

            for ( var pt_ : org_fig ) {
                var pt = new Point( pt_ );
                                                                   // rotate
                for ( var n = 0; n < r_f % 4; ++n ) pt.set( -pt.y, pt.x );
                if ( r_f >= 4 )                     pt.x = -pt.x;  // flip

                fig.add( pt );
            }

            Collections.sort( fig, (p1,p2) ->                      // sort
                              p1.y == p2.y ? (p1.x - p2.x) : (p1.y - p2.y)
                              );

            if ( fig.size() > 0 ) {
                var o = new Point( fig.get(0) );
                for ( var pt : fig ) {                             // normalize
                    pt.x -= o.x;
                    pt.y -= o.y;
                }
            }
            if ( ! figs.toString().contains( fig.toString() ) ) {  // uniq
                this.figs.add( fig );
            }
        }

        if ( Solver.debug_flg ) {
            System.out.println( id + ": (" + this.figs.size() + ")" );
            for ( var fig : this.figs ) {
                System.out.println( "    " + fig.toString() );
            }
        }
    }
}


///////////////////////////////////////////////////

class Board
{
    static final char SPACE = ' ';

    int   width, height;
    char  cells[][];

    Board( int w, int h )
    {
        width  = w;
        height = h;

        cells = new char[ height ][];
        for ( var y = 0; y < height; ++y ) {
            cells[ y ] = new char[ width ];
            for ( int x = 0; x < width; ++x ) {
                cells[ y ][ x ] = SPACE;
            }
        }
        if ( width * height == 64 ) {      // 8x8 or 4*16
            int cx = width/2, cy = height/2;
            cells[ cy - 1][ cx - 1] = '@';  cells[ cy - 1][ cx - 0] = '@';
            cells[ cy - 0][ cx - 1] = '@';  cells[ cy - 0][ cx - 0] = '@';
        }
    }


    char at( int x, int y )
    {
        return (x >= 0 && x < width && y >= 0 && y < height)? cells[y][x] : '?';
    }


    boolean check( Point o, Fig fig )
    {
        for ( var pt : fig ) {
            if ( at( o.x + pt.x, o.y + pt.y ) != SPACE ) return false;
        }
        return true;
    }


    void place( Point o, Fig fig, char id )
    {
        for ( var pt : fig ) {
            cells[ o.y + pt.y ][ o.x + pt.x ] = id;
        }
    }


    Point find_space( Point xy  )
    {
        var x = xy.x;
        var y = xy.y;

        while ( cells[ y ][ x ] != SPACE ) {
            if ( ++x == width ) { x = 0;  ++y; }
        }

        return new Point( x, y );
    }

    //         2
    // (-1,-1) | (0,-1)
    //   ---4--+--1----
    // (-1, 0) | (0, 0)
    //         8
    static final String ELEMS_DEF[] = {
        //0      3     5    6    7     9    10   11   12   13   14   15
        "    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---",
        "    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   "
    };
    static final String[][] ELEMS = { ELEMS_DEF[0].split( "," ),
                                      ELEMS_DEF[1].split( "," ) };

    String render()
    {
        var lines = new ArrayList<String>();
        for ( var y = 0; y <= height; y++ ) {
            for ( var d = 0; d < 2; d++ ) {
                var line = "";
                for ( var x = 0; x <= width; x++ ) {
                    int code =
                        ( ( at( x+0, y+0 ) != at( x+0, y-1 ) )? 1: 0 ) |
                        ( ( at( x+0, y-1 ) != at( x-1, y-1 ) )? 2: 0 ) |
                        ( ( at( x-1, y-1 ) != at( x-1, y+0 ) )? 4: 0 ) |
                        ( ( at( x-1, y+0 ) != at( x+0, y+0 ) )? 8: 0 );
                    line += ELEMS[ d ][ code ];
                }
                lines.add( line );
            }
        }
        return String.join( "\n", lines );
    }
}
