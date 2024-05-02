# -*- coding:utf-8 -*-

#
# Pentomino Puzzle Solver with AWK
#


function piece_def( x, y, i, id, def, arr ) {
    PIECE_DEF_DOC =\
        "+-------+-------+-------+-------+-------+-------+."\
        "|       |   I   |  L    |  N    |       |       |."\
        "|   F F |   I   |  L    |  N    |  P P  | T T T |."\
        "| F F   |   I   |  L    |  N N  |  P P  |   T   |."\
        "|   F   |   I   |  L L  |    N  |  P    |   T   |."\
        "|       |   I   |       |       |       |       |."\
        "+-------+-------+-------+-------+-------+-------+."\
        "|       | V     | W     |   X   |    Y  | Z Z   |."\
        "| U   U | V     | W W   | X X X |  Y Y  |   Z   |."\
        "| U U U | V V V |   W W |   X   |    Y  |   Z Z |."\
        "|       |       |       |       |    Y  |       |."\
        "+-------+-------+-------+-------+-------+-------+."

    x = 0; y = 0;
    for ( i = 1; i <= length( PIECE_DEF_DOC ); i++ ) {
        id = substr( PIECE_DEF_DOC, i, 1 )
        if ( id  ~ /[A-Z]/ ) {
            def[ id ] = sprintf( "%s; %d,%d", def[ id ], int(x/2), y )
        }
        if ( id == "." ) { y ++;  x = 0 }
        else             { x ++         }
    }
    for ( id in def ) {
        sub( /^[ ]*;/, "", def[ id ] )
        split( def[id], arr, /;/ )
        for ( i = 1; i <= 5; i++ ) {
            PIECE_DEF[ id, i ] = arr[ i ]    # "12, 5"
        }
    }

}

#####################################################################

function qsort( arr, left, right,    i, j, pivot, temp ) {
    if (left < right) {
        pivot = arr[int((left + right) / 2)];
        i = left;
        j = right;
        while (i <= j) {
            while (arr[i] < pivot) i++;
            while (arr[j] > pivot) j--;
            if (i <= j) {
                temp = arr[i];
                arr[i] = arr[j];
                arr[j] = temp;
                i++;
                j--;
            }
        }
        qsort(arr, left, j);
        qsort(arr, i, right);
    }
}

function xy2n( xy )    { return ( xy[1] + 100 ) + ( xy[2] + 100 ) * 1000 }
function n2xy( n, xy ) { set_xy( (n % 1000)-100, int(n/1000)-100, xy )   }

function set_xy( x, y, xy ) { xy[1] = x;  xy[2] = y }
function n_sub_n( a, b,  xy, uv, w ) {  # a - b
    n2xy( a, xy )
    n2xy( b, uv )
    set_xy( xy[1] - uv[1], xy[2] - uv[2], w )
    return xy2n( w )
}

#####################################################################

function new_Piece( id, def,    xy, tmp, i,n, fig, r_f, pts, figs_STR ) {
    Piece[ id, "fig_num" ] = 0
    figs_STR = ""
    for ( r_f = 0; r_f < 8; r_f++ ) {    # rotate & flip
        for ( n = 1; n <= 5; n ++ ){
            split( PIECE_DEF[ id, n ], xy, /,/ )      # def[n] = "12,34"
            for ( i  = 0; i < r_f % 4; i++ ) {        # rotate
                set_xy( -xy[2], xy[1], xy )           # x,y = -y, x
            }
            if ( r_f >= 4 ) { xy[1] = -xy[1] }        # flip
            pts[ n ] = xy2n( xy )
        }
        qsort( pts, 1, 5 )                            # sort

        for ( n = 5; n >= 1; n-- ) {                  # normalize
            pts[n] = n_sub_n( pts[n], pts[1] )
        }

        tmp = sprintf( "[%d,%d,%d,%d] ", pts[2], pts[3], pts[4], pts[5] )

        if ( index( figs_STR, tmp ) == 0 ) {          # uniq
            figs_STR =  sprintf( "%s%s",  figs_STR, tmp )
            # "figs_STR = figs_STR tmp " causes trouble on gawk 4.1
            fig = ++Piece[ id, "fig_num" ];
            for ( n = 1; n <= 5; n++ ) {
                n2xy( pts[ n ], xy )
                Piece[ id, fig, n, "x" ] = xy[1]
                Piece[ id, fig, n, "y" ] = xy[2]
            }
        }
    } # r_f

    if ( debug_flg ) {
        printf( "%s: (%d)\n", id, Piece[ id, "fig_num" ] )
        printf( "\t%s\n", figs_STR )
        for ( fig = 1; fig <= Piece[ id, "fig_num"]; fig++ ) {
            printf( "\t[" )
            for ( n = 1; n <= 5; n++ ) {
                printf( "[%d, %d]%s",
                        Piece[ id, fig, n, "x"],
                        Piece[ id, fig, n, "y"],
                        ( n == 5 ) ? "" : ", " )
            }
            printf( "]\n" )
        }
    }
}

#####################################################################

