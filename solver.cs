// -*- coding:utf-8 -*-

//
// Pentomino Puzzle Solver with C#
//

using System;
using System.Linq;
using System.Collections;
using System.Collections.Generic;
using System.Text.RegularExpressions;

using Fig = System.Collections.Generic.List<int[]>;

////////////////////////////////////////////////////////

public class Piece
{
    public List<Fig> figs = new List<Fig>();
    public Piece     next;
    public char      id;

    string to_s( Fig fig )
    {
        var xys = fig.Select( xy => string.Format( "({0},{1})", xy[0], xy[1] ));
        return "[" + string.Join( ",",  xys ) + "]";
    }

    string to_s( List<Fig> figs )
    {
        return string.Join( "\n", figs.Select( fig => "    " + to_s( fig ) ) );
    }

    public Piece( char id_ , List<int[]> def, Piece next_ )
    {
        id   = id_;
        next = next_;

        for ( int r_f = 0; r_f < 8; ++r_f ) {     // rotate and flip
            var fig = new Fig();
            foreach( int[] xy in def ) {
                var pt = new int[]{ xy[0], xy[1] };
                for ( int rot = 0; rot < r_f % 4; ++rot ) {      // rotate
                    pt = new int[]{ -pt[1], pt[0] };
                }
                if ( r_f >=4 ) { pt[0] = -pt[0]; }               // flip
                fig.Add( pt );
            }

            fig.Sort( (p,q) =>                                   //sort
                      ( p[1] == q[1] ? (p[0] - q[0]) : (p[1] - q[1]) )
            );

            for ( int j = fig.Count - 1; j >= 0; --j ) {         // normalize
                fig[j] = new int[]{ fig[j][0] - fig[0][0], fig[j][1] - fig[0][1] };
            }

            if ( ! to_s( figs ).Contains( to_s(fig ) ) ) {       //uniq
                this.figs.Add( fig );
            }
        }

        if ( Solver.debug_flg ) {
            Console.WriteLine( "{0}: ({1})", id_, figs.Count );
            Console.WriteLine( "{0}", to_s( figs ) );
        }
    }

}

////////////////////////////////////////////////////////

public class Board
{
    public const char SPACE = ' ';
    public  int  width, height;
    char [,]     cells;

    public Board( int w, int h )
    {
        width  = w;
        height = h;
        cells  = new char [ width, height ];
        for ( int y = 0; y < height; y++ )  {
            for ( int x = 0; x < width; x++ ) {
                cells[ x, y ]  = SPACE;
            }
        }
        if ( width * height == 64 ) {
            Fig hole = new Fig{ new int[] {0,0}, new int[] {0,1},
                                new int[] {1,0}, new int[] {1,1} };
            place( width/2 - 1, height/2 - 1, hole, '@' );
        }
        ELEMS = new string[][]{ elems[0].Split( ',' ), elems[1].Split( ',' ) };
    }

    char at( int x, int y )
    {
        return ( x >= 0 && x < width && y >= 0 && y < height )?
            cells[ x, y ] : '?';
    }


    public bool check( int x, int y, Fig fig )
    {
        return fig.All( pt => at( x + pt[0], y + pt[1] ) == SPACE );
    }


    public void place( int x, int y, Fig fig, char id )
    {
        foreach( var pt in fig ) { cells[ x + pt[0], y + pt[1] ] = id; }
    }


    public int[] find_space( int x, int y )
    {
        while ( cells[ x, y ] != SPACE ) {
            if ( ++x == width ) { x = 0;  ++y; }
        }
        return new int[]{ x, y };
    }

    //         2
    // (-1,-1) | (0,-1)
    //   ---4--+--1----
    // (-1, 0) | (0, 0)
    //         8
    static string[] elems =
    {
        //0      3     5    6    7     9    10   11   12   13   14   15
        "    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---",
        "    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   ",
    };
    static string[][] ELEMS;

    public string render()
    {
        var  lines = new List<string>();

        for ( int y = 0; y <= height; y++ ) {
            for ( int d = 0; d < 2; d++ ) {
                string line = "";
                for ( int x = 0; x <= width; x++ ) {
                    int code =
                        ( ( at( x+0, y+0 ) != at( x+0, y-1 ) )? 1 : 0 ) |
                        ( ( at( x+0, y-1 ) != at( x-1, y-1 ) )? 2 : 0 ) |
                        ( ( at( x-1, y-1 ) != at( x-1, y+0 ) )? 4 : 0 ) |
                        ( ( at( x-1, y+0 ) != at( x+0, y+0 ) )? 8 : 0 );
                    line += ELEMS[d][code];
                }
                lines.Add( line );
            }
        }
        return string.Join( "\n", lines );
    }

}

////////////////////////////////////////////////////////

public class Solver
{
    static string PIECE_DEF_DOC = @"
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
    ";
    static List<int[]> piece_def( char id )
    {
        var def = new List<int[]>();
        int y = 0;
        foreach( var line in PIECE_DEF_DOC.Split( '\n' ) ) {
            for( var x = 0; x < line.Length; x++ ) {
                if ( line[ x ] == id ) { def.Add( new int[]{ x/2, y } ); }
            }
            y++;
        }
        return def;
    }

    public static bool debug_flg = false;

    Piece Unused;
    Board board;
    int solutions = 0;

    Solver( int width, int height )
    {
        Piece pc = null;
        foreach( char id in "FLINPTUVWXYZ".Reverse() ) {
            pc = new Piece( id, piece_def( id ), pc );
        }
        Unused = new Piece( 'F', new List<int[]>(), pc );    // dummy piece
        // limit the symmetry of 'F'
        pc.figs = pc.figs.GetRange( 0, (width == height) ? 1 : 2 );

        board = new Board( width, height);
    }

    void solve( int x, int y )
    {
        if ( Unused.next != null ) {
            var xy  = board.find_space( x, y );
            x = xy[0];  y = xy[1];
            Piece prev = Unused;
            Piece pc;
            while ( (pc = prev.next) != null )
            {
                prev.next = pc.next;
                foreach( Fig fig in pc.figs ) {
                    if ( board.check( x, y, fig ) ) {
                        board.place( x, y, fig, pc.id );
                        solve( x, y );
                        board.place( x, y, fig, Board.SPACE );
                    }
                }
                prev.next = ( prev = pc );
            }
        }
        else {
            solutions ++;
            string curs_up = ( solutions > 1 ) ?
                string.Format( "\x1b[{0}A", board.height * 2 + 2 ) : "";

            Console.WriteLine( curs_up + board.render() + solutions );
        }
    }


    public static void Main( string[] args )
    {
        var width  = 6;
        var height = 10;
        foreach ( string av in args )
        {
            if ( av == "--debug" )  debug_flg = true;

            var m = Regex.Match( av, @"(\d+)\D(\d+)" );
            if (m.Success)
            {
                var w = int.Parse( m.Groups[1].Value );
                var h = int.Parse( m.Groups[2].Value );
                if ( w >= 3 && h >= 3 && ( w * h == 60 | w * h == 64 ) ) {
                    width  = w;
                    height = h;
                }
            }
        }
        var solver = new Solver( width, height );
        solver.solve( 0, 0 );
    }
}
