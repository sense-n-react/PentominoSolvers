#! /usr/bin/env ruby
# -*- coding:utf-8 -*-

require 'optparse'

# default options
OPT = { size: [6,10,1], every: 1, windup: true }

exit(1) unless ARGV.options do |opt|
  opt.banner =<<EOT
  Size  Solutions   Size   Solutions   Size  Solutions   Size  Solutions
  ----- ---------   ------ ---------   ----- ---------   ------ ---------
  6x10    2,339     5x4x3   3,940      8x8h       65     7x9h      150
  5x12    1,010     6x5x2     264      8x8    16,146     7x9    62,024
  4x15      368     10x3x2     12      4x16h      47     3x21       56
  3x20        2                        4x16    2,451

EOT

  opt.on( '-s', '--size WxHxD',
          "#{OPT[:size].join('x')}(default)",
          '8x8h, 7x9h : with a hole in the middle'
        ) do |v|
    sz = v.match(/(\d+)\D(\d+)h?/i).to_a[1..-1].map{ |s| s.to_i }

    if sz.size == 2
      sz[2] = (sz[0] * sz[1] >= 60)? 1 : ( 60 /(sz[0] * sz[1] ) )
    end
    if sz.size != 3 || [ 60, 64, 63 ].all?{ |s| sz.inject(:*) != s }
      puts "Wrong SIZE: #{v}"
      exit -1
    end
    sz = [ sz[1], sz[2], 1 ] if sz[0] == 1
    sz = [ sz[0], sz[2], 1 ] if sz[1] == 1
    OPT[:hole] = v !~ /h$/i
    [sz]  # for optparse 0.5.0
  end

  opt.on( '-e', '--every N',
          'display a solution every N times.',
          '(nothing when N=0)' )                { |v| v.to_i  }
  opt.on( '-i', '--interactive' )
  opt.on( '-n', '--[no-]windup' )
  opt.on( '-p', '--print', 'print piece ID' )
  opt.on( '-3', '--3D', 'equivalent -s3x4x5'  ) { |v| OPT[:size] = [3,4,5]; v }
  opt.on( '--step', 'show step-by-step' )
  opt.on( '-d',  '--debug' )
  opt.parse!( into: OPT )
end

OPT[:size].flatten!   # for optparse 0.5.0

################################################
#
#  Piece Definition
#
PIECE_DEF = %Q(
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
|       |   b   |
| s s   |   b   |
| s s   |   b   |
|       |       |
+-------+-------+
).lines.flat_map.with_index do |line, y|
  line.chars.map.with_index { |c, x| [ c, x/2, y ] }
end.each_with_object( Hash.new([]) ) do |(c,*xy), h|
  h[ c ] += [ xy ]   if c =~ /\w/
end


#
# Fig
#
class Fig
  @@grid     = nil
  def self.grid=( grid ); @@grid = grid;       end

  @@bits2fig = {}
  def self.[]( bits );    @@bits2fig[ bits ];  end
  def self.all_figs;      @@bits2fig.values;   end

  attr_reader :pc, :pts, :bits
  attr_reader :symms        #[ :x, :Rz ...]

  def initialize( _pc, _pts )
    @pc  = _pc
    @pts = _pts

    @bits = @@grid.pts2bit( _pts )
    @@bits2fig[ @bits ] = self

    # Determine all axes where the mirror matches itself
    @symms = @@grid.symms.select do |symm|
      mirror_by_symm( symm ) == self
    end
  end

  def inspect;  to_s;  end

  def to_s
    sprintf( '@id="%s" 0x%016x, symms=%s, [%s]',
             @pc.id, @bits,
             @symms,
             @pts.map{ |pt| "(%d,%d,%d)" % [*pt] }.join( ',')
           )
  end

  # symm: [:x], [:y], [:z], [:x,:y], [:x,:z], [:y,:z], [:x,:y,:z]
  def mirror_by_symm( symm )
    # Place :r at the very end for reflection
    pts = @pts.map do |x,y,z|
      x = @@grid.width  - 1 - x  if symm.include?( :x )
      y = @@grid.height - 1 - y  if symm.include?( :y )
      z = @@grid.depth  - 1 - z  if symm.include?( :z )
      x, y = y, x                if symm.include?( :r )
      [ x, y, z]
    end

    Fig[ @@grid.pts2bit( pts ) ]
  end

