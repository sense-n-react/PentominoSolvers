# -*- coding:utf-8 -*-
#
# Pentomino Puzzle Solver with Ruby
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
).lines.flat_map.with_index do |line, y|
  line.chars.map.with_index do |c, x|
    [c, x/2, y]
  end
end.each_with_object( Hash.new([]) ) do |(c,*xy), h|
  h[c] += [ xy ]
end.transform_values do |points|
  Array.new( 8 ) do |r_f|
    points.map do |x,y|
      ( r_f % 4 ).times { x, y = -y, x }   # rotate
      ( r_f < 4 )? [x, y] : [-x, y]        # flip
    end.sort_by do |x,y|                   # sort
      [y, x]
    end.then do |pts|                      # normalize
      pts.map { |x,y| [ x - pts[0][0], y - pts[0][1] ] }
    end
  end.uniq                                 # uniq
end

PIECE_DEF['F'].slice!(2 .. -1)             # limit the symmetry of 'F'

@width, @height = 6, 10
@solutions      = 0
@cells          = Array.new( @height ) { Array.new( @width, :SPACE ) }

##################################################

def at( x, y )
  ( x >= 0 && x < @width  && y >= 0 && y < @height )? @cells[y][x] : nil
end

def check?( x, y, fig )
  fig.all? { |u,v| at( x + u, y + v ) == :SPACE }
end

def place( x, y, fig, id )
  fig.each { |u,v| @cells[y + v][x + u] = id }
end

def find_space( x, y )
  while @cells[y][x] != :SPACE
    x += 1
    x, y = [0, y + 1]  if x == @width
  end
  [ x, y ]
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
].map { |s| s.split(',') }

def render()
  Array.new( @height + 1 ) do |y|
    Array.new( @width + 1 ) do |x|
      ids = [ [0,0], [0,1], [1,1], [1,0] ].map { |u,v| at( x-u, y-v ) }
      ( ( ids[0] != ids[1] ? 1 : 0 ) +
        ( ids[1] != ids[2] ? 2 : 0 ) +
        ( ids[2] != ids[3] ? 4 : 0 ) +
        ( ids[3] != ids[0] ? 8 : 0 ) )
    end.then do |codes|
      [ codes.map{ |c| ELEMS[0][c] }.join,
        codes.map{ |c| ELEMS[1][c] }.join ]
    end
  end.join( "\n" )
end

def solve( x, y, pieces )
  if pieces.size > 0
    x, y = find_space( x, y )
    pieces.each_with_index do |id,i|
      rest = pieces.clone.tap { |org| org.delete_at(i) }
      PIECE_DEF[ id ].each do |fig|
        if check?( x, y, fig )              # check
          place( x, y, fig, id )            # place
          solve( x, y, rest )               # call recursively
          place( x, y, fig, :SPACE )        # unplace
        end
      end
    end
  else
    @solutions += 1
    printf( "%s%s%d\n",
            (@solutions > 1)? ("\033[%dA" % [@height * 2 + 2]) : "",
            render(),
            @solutions )
  end
end

####################################################
solve( 0, 0, %w( F I L N P T U V W X Y Z) )
