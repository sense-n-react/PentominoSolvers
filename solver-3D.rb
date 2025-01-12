#! /usr/bin/env ruby
# -*- coding:utf-8 -*-

require 'optparse'

# default options
OPT = { size: [6,10,1], every: 1, windup: true }

exit(1) unless ARGV.options {|opt|
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
        ) {|v|
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
  }

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
}

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
).split("\n").each_with_index.map do |l, y|
  l.split('').each_with_index.map { |c, x| [ c, x, y ] }
end.flatten(1).each_with_object( Hash.new([]) ) do |cxy, h|
  h[ cxy[0] ] += [ [ cxy[1] / 2, cxy[2] ] ]   if cxy[0] =~ /\w/
end


#
# Fig
#
class Fig
  @@grid     = nil
  def self.grid=( grid ); @@grid = grid;       end

  @@bits2fig = {}
  def self.all_figs;      @@bits2fig.values;   end

  attr_reader :pc, :pts, :bits
  attr_reader :symms        #[ :x, :Rz ...]

  def initialize( _pc, _pts )
    @pc  = _pc
    @pts = _pts

    @bits = @@grid.pts2bit( _pts )
    @@bits2fig[ @bits ] = self

    # ミラーが自分と一致する 軸 を全て求めておく
    @symms = @@grid.symms.select{ |symm| mirror_by_axis( symm ) == self }
  end

  def inspect;  to_s;  end

  def to_s
    sprintf( '@id="%s" 0x%016x, symms=%s, [%s]',
             @pc.id, @bits,
             @symms,
             @pts.map{ |pt| "(%d,%d,%d)" % [*pt] }.join( ',')
           )
  end

  # axes: [:x], [:y], [:z], [:x,:y], [:x,:z], [:y,:z], [:x,:y,:z]
  def mirror_by_axis( axes )
    _W, _H, _D = @@grid.width - 1, @@grid.height - 1, @@grid.depth - 1
    pts_ = axes.inject( @pts ){ |pts, ax|
      pts.map{ |x,y,z|
        case ax
        when :x;  [ _W - x,      y,      z ]
        when :y;  [      x, _H - y,      z ]
        when :z;  [      x,      y, _D - z ]
        when :r;  [      y,      x,      z ]
        else
          raise "unknow axis #{ax}"
        end
      }
    }

    bits = @@grid.pts2bit( pts_ )
    @@bits2fig[ bits ]
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

    # 0/90/180/270回転 × 反転 の組み合わせでピースの座標を計算する
    @org_pts = Array.new(24){ |r_f|      # rotate(4), flip(2), plane(3)
      fig = fig_points.map{ |x,y|
        z = 0
        (r_f % 4).times{ x, y = -y, x }          # rotate
        x, y = (r_f % 8 < 4)? [x, y] : [-x, y]   # flip
        (r_f / 8).times{ x, y, z = y, z, x }     # x plane, y plane, z plane
        [ x, y, z ]
      }.sort_by{ |x,y,z|                         # sort
        [ z, y, x ]
      }
      fig.map{ |x,y,z|                           # normalize
        ox, oy, oz = fig[0]
        [ x - ox, y - oy, z - oz ]
      }
    }.uniq                                       # uniq

    # grid上 位置毎に配置可能な全ての fig を計算
    @figs_at = Array.new( @@grid.size ) { |bp|
      ox, oy, oz = @@grid.bp2pt[bp]
      @org_pts.map{ |pts|
        pts.map{ |x,y,z| [ x + ox, y + oy, z + oz ] }
      }.select{ |pts|
        # Grid に収まり、穴に干渉しない場合のみ
        pts.all?{ |pt| @@grid.is_inside?( *pt ) } &&
          ( @@grid.pts2bit( pts ) & @@grid.bits ) == 0
      }.map{ |pts|
        Fig.new( self, pts )
      }.select{ |fig|
        # セル数が５の倍数でない閉塞空間を作る fig を排除。
        # fig を置いてみて連続した空白のセル数を数える
        # 左上が空いていなければ右下から数える
        n  = @@grid.space_num( (bp != 0)? 0 : ( @@grid.size - 1 ),
                               [ 0, fig.bits | @@grid.bits ] )
        ( ( n % 5 ) == 0 || ( n % 5 ) == ( @@grid.sp_size - 60 ) ).
          tap{|f|
          if OPT[:debug] && ! f
            puts @id
            puts @@grid.render( [fig] )
            gets
          end
        }
      }
    }
  end   # initializ()


  # 対称性を排除する anchor_figs
  def make_anchors
    symms_list = ( Fig::all_figs.map{ |v| v.symms } + [ @@grid.symms ] ).uniq

    @anchor_figs = symms_list.each_with_object( {} ) { |symms, h |
      h[ symms ] = @figs_at.flatten.map{ |fig|
        # 自分自身（fig）とmirrorの中で 最小の fig.bits を採用する
        ( [fig] + symms.map{ |symm| fig.mirror_by_axis( symm ) }).
          uniq.
          sort_by{ |fig| fig.bits }[0]
      }.uniq
    }
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
  BITs64 = Array.new(64) {|b| 1 << b }  # LSB が (x,y,z) = (0,0,0)
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

    @bp2pt = Array.new( @size ) {|bp|
      z, xy = bp.divmod( @height * @width )
      y, x = xy.divmod( @width )
      [ x, y, z]
    }

    if @size > 60 && !opt[:hole]
      cx, cy = @width / 2, @height / 2
      hole = [ [cx,cy], [ cx-1, cy], [cx,cy-1], [cx-1,cy-1] ]  if @size == 64
      hole = [ [cx,cy-1], [cx,cy], [cx,cy+1] ]                 if @size == 63
      @sp_size = 60
      @bits    = pts2bit( hole.map{ |x,y| [x,y,0] } )
    end

    # ミラー軸の組み合わせ
    # [:x], [:y], [:z], [:x,:y], [:x,:z], [:y,:z], [:x,:y,:z]
    axes = [ :x, :y ]
    axes << :z  if @depth != 1
    axes << :r  if @width == @height && @depth == 1
    @symms = ( 1 .. axes.size ).inject( [] ){ |a, n|
      a += axes.combination(n).to_a.sort
    }
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
    # array
    grid = Array.new( @size ){ :SPACE }
    id = ->( *pt ) { is_inside?( *pt )? grid[ offset( *pt ) ] : nil }
    # Piece ID の表示
    disp_id = Array.new( @size ){ opt_print ? ' ' : '.' }

    figs.each{ | fig |
      pc_id = fig.pc.id
      fig.pts.each {|pt|
        grid[ offset( *pt ) ]    = pc_id
        disp_id[ offset( *pt ) ] = ' '
      }

      if opt_print
        last_z, ch = -1, fig.pc.id
        fig.pts.each {|x,y,z|
          next if  last_z == z
          disp_id[ offset( x,y,z ) ]  = ch;  ch = ch.downcase
          u, v = 1, 0
          4.times{ last_z = z  if fig.pc.id == id.(x+u, y+v, z); u,v = v,-u }
        }
      end
    }

    Array.new( @height + 1 ) {|y|
      Array.new( @depth ) { |z|
        Array.new( @width + 1 ) { |x|
          code = ( ( id.( x,   y  , z ) != id.( x,   y-1, z ) )? 1: 0 ) |
                 ( ( id.( x,   y-1, z ) != id.( x-1, y-1, z ) )? 2: 0 ) |
                 ( ( id.( x-1, y-1, z ) != id.( x-1, y  , z ) )? 4: 0 ) |
                 ( ( id.( x-1, y  , z ) != id.( x,   y  , z ) )? 8: 0 )
          ch = id.(x,y,z) ? disp_id[ offset(x,y,z) ] : ' '
          [ BORDER[0][code], BORDER[1][code].clone.tap{|s| s[2] = ch } ]
        }.transpose.map(&:join)
      }.transpose.map(&:join)
    }.flatten
  end

  #
  # 連続した空白を数える
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

    id_list.each_with_index{ |id, i|
      Piece[id].next   = Piece[ id_list[i+1] ]  # Piece[ nil ] => nil
    }
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

    # 最初のPiece として 座標を持たない Fig を使う
    # 配置を制限して対称の解を排除する
    nil_fig  = Piece[ '@' ].figs_at[0][0]

    solve( nil_fig, @grid.symms ) { |cond, figs|
      if cond == :done
        @solutions += 1
        last_solution = figs
      end
      if @o[:every] != 0 && ( @solutions % @o[:every] == 0 || @solutions == 1 )
        show_solution( figs )
      end
    }

    show_solution( last_solution )  if @o[:every] != 0

    printf( "total solution(s): %7s   %.2f sec\n" +
            "        try count: %s\n",
            delim3(@solutions), Time.now - @start_time,
            delim3(@try_count) )
  end


  def solve( _fig, _symms = [] )
    @try_count += 1

    @grid.place( _fig )
    yield [ :place, [_fig] ] if @o[:step]

    prev = @Unused
    if ( bp = @grid.find_space() ) == @grid.size
      yield [ :done, [_fig] ]    # done !

    elsif ! _symms.empty?
      # 対称性が残っている場合、対称性を制限する anchor_figs を設定する
      anchor    = prev.next
      prev.next = anchor.next
      anchor.anchor_figs[ _symms ].each{ |fig|
        if @grid.check( fig )
          solve( fig, _symms & fig.symms ) { |cond, figs|
            yield [ cond, figs.unshift( _fig ) ]
          }
        end
      }
      prev.next = anchor

    else
      while ( pc = prev.next ) != nil
        prev.next = pc.next
        pc.figs_at[bp].each{ |fig|
          if @grid.check( fig )
            solve( fig ) { |cond, figs|
              yield [ cond, figs.unshift( _fig ) ]
            }
          end
        }
        prev = ( prev.next = pc )
      end

    end

    @grid.unplace( _fig )
    yield [ :unplace, [] ] if @o[:step] && @o[:interactive]

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