end  # class Fig

#
# Piece
#
class Piece
  @@grid    = nil
  def self.grid=( grid ); @@grid = grid; end

  @@Pieces  = {}
  def self.[]( id );    @@Pieces[id];    end

  attr_reader   :id, :figs_at, :anchor_figs
  attr_accessor :next

  def initialize( id, fig_points )
    @id      = id
    @next    = nil
    @@Pieces[id] = self

    # Calc piece coordinates for all combinations of 0/90/180/270 degree rotation x flip
    @org_pts = Array.new(24) do |r_f|      # rotate(4), flip(2), plane(3)
      fig = fig_points.map do |x,y|
        z = 0
        (r_f % 4).times{ x, y = -y, x }          # rotate
        x, y = (r_f % 8 < 4)? [x, y] : [-x, y]   # flip
        (r_f / 8).times{ x, y, z = y, z, x }     # x plane, y plane, z plane
        [ x, y, z ]
        end.sort_by do |x,y,z|                   # sort
        [ z, y, x ]
      end
      fig.map do |x,y,z|                         # normalize
        ox, oy, oz = fig[0]
        [ x - ox, y - oy, z - oz ]
      end
    end.uniq                                     # uniq

    # Cal all figs that can be placed at each position on the grid
    @figs_at = Array.new( @@grid.size ) do |bp|
      ox, oy, oz = @@grid.bp2pt[bp]
      @org_pts.map do |pts|
        pts.map{ |x,y,z| [ x + ox, y + oy, z + oz ] }
      end.select do |pts|
        # all points are inside the Grid and does not interfere with holes
        pts.all?{ |pt| @@grid.is_inside?( *pt ) } &&
          ( @@grid.pts2bit( pts ) & @@grid.bits ) == 0
      end.map do |pts|
        Fig.new( self, pts )
      end.select do |fig|
        # Eliminate figs that create enclosed spaces whose number of cells
        # is not a multiple of 5,
        # Count the number of consecutive empty cells after placing the fig.
        # If the top-left is not empty, start counting from the bottom-right
        n  = @@grid.space_num( (bp != 0)? 0 : ( @@grid.size - 1 ),
                               [ 0, fig.bits | @@grid.bits ] )
        ( ( n % 5 ) == 0 || ( n % 5 ) == ( @@grid.sp_size - 60 ) ).
          tap do |f|
          if OPT[:debug] && ! f
            puts @id
            puts @@grid.render( [fig] )
            gets
          end
        end
      end
    end
  end   # initializ()


  # anchor_figs that remove symmetry
  def make_anchors
    symms_list = ( Fig::all_figs.map{ |v| v.symms } + [ @@grid.symms ] ).uniq

    @anchor_figs = symms_list.each_with_object( {} ) do |symms, h |
      h[ symms ] = @figs_at.flatten.map do |fig|
        # use the fig with the smallest bits among itself (fig) and its mirrors
        ( [fig] + symms.map{ |symm| fig.mirror_by_symm( symm ) }).
          uniq.
          min{ |a,b| a.bits <=> b.bits }
      end.uniq
    end
  end

  def inspect;  to_s;  end

  def to_s
    sprintf( "Piece: '%s' next:'%s'",
             @id,
             @next ? @next.id: 'nil'
           )
  end

end  # class Piece


