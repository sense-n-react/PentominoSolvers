<?php
# -*- coding:utf-8 -*-

#
# Pentomino Puzzle Solver with PHP
#

$PIECE_DEF_DOC = <<<EOD
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
EOD;

function piece_def( $id ) {
    global $PIECE_DEF_DOC;
    $def = [];
    $y = 0; $x = 0;
    foreach ( str_split( $PIECE_DEF_DOC ) as $ch ) {
        if ( $id == $ch  ) { $def[] = [ floor( $x / 2 ), $y ]; }
        if ( $ch == "\n" ) { $y++;  $x = 0; }
        else               { $x++;          }
    }
    return $def;
}

function fig2str( $fig ) {
    return sprintf( "[ %s ]",
                    implode( ", ", array_map( function( $pt ) {
                        return sprintf( "(%d, %d)", $pt[0], $pt[1] );
                    }, $fig ) )
    );
}

/////////////////////////////////////////////////////////

$debug_flg = false;

class Piece {
    public $id;
    public $next;
    public $figs = [];

    public function __construct( $id, $fig_def, $next_pc ) {

        $this->id   = $id;
        $this->next = $next_pc;
        $figs_str   = "";
        for ( $r_f = 0; $r_f < 8; $r_f++ ) {     // rotate & flip
            $fig = [];
            foreach ( $fig_def as list( $x, $y ) ) {
                for ( $i = 0; $i < $r_f % 4; $i++ ) {
                    list( $x, $y ) = [ -$y, $x ];           // rotate
                }
                if ($r_f >= 4) {
                    list( $x, $y ) = [ -$x, $y ];           // flip
                }
                $fig[] = [ $x, $y ];  // push
            }
            usort( $fig, function($a, $b) {                 // sort
                return ( $a[0] + $a[1] * 100 ) <=> ( $b[0] + $b[1] * 100 );
            });

            $fig = array_map( function($pt) use($fig) {     // normalize
                return [ $pt[0] - $fig[0][0], $pt[1] - $fig[0][1] ];
            }, $fig );

            if ( strpos( $figs_str, fig2str( $fig ) ) === false ) {
                $this->figs[] = $fig;
                $figs_str     = $figs_str . fig2str( $fig );
            }
        }

        global $debug_flg;
        if ( $debug_flg ) {
            printf( "%s:(%d)\n%s\n",
                    $this->id, count( $this->figs ),
                    implode( "\n", array_map( function( $fig ) {
                        return fig2str( $fig );
                    }, $this->figs ) )
            );
        }
    }
}

/////////////////////////////////////////////////////////

class Board {
    const SPACE = ' ';
    public  $width;
    public  $height;
    private $cells;

    private const elems_str = [
        //0      3     5    6    7     9    10   11   12   13   14   15
        "    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---",
        "    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   "
    ];
    private static $ELEM;

    public static function initialize() {
        self::$ELEM = array_map( function( $s ) {
            return explode(  ",", $s );
        }, self::elems_str );
    }


    public function __construct( $w, $h ) {
        $this->width  = $w;
        $this->height = $h;
        $this->cells  = array_fill( 0, $h, array_fill( 0, $w, self::SPACE ) );
        if ( $w * $h == 64 ) {     // 8x8 or 4x16
            $this->place( $w/2-1, $h/2-1, [[0,0],[1,0],[0,1],[1,1]], '@' );
        }
    }


    public function at( $x, $y ) {
        return ($x >= 0 && $x < $this->width && $y >= 0 && $y < $this->height)?
                     $this->cells[ $y ][ $x ] : "?";
    }


    public function check(  $x, $y, $fig ) {
        foreach ( $fig as $p ) {
            if ( $this->at( $x + $p[0], $y + $p[1] ) != self::SPACE) {
                return false;
            }
        }
        return true;
    }


    public function place(  $x, $y, $fig, $id ) {
        foreach ( $fig as $p ) {
            $this->cells[ $y + $p[1] ][ $x + $p[0] ] = $id;
        }
    }


    public function find_space( $x, $y ) {
        while ( $this->cells[ $y ][ $x ] != self::SPACE ) {
            if ( ++$x == $this->width ) { $x = 0;  ++$y; }
        }
        return [ $x, $y ];
    }

    //         2
    // (-1,-1) | (0,-1)
    //   ---4--+--1----
    // (-1, 0) | (0, 0)
    //         8
    public function render() {
        $cmp = function( $x, $y, $u, $v, $n ) {
            return $this->at($x, $y) != $this->at($u, $v) ? $n : 0;
        };
        $lines = [];
        for ( $y = 0; $y <= $this->height; $y++ ) {
            for ( $d = 0; $d < 2; $d++ ) {
                $line = [];
                for ( $x = 0; $x <= $this->width; $x++ ) {
                    $line[] = self::$ELEM[ $d ][
                            $cmp( $x,   $y,   $x,   $y-1, 1 ) +
                            $cmp( $x,   $y-1, $x-1, $y-1, 2 ) +
                            $cmp( $x-1, $y-1, $x-1, $y,   4 ) +
                            $cmp( $x-1, $y,   $x,   $y,   8 ) ];
                }
                $lines[] = implode( '', $line );
            }
        }
        return implode( "\n", $lines );
    }
}

/////////////////////////////////////////////////////////

class Solver {
    private $solutions;
    private $board;
    private $Unused;

    public function __construct( $width, $height ) {

        Board::initialize();
        $this->board     = new Board( $width, $height );
        $this->solutions = 0;

        $pc = null;
        foreach ( array_reverse( str_split( 'FLINPTUVWXYZ' ) ) as $id) {
            $pc = new Piece( $id, piece_def( $id ), $pc );
        }
        $this->Unused = new Piece( "!", [], $pc );  // dummy piece
        // limit the symmetry of 'F'
        $pc->next->figs = array_slice( $pc->next->figs, 0,
                                       ($width == $height) ? 1 : 2 );
    }


    function solve( $x, $y ) {
        if ($this->Unused->next !== null) {
            $xy   = $this->board->find_space( $x, $y );
            $x    = $xy[0];   $y = $xy[1];
            $prev = $this->Unused;
            $pc    = null;
            while ( ( $pc = $prev->next ) !== null ) {
                $prev->next = $pc->next;
                foreach ( $pc->figs as $fig ) {
                    if ($this->board->check( $x, $y, $fig) ) {
                        $this->board->place( $x, $y, $fig, $pc->id );
                        $this->solve( $x, $y );
                        $this->board->place( $x, $y, $fig, Board::SPACE );
                    }
                }
                $prev = ( $prev->next = $pc );
            }
        } else {
            $this->solutions++;
            $lines   = $this->board->height * 2 + 2;
            $curs_up = ($this->solutions > 1)? "\033[{$lines}A" : "";
            printf( "%s%s%d\n", $curs_up, $this->board->render(), $this->solutions );
        }
    }
}

/////////////////////////////////////////////////////////

$width  = 6;
$height = 10;
foreach ( $argv as $arg ) {
    if ( $arg == "--debug" ) {
        $debug_flg = true;
    }
    preg_match('/^(\d+)\D(\d+)$/', $arg, $m);
    $sz = array_map('intval', array_slice( $m, 1));
    if ( count( $sz ) == 2 && $sz[0] >= 3 && $sz[1] >= 3 &&
            ( $sz[0] * $sz[1] == 60 || $sz[0] * $sz[1] == 64 ) ) {
       $width  = $sz[0];
       $height = $sz[1];
    }
}

$solver = new Solver( $width, $height );
$solver->solve( 0, 0 );

?>
