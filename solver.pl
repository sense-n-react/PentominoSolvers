# -*- coding:utf-8 -*-

#
# Pentomino Puzzle Solver with Perl
#

$PIECE_DEF=<<EOT;
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
EOT

sub piece_def {
    my ($id ) = @_;

    my ( $x, $y ) = ( 0, 0 );
    my @def = ();
    foreach my $ch ( split( "", $PIECE_DEF ) ) {
        if ( $ch =~ $id  ) { push( @def, [ int($x/2), $y ] );  }
        if ( $ch =~ /\n/ ) { $y++;  $x = 0; }
        else               { $x++;          }
    }
    return \@def;
}

sub fig_to_str {
    my ( $fig ) = @_;
    return "[ " .
        join( " ", map( sprintf( "(%d,%d)", $_->[0], $?->[1] ), @$fig ) ) .
        " ]";
}

##############################################
$debug_flg  = 0;

sub new_Piece {
    my ($id ) = @_;

    my $def = piece_def( $id );

    my $figs_str = "";
    my @figs = ();
    for ( my $r_f = 0; $r_f < 8; $r_f++ ) {     # rotate & flip
        my @fig = ();

        foreach my $pt_ ( @$def ) {
            my @pt = ( $pt_->[0], $pt_->[1] );    # copy
            for ( my $r = 0; $r < $r_f % 4; $r++ ) {            # rotate
                @pt = ( -$pt[1], $pt[0] );
            }
            @pt = ( -$pt[0], $pt[1] )  if ( $r_f >= 4 );        # flip
            push( @fig, \@pt );
        }

        @fig = sort{                                            # sort
            ($a->[1] == $b->[1])? ($a->[0] <=> $b->[0]) : ($a->[1] <=> $b->[1])
        }( @fig );

        my ($ox, $oy) = ($fig[0][0], $fig[0][1] );              # normalize
        @fig = map( [ $_->[0] - $ox, $_->[1] - $oy ], @fig );

        if ( index( $figs_str, fig_to_str( \@fig ) ) == -1 ) {   # uniq
            $figs_str = $figs_str . fig_to_str( \@fig );
            push( @figs, \@fig );
        }
    }

    if ( $debug_flg ) {
        printf( "%s: (%d)\n", $id, scalar(@figs) );
        foreach my $fig ( @figs ) {
            printf( "\t%s\n",  fig_to_str( $fig ) );
        }
    }
    return \@figs;
}

##############################################

sub new_Board {
    my ( $w, $h ) = @_;
    $width  = $w;
    $height = $h;

    use constant SPACE => " ";
    @cells = ();
    for ( my $y = 0; $y < $height; $y++ ) {
        for ( my $x = 0; $x < $width; $x++ ) {
            $cells[$y][$x] = SPACE;
        }
    }
    if ( $width * $height == 64 ) {     # 8x8 or 4x16
        place( $width/2-1, $height/2-1, [ [0,0], [0,1], [1,0], [1,1] ], "@" );
    }

    my @elems = (
        "    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---",
        "    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   "
        );
    @ELEMS = map( [ split( /,/, $_ ) ], @elems );
}


sub at {
    my ( $x, $y ) = @_;
    if ( $x >= 0 && $x < $width && $y >= 0 && $y < $height ) {
        return $cells[$y][$x];
    }
    return "?";
}


sub check {
    my ( $x, $y, $fig ) = @_;
    foreach $pt ( @{$fig} ) {
        return 0  if at( $pt->[0] + $x, $pt->[1] + $y ) ne SPACE;
    }
    return 1;
 }


sub place {
    my ( $x, $y, $fig, $id ) = @_;
    foreach $pt ( @{$fig} ) {
        $cells[ $pt->[1] + $y ][ $pt->[0] + $x ] = $id;
    }
 }


sub find_space {
    my ( $x, $y ) = @_;
    while ( $cells[ $y ][ $x ] ne SPACE ) {
        ( $x = ( $x + 1 ) % $width ) == 0 && $y++;
    }
    return [ $x, $y ];   # reference
}


sub render {
    my @lines = ();
    for ( my $y = 0; $y <= $height; $y++ ) {
        for ( my $d = 0; $d < 2; $d++ ) {
            my $line = "";
            for ( $x = 0; $x <= $width; $x++ ) {
                my $code =
                    ( at( $x+0, $y+0 ) ne at( $x+0, $y-1 )? 1 : 0 ) |
                    ( at( $x+0, $y-1 ) ne at( $x-1, $y-1 )? 2 : 0 ) |
                    ( at( $x-1, $y-1 ) ne at( $x-1, $y+0 )? 4 : 0 ) |
                    ( at( $x-1, $y+0 ) ne at( $x+0, $y+0 )? 8 : 0 );
                $line = $line . $ELEMS[ $d ][ $code ];
            }
            push( @lines, $line );
        }
    }
    return join( "\n", @lines );
}

##############################################

sub new_Solver {
    my ( $width, $height ) = @_;

    %Pieces    = ();
    %Next      = ();
    $Solutions = 0;

    my $pc = "";
    foreach my $id ( reverse( split( "", "FILNPTUVWXYZ" ) ) ) {
        $Pieces{ $id } = new_Piece( $id );
        $Next{ $id }   = $pc;
        $pc = $id;
    }
    # limit the symmetry of 'F'
    $Pieces{ "F" } = [@{$Pieces{ "F" }}[0.. (($width==$height)? 0 : 1 )]];
    $Unused = "!";                  # dummy piece
    $Next{ $Unused } = "F";
    new_Board( $width, $height );
}


sub solve {
    my ( $x_, $y_ ) = @_;
    if ( $Next{ $Unused } ne "" ) {
        my ( $x, $y ) = @{find_space( $x_, $y_ )};
        my $prev      = $Unused;
        while ( ( my $pc = $Next{ $prev } ) ne "" ) {
            $Next{ $prev } = $Next{ $pc };
            foreach my $fig ( @{$Pieces{ $pc }} ) {
                if ( check( $x, $y, $fig ) ) {
                    place( $x, $y, $fig, $pc );
                    solve( $x, $y );
                    place( $x, $y, $fig, SPACE );
                }
            }
            $prev = ( $Next{ $prev } = $pc );
        }
    }
    else {
        $Solutions ++;
        my $curs_up = ($Solutions > 1)? sprintf( "\e[%dA", $height * 2 + 2 ) : "";
        printf( "%s%s%d\n", $curs_up, render(), $Solutions );
        #my $line = <STDIN>;
    }
}

#################################

my ( $width, $height ) = @{[ 6, 10 ]};

foreach my $arg ( @ARGV ) {
    if ( $arg eq "--debug" ) {
        $debug_flg = 1;
    }
    my @sz = $arg =~ /^(\d+)\D(\d+)$/;
    @sz = map( int($_), @sz );
    if ( scalar(@sz) == 2 && $sz[0] >= 3 && $sz[1] >= 3 &&
         ( $sz[0] * $sz[1] == 60 || $sz[0] * $sz[1] == 64 ) ) {
        ( $width, $height ) = @sz;
    }
}

new_Solver( $width, $height );
solve( 0, 0 );
