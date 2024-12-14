# -*- coding:utf-8 -*-

#
# Pentomino Puzzle Solver with Crystal
#

PIECE_DEF= Hash( Char, Array(Array(Int32)) ).new( [] of Array(Int32) )
%Q(
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
).split("\n").each_with_index do |l, y|
  l.each_char.each_with_index { |c, x| PIECE_DEF[ c ] += [[ (x/2).to_i, y ]] }
end
# --> Hash: { "F"=>[ [2,  3], [ 3, 3], [ 1, 4], [ 2, 4], [ 2, 5] ],
#             "P"=>[ [17, 3], [18, 3], [17, 4], [18, 4], [17, 5] ],

##################################################

class Piece
  getter   id : Char
  property next : Piece | Nil
  property figs : Array(Array(Array(Int32)))

  def initialize( id, fig_def, next_pc )
    @id   = id
    @next = next_pc
    @figs = Array.new(8) do |r_f|                    # rotation and flip
      fig = fig_def.map do |pt|
        ( r_f % 4 ).times{ pt = [ -pt[1], pt[0] ] }  # rotate
        ( r_f < 4 )? pt : [ -pt[0], pt[1] ]          # flip
      end.sort_by do |pt|                            # sort
        [pt[1], pt[0]]
      end
      fig.map do |pt|                                # normalize
        [ pt[0] - fig.first[0], pt[1] - fig.first[1] ]
      end
    end.uniq                                         # uniq

    if Solver.debug_flg
      puts "#{id}: (#{@figs.size})"
      @figs.each{ |fig| puts "    " + fig.to_s }
    end
  end

end # class Piece

####################################################

class Board
  SPACE = ' '
  @cells : Array(Array(Char))
  getter  width : Int32,  height : Int32

  def initialize( w, h )
    @width, @height = w, h
    @cells  = Array.new( @height ) { Array.new( @width, SPACE ) }
    if w * h == 64               # 8x8 or 4x16
      place( (w/2-1).to_i, (h/2-1).to_i, [ [0,0], [0,1], [1,0], [1,1] ], '@' )
    end
  end


  def at( x, y )
    ( x >= 0 && x < @width  && y >= 0 && y < @height )? @cells[y][x] : '?'
  end


  def check?( ox, oy, fig )
    fig.all? { |pt| at( pt[0] + ox, pt[1] + oy ) == SPACE }
  end


  def place( ox, oy, fig, id )
    fig.each { |pt|  @cells[ pt[1] + oy ][ pt[0] + ox ] = id  }
  end


  def find_space( x, y )
    while @cells[ y ][ x ] != SPACE
      x, y = 0, y + 1   if ( x += 1 ) == @width
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
      end.transpose.map{ |elems| elems.join }
    end.flatten.join( "\n" )
  end

end # class Board

####################################################

class Solver
  @@debug_flg = false
  def self.debug_flg;       @@debug_flg;     end
  def self.debug_flg=( v ); @@debug_flg = v; end

  def initialize( w, h )
    @solutions = 0
    @board     = Board.new( w, h )

    pc = nil
    "FLINPTUVWXYZ".reverse.each_char do |id|
      pc = Piece.new( id, PIECE_DEF[id], pc )
    end
    @Unused = Piece.new( '!', [] of Array(Int32), pc )      # dummy piece
    # limit the symmetry of 'F'
    pc.figs = pc.figs[ 0, (w == h)? 1 : 2 ]   if pc
  end


  def solve( x, y )
    if (prev = @Unused).next
      x, y = @board.find_space( x, y )
      loop do
        pc = prev.next
        break unless pc
        prev.next = pc.next
        pc.figs.each do |fig|
          if @board.check?( x, y, fig )
            @board.place( x, y, fig, pc.id )
            solve( x, y )                      # call recursively
            @board.place( x, y, fig, Board::SPACE )
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

while ARGV.size > 0
  arg = ARGV.shift
  Solver.debug_flg = true   if arg == "--debug"

  md = arg.match( /^(\d+)\D(\d+)$/ )
  if md && md.size == 3
    sz = [ md[1].to_i, md[2].to_i ]
    if sz[0] >= 3 && sz[1] >= 3 &&
       ( sz[0] * sz[1] == 60 || sz[0] * sz[1] == 64 )
      width, height = sz[0], sz[1]
    end
  end
end

solver = Solver.new( width, height )
solver.solve( 0, 0 )