function new_Board( width, height,   x, y, i, arr ) {
    SPACE = " "
    Board[ "Width"     ] = width
    Board[ "Height"    ] = height
    Board[ "solutions" ] = 0
    for ( y = 1; y <= Board[ "Height" ]; y++ ) {
        for ( x = 1; x <= Board[ "Width" ]; x++ ) {
            Board[ x, y ] = SPACE
        }
    }
    if ( width * height == 64 ) {    # 8x8 or 4x16
        Board[ int(width/2),     int(height/2)     ] = "@"
        Board[ int(width/2),     int(height/2) + 1 ] = "@"
        Board[ int(width/2) + 1, int(height/2)     ] = "@"
        Board[ int(width/2) + 1, int(height/2) + 1 ] = "@"
    }

    #         2
    # (-1,-1) | (0,-1)
    #   ---4--+--1----
    # (-1, 0) | (0, 0)
    #         8
    #        0      3     5    6    7     9    10   11   12   13   14   15
    split( "    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---,"\
           "    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   ",
           arr, /,/ )
    for ( i in arr ) {
        if ( i+0  <= 16 ) { ELEMS[ 1, i      ] = arr[ i ] }
        else              { ELEMS[ 2, i - 16 ] = arr[ i ] }
    }
}


function at( bd, x, y ) {
    if ( x >= 1 && x <= bd[ "Width" ] && y >= 1 && y <= bd[ "Height" ] ) {
        return bd[ x, y ]
    }
    return "?"
}


function check( bd, ox, oy, id, fig,   n ) {
    for ( n = 1; n <= 5; n++ ) {
        if ( at( bd,
                 Piece[ id, fig, n, "x"] + ox,
                 Piece[ id, fig, n, "y"] + oy ) != SPACE ) {
            return 0
        }
    }
    return 1
}


function place( bd, ox, oy, id, fig, ch,   n ) {
    for ( n = 1; n <= 5; n++ ) {
        bd[ Piece[ id, fig, n, "x" ] + ox,
            Piece[ id, fig, n, "y" ] + oy ] = ch
    }
}


function find_space( bd, xy ) {
    while ( bd[ xy[1], xy[2] ] != SPACE ) {
        ( xy[1] = ( xy[1] % bd[ "Width" ] ) + 1 ) == 1 && xy[2]++
    }
}


function render( bd,   code, line, lines, x, y, d ) {
    lines = ""
    for ( y = 1; y <= bd[ "Height" ] + 1; y++ ) {
        for ( d = 1; d <= 2; d++ ) {
            line = ""
            for ( x = 1; x <= bd[ "Width" ] + 1; x++ ) {
                code = 1 + \
                    ( at( bd, x+0, y+0 ) != at( bd, x+0, y-1 )? 1 : 0 ) + \
                    ( at( bd, x+0, y-1 ) != at( bd, x-1, y-1 )? 2 : 0 ) + \
                    ( at( bd, x-1, y-1 ) != at( bd, x-1, y+0 )? 4 : 0 ) + \
                    ( at( bd, x-1, y+0 ) != at( bd, x+0, y+0 )? 8 : 0 )
                line = line  ELEMS[ d, code ]
            }
            lines = lines line "\n"
        }
    }
    return lines
}

####################################################################

function new_Solver( width, height,   i, id, ids ) {
    new_Board( width , height )

    ids = "FILNPTUVWXYZ"
    for ( i = 1; i <= length( ids ); i++ ) {
        id = substr( ids, i, 1 )

        new_Piece( id, PIECE_DEF )

        Piece[ id, "next" ] = substr( ids, i + 1, 1 )
    }
    Unused = "!"
    Piece[ Unused, "next" ] = "F"                # head node
    # limit the symmetry of 'F'
    Piece[ "F", "fig_num" ] = ( width == height )? 1 : 2
}


function solve( bd, x, y,   xy, prev, pc, fig, curs_up ) {
    if ( Piece[ Unused, "next" ] != "" ) {
        xy[1] = x;  xy[2] = y
        find_space( bd, xy )
        x = xy[1];  y = xy[2]     # update x, y
        prev = Unused
        while ( ( pc = Piece[ prev, "next" ] ) != "" ) {
            Piece[ prev, "next" ] = Piece[ pc, "next" ]

            for ( fig = 1; fig <= Piece[ pc, "fig_num" ]; fig++ ) {
                if ( check( bd, x, y, pc, fig ) ) {
                    place( bd, x, y, pc, fig, pc )
                    solve( bd, x, y )
                    place( bd, x, y, pc, fig, SPACE )
                }
            }
            prev = ( Piece[ prev, "next" ] = pc )
        }
    } else {
        bd[ "solutions" ]++
        curs_up = ""
        if ( bd[ "solutions" ] > 1 ) {
            curs_up = sprintf( "\033[%dA", bd[ "Height" ] * 2 + 3 )
        }
        printf( "%s%s%d\n", curs_up, render( bd ), bd[ "solutions" ] )
        # getline input
    }
}

##################################################################

BEGIN {
    width  = 6
    height = 10
    debug_flg = 0
    for ( ac in ARGV ) {
        if ( ARGV[ac] == "--debug" ) { debug_flg = 1  }
        split( ARGV[ac], sz_arr, /[^0-9]/ )
        if ( length( sz_arr ) == 2 ) {
            w_ = sz_arr[1] + 0
            h_ = sz_arr[2] + 0
            if ( w_ >= 3 && h_ >= 3 && ( w_ * h_ == 60 || w_ * h_ == 64 ) ) {
                width  = w_
                height = h_
            }
        }
    }
    piece_def()

    new_Solver( width, height )
    solve( Board, 1, 1 )
}