#
# Grid
#
class Grid
  BITs64 = Array.new(64) {|b| 1 << b }  # LSB : (x,y,z) = (0,0,0)
  BITPOS = (0..64).each_with_object( {} ) { |i, h|  h[ 1 << i ] = i }

  attr_reader :width, :height, :depth, :size, :sp_size
  attr_reader :bits, :bp2pt, :symms

  # [x,z,z] -> bp
  def offset( x, y, z )
    ( z * @height + y ) * @width + x
  end

  def is_inside?( x, y, z )
    x >= 0 && x < @width  &&  y >= 0 && y < @height  &&  z >= 0 && z < @depth
  end

  def pts2bit( pts )
    pts.inject( 0 ) { |b, pt| BITs64[ offset( *pt ) ] | b }
  end

  def initialize( opt )
    @width, @height, @depth = opt[:size]
    @size                   = opt[:size].reduce(:*)
    @sp_size = @size
    @bits    = 0

    @bp2pt = Array.new( @size ) do |bp|
      z, xy = bp.divmod( @height * @width )
      y, x = xy.divmod( @width )
      [ x, y, z]
    end

    if @size > 60 && !opt[:hole]
      cx, cy = @width / 2, @height / 2
      hole = [ [cx,cy], [ cx-1, cy], [cx,cy-1], [cx-1,cy-1] ]  if @size == 64
      hole = [ [cx,cy-1], [cx,cy], [cx,cy+1] ]                 if @size == 63
      @sp_size = 60
      @bits    = pts2bit( hole.map{ |x,y| [x,y,0] } )
    end

    # Combinations of mirror axes
    # [:x], [:y], [:z], [:x,:y], [:x,:z], [:y,:z], [:x,:y,:z]
    axes = [ :x, :y ]
    axes << :z  if @depth != 1
    axes << :r  if @width == @height && @depth == 1
    @symms = ( 1 .. axes.size ).inject( [] ) do |a, n|
      a += axes.combination(n).to_a.sort
    end
  end


  #         |
  # (-1,-1) 2   (0,-1)
  #         |
  #   ---4--+--1---
  #         |
  # (-1,0)  8   (0,0)
  #         |
  #
  BORDER = [
    #0      3     5    6    7     9    10   11   12   13   14   15
    '    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---',
    '    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   '
  ].map{ |s| s.split(/,/) }

  # figs  :  [fig1, fig2, ....]
  def render( figs, opt_print = false )
    grid    = Array.new( @size, :SPACE )     # ID
    disp_id = Array.new( @size, '.' )        # ID to show
    id = ->( *pt ) { is_inside?( *pt )? grid[ offset( *pt ) ] : nil }

    figs.each do | fig |
      fig.pts.each { |pt| grid[ offset( *pt ) ] = fig.pc.id }
    end
    figs.each do | fig |
      last_z, ch = -1,  (opt_print ? fig.pc.id : ' ')
      fig.pts.each do |x,y,z|
        # display only one ID
        if last_z == z
          disp_id[ offset( x,y,z ) ] = ' '
        else
          disp_id[ offset( x,y,z ) ] = ch
          ch = ch.downcase
          last_z = z  if [ [1,0], [0,1], [-1,0], [0,-1] ].any? do |u,v|
            fig.pc.id == id.(x + u, y + v, z)
          end
        end
      end
    end

    Array.new( @height + 1 ) do |y|
      Array.new( @depth ) do |z|
        Array.new( @width + 1 ) do |x|
          ids = [ [0,0], [0,1], [1,1], [1,0] ].map { |u,v| id.( x-u, y-v, z ) }
          [ ( ids[0] != ids[1] ? 1: 0 ) +
            ( ids[1] != ids[2] ? 2: 0 ) +
            ( ids[2] != ids[3] ? 4: 0 ) +
            ( ids[3] != ids[0] ? 8: 0 ),
            id.(x,y,z) ? disp_id[ offset(x,y,z) ] : ' '
          ]
        end
      end.flatten(1).then do |codes|
        [ codes.map{ |c,id| BORDER[0][c] }.join,
          codes.map{ |c,id| BORDER[1][c].sub( /   $/, " #{id} " ) }.join ]
      end
    end.flatten
  end

  #
  # Count consecutive empty spaces
  #
  def space_num( bp, num_and_bits )
    b = BITs64[ bp ]
    if (num_and_bits[1] & b ) == 0
      num_and_bits[0] += 1
      num_and_bits[1] |= b

      x, y, z = *@bp2pt[ bp ]
      space_num( bp - 1,                num_and_bits )  if x > 0
      space_num( bp + 1,                num_and_bits )  if x < @width - 1
      space_num( bp - @width,           num_and_bits )  if y > 0
      space_num( bp + @width,           num_and_bits )  if y < @height - 1
      space_num( bp - @width * @height, num_and_bits )  if z > 0
      space_num( bp + @width * @height, num_and_bits )  if z < @depth - 1
    end
    return num_and_bits[0]
  end

  def find_space()
    # lowest zero-bit position
    return BITPOS[  ~@bits & ( @bits + 1 ) ]
  end

  def unplace( fig )
    @bits &= ~fig.bits
  end

  def place( fig )
    @bits |= fig.bits
  end

  def check( fig )
    (@bits & fig.bits ) == 0
  end

