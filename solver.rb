# -*- coding:utf-8 -*-

#
# Pentomino Puzzle Solver with Ruby
#
$stdout.sync = true

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
).lines.flat_map.with_index do |l, y|
  l.chars.map.with_index { |c, x|  [c, [x/2, y] ] }
end.each_with_object( Hash.new([]) ) { |(c, xy), h|  h[c] += [xy] }
# --> Hash: { "F"=>[ [2,  3], [ 3, 3], [ 1, 4], [ 2, 4], [ 2, 5] ],
#             "P"=>[ [17, 3], [18, 3], [17, 4], [18, 4], [17, 5] ],

##################################################

$debug_flg = false

class Piece
  attr_reader   :id
  attr_accessor :next, :figs

  def initialize( id, fig_def, next_pc )
    @id   = id
    @next = next_pc
    @figs = Array.new(8) do |r_f|          # rotation and flip
      fig = fig_def.map do |x,y|
        ( r_f % 4 ).times{ x, y = -y, x }  # rotate
        ( r_f < 4 )? [x, y] : [-x, y]      # flip
      end.sort_by do |x,y|                 # sort
        [y, x]
      end
      fig.map do |x,y|                     # normalize
        [ x - fig.first[0], y - fig.first[1] ]
      end
    end.uniq                               # uniq

    if $debug_flg
      puts "#{id}: (#{@figs.size})"
      @figs.each{ |fig| puts "    " + fig.to_s }
    end
  end

end # class Piece

####################################################

class Board
  attr_reader   :width, :height

  def initialize( w, h )
    @width  = w
    @height = h
    @cells  = Array.new( @height ) { Array.new( @width ) { :SPACE } }
    if w * h == 64               # 8x8 or 4x16
      place( w / 2 - 1, h / 2 - 1, [ [0,0], [0,1], [1,0], [1,1] ], '@' )
    end
  end


  def at( x, y )
    ( x >= 0 && x < @width  && y >= 0 && y < @height )? @cells[y][x] : '?'
  end


  def check?( ox, oy, fig )
    fig.all? { |x,y| at( x + ox, y + oy ) == :SPACE }
  end


  def place( ox, oy, fig, id )
    fig.each { |x,y|  @cells[ y + oy ][ x + ox ] = id  }
  end


  def find_space( x, y )
    while @cells[ y ][ x ] != :SPACE
      x, y = 0, y + 1  if ( x += 1 ) == @width
    end
    return [ x, y ]
  end

  #         2
  # (-1,-1) | (0,-1)
  #   ---4--+--1----
  # (-1, 0) | (0, 0)
  #         8
  ELEMS = [
    # 0      3     5    6    7     9    10   11   12   13   14   15
    "    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---",
    "    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   "
  ].map { |s| s.split(',') }.transpose

  def render()
    Array.new( @height + 1 ) do |y|
      Array.new( @width + 1 ) do |x|
        ELEMS[ ( ( at( x+0, y+0 ) != at( x+0, y-1 ) )? 1: 0 ) |
               ( ( at( x+0, y-1 ) != at( x-1, y-1 ) )? 2: 0 ) |
               ( ( at( x-1, y-1 ) != at( x-1, y+0 ) )? 4: 0 ) |
               ( ( at( x-1, y+0 ) != at( x+0, y+0 ) )? 8: 0 ) ]
      end.transpose.map(&:join)
    end.flatten.join( "\n" )
  end

end # class Board

####################################################

class Solver
  def initialize( w, h )
    @solutions = 0
    @board     = Board.new( w, h )

    pc = nil
    'FLINPTUVWXYZ'.reverse.each_char do |id|
      pc = Piece.new( id, PIECE_DEF[id], pc )
    end
    @Unused = Piece.new( '!', [], pc )      # dummy piece
    # limit the symmetry of 'F'
    pc.figs = pc.figs[ 0, (w == h)? 1 : 2 ]
  end


  def solve( x, y )
    if (prev = @Unused).next != nil
      x, y = @board.find_space( x, y )
      while ( pc = prev.next ) != nil
        prev.next = pc.next
        pc.figs.each do |fig|
          if @board.check?( x, y, fig )
            @board.place( x, y, fig, pc.id )
            solve( x, y )                      # call recursively
            @board.place( x, y, fig, :SPACE )
          end
        end
        prev = (prev.next = pc)
      end
    else
      @solutions += 1
      curs_up = (@solutions > 1)? ("\033[%dA" % [@board.height * 2 + 2]) : ""
      printf( "%s%s%d\n", curs_up, @board.render(), @solutions )
    end
  end

end  # class Solver

####################################################

width, height = 6, 10
while arg = ARGV.shift
  $debug_flg = true   if arg == "--debug"

  sz = arg.match( /^(\d+)\D(\d+)$/ ).to_a[1..-1].to_a.map{ |s| s.to_i }
  if sz.size == 2 && sz[0] >= 3 && sz[1] >= 3 &&
     ( sz[0] * sz[1] == 60 || sz[0] * sz[1] == 64 )
    width, height = sz[0], sz[1]
  end
end

solver = Solver.new( width, height )
solver.solve( 0, 0 )