end   # class Grid

#
# Solver
#
class Solver
  attr_reader :grid

  def initialize( opt )
    @o    = opt
    @grid = Grid.new( @o )
    Fig::grid   = @grid
    Piece::grid = @grid

    # create all pieces
    PIECE_DEF.keys.each{ |id | Piece.new( id, PIECE_DEF[id] )  }
    # then make anchors
    PIECE_DEF.keys.each{ |id | Piece[id].make_anchors          }
    # dummy piece
    Piece.new( '@', [] )

    if @o[:size][2] == 1
      id_list = %w( X F I L N P T U V W Y Z )
      id_list << 's'  if @o[:hole] && @grid.size == 64
      id_list << 'b'  if @o[:hole] && @grid.size == 63
    else
      id_list = %w( I X L N Y F P T U V W Z )
    end

    id_list.each_with_index do |id, i|
      Piece[id].next   = Piece[ id_list[i+1] ]  # Piece[ nil ] => nil
    end
    @Unused      = Piece[ '@' ]
    @Unused.next = Piece[ id_list[0] ]
  end   # initialize


  def show_solution( figs )
    printf( "\033[%dA", @printed_lines ) if @o[:windup] && @printed_lines != 0

    lines = []
    lines += @grid.render( figs, @o[:print] )   if @o[:every] > 0
    lines << "%7s  %.2f sec" % [ delim3(@solutions), Time.now - @start_time ]
    print lines.join( "\n" )
    @printed_lines = lines.size

    if @o[:interactive]
      print "  hit [ret]"; gets
    else
      puts ""
    end
  end


  def run()
    @solutions     = 0
    @start_time    = Time.now
    @printed_lines = 0
    @try_count     = 0
    last_solution = []

    place_anchor( @grid.symms ) do |cond, anchor_figs|
      next  if cond != :done

      solve() do |cond, figs|
        if cond == :done
          @solutions += 1
          last_solution = anchor_figs + figs
        end
        if @o[:every] != 0 && ( @solutions % @o[:every] == 0 || @solutions == 1 )
          show_solution( anchor_figs + figs )
        end

      end
    end

    show_solution( last_solution )  if @o[:every] != 0

    printf( "total solution(s): %7s   %.2f sec\n" +
            "        try count: %s\n",
            delim3(@solutions), Time.now - @start_time,
            delim3(@try_count) )
  end


  # Set anchor_figs to restrict symmetry
  def place_anchor( _symms )
    @try_count += 1

    if _symms.empty?
      yield [ :done, [] ]
    else
      anchor = @Unused.next
      @Unused.next = anchor.next
      anchor.anchor_figs[ _symms ].each do |fig|
        if @grid.check( fig )
          @grid.place( fig )
          place_anchor( _symms & fig.symms ) do |cond, figs|
            yield [ cond, figs.unshift( fig ) ]
          end
          @grid.unplace( fig )
        end
      end
      @Unused.next = anchor
    end

  end  # place_anchor()


  def solve()
    @try_count += 1

    if ( bp = @grid.find_space() ) == @grid.size
      yield [ :done, [] ]    # done !

    else
      prev = @Unused
      while ( pc = prev.next ) != nil
        prev.next = pc.next
        pc.figs_at[bp].each do |fig|
          if @grid.check( fig )
            @grid.place( fig )
            yield [ :place, [fig] ] if @o[:step]

            solve() do |cond, figs|
              yield [ cond, figs.unshift( fig ) ]
            end

            @grid.unplace( fig )
            yield [ :unplace, [] ] if @o[:step] && @o[:interactive]
          end
        end
        prev = ( prev.next = pc )
      end

    end

  end  # solve()

end  # class Solver

#########################################################

def delim3( v ); v.to_s.reverse.scan(/.{1,3}/).join(',').reverse;  end

def main
  if ARGV.size != 0
    puts "unknown args #{ARGV}"
    exit 1
  end
  OPT[:print] ||= true   if OPT[:size][2] != 1

  @solver = Solver.new( OPT )
  @solver.run()
end

begin
  $stdout.sync = true
  main
rescue Interrupt
  puts "Interrupted"
rescue Errno::EPIPE
  puts $!
rescue
  puts $!.class
  puts $!
  puts $!.backtrace
end
