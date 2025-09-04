# Introduction

This article explains the algorithm behind the Pentomino Solver.

The program ([simple.rb](simple.rb)) is about 100 lines in total and consists of the following three parts:
- Generating initial data
- Manipulating and displaying the board
- Searching for solutions

Each part is about 30-40 lines, which makes the overall structure easy to grasp.  
If you are familiar with Ruby, you will be able to understand what it does just by looking at the program.


# Searching Solutions Strategy
1. Try all possibilities:  
    All combinations of pieces in all orientations are tested recursively using backtracking.
2. Fill from the top-left:  
    Starting from the top-left, we search for empty spaces to the right.  
    If there is no space, we move one row down and search from the left edge to the right edge.  
    Once we find an empty space, we place a piece there.
3. Eliminating symmetry:  
    For a 6x10 pentomino, there are 2,339 solutions.  
    However, if we do not exclude solutions that are mirror-images (flipped horizontally or vertically), we would find four times as many: 9,356 solutions.  
    Therefore, in order to eliminate symmetric solutions, we restrict the placement of 'F'.
4.  Optimization:  
    In favor of simplicity of the code, no optimization is performed.


# Definition of Coordinates

## Board Coordinates

The board consists of 60 cells arranged on a plane with the X-axis as the horizontal direction and the Y-axis as the vertical direction.  
For a 6x10 board, the top-left is *(0,0)* and the bottom-right is *(5,9)*.

~~~
     0   1   2   3   4   5    X
   +---+---+---+---+---+---+ 
0  |0,0|   |   |   |   |   |
   +---+---+---+---+---+---+
1  |   |   |   |   |   |   |
   +---+---+---+---+---+---+
2  |   |   |   |   |   |   |
   +---+---+---+---+---+---+
... (rows omitted) ...
7  |   |   |   |   |   |   |
   +---+---+---+---+---+---+
8  |   |   |   |   |   |   |
   +---+---+---+---+---+---+
9  |   |   |   |   |   |5,9|
   +---+---+---+---+---+---+
Y
~~~

## Piece Coordinates and *Fig* Representation

There are 12 types of pieces, identified by their shapes: 'F', 'I', 'L', 'N', 'P', 'T', 'U', 'V', 'W', 'X', 'Y', and 'Z'.  
Each piece can be placed in up to 8 ways, combining 0°/90°/180°/270° rotations and front/back reflections.  
Because of symmetry, 'T', 'U', 'V', 'W', and 'Z' have 4 placements, 'I' has 2, and 'X' only 1.

The shape and placement of a piece are uniquely represented by an array of five coordinates, each in the form (x, y).
The top-left cell of each piece is considered to be at (0,0).
Therefore, the Y-coordinate is always non-negative, but the X-coordinate may be negative.

In this article, we define a **Fig** (short for "figure") as an array of coordinates representing the shape of a piece.  
For example, in the figure below, the Fig for the left piece is
*[(0,0), (1,0), (-1,1), (0,1), (0,2)]*,
and for the right piece it is
*[(0,0), (0,1), (1,1), (2,1), (1,2)]*.

~~~
     -1   0   1      X                    0   1   2     X
        +---+---+                       +---+
0       |0,0    |                  0    |0,0| 
    +---+   +---+                       +   +---+---+
1   |       |                      1    |           |
    +---+   +                           +---+   +---+
2       |   |                      2        |   |
        +---+                               +---+
Y                                  Y

[(0,0),(1,0),(-1,1),(0,1),(0,2)]   [(0,0),(0,1),(1,1),(2,1),(1,2)]
~~~

In [simple.rb](simple.rb), the coordinate (x,y) is handled as an array of two integers.


# Array of Figs for Each Piece

For each piece ID, the array of Figs is defined in a Hash as follows:

```ruby
{ "F"=>[ [[0, 0], [1, 0], [-1, 1], [0, 1], [0, 2]],
         [[0, 0], [-1, 1], [0, 1], [1, 1], [1, 2]],
         [[0, 0], [0, 1], [1, 1], [-1, 2], [0, 2]],
         [[0, 0], [0, 1], [1, 1], [2, 1], [1, 2]],
         [[0, 0], [1, 0], [1, 1], [2, 1], [1, 2]],
         [[0, 0], [-1, 1], [0, 1], [1, 1], [-1, 2]],
         [[0, 0], [-1, 1], [0, 1], [0, 2], [1, 2]],
         [[0, 0], [-2, 1], [-1, 1], [0, 1], [-1, 2]]
       ], 
  "I"=>[ [[0, 0], [0, 1], [0, 2], [0, 3], [0, 4]],
         [[0, 0], [1, 0], [2, 0], [3, 0], [4, 0]]
       ],
   ....
  "X"=>[ [[0, 0], [-1, 1], [0, 1], [1, 1], [0, 2]]
       ],
   ....
}
```
Hardcoding this data would be cumbersome and lengthen the code.  
In [simple.rb](simple.rb), Figs are obtained from the **ASCII ART** of the piece, and the Hash is generated smartly.

```ruby
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
    [c, [x/2, y]]                                         # (A)
  end
end.each_with_object( Hash.new([]) ) do |(c,xy), h|
  h[c] += [ xy ]                                          # (B)
end.transform_values do |points|                          # (C)
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
```
**(A)**: make an array of character-position pairs, with position given by column and row.
Using *`lines`*, *`chars`*, and *`map.with_index`*, coordinates can be obtained simply.
Since one cell in ASCII ART is represented by two characters, the horizontal character position is halved to get the X-coordinate.

**(B)**: Construct a Hash with the character as the key and the Fig as the value.
By using each_with_object, the creation of a Hash from an array can be written very simply.

As a result up to this point, we obtain a Hash as shown below:
```ruby
{
  "F" => [[2, 3], [3, 3], [1, 4], [2, 4], [2, 5]],
  "I" => [[6, 2], [6, 3], [6, 4], [6, 5], [6, 6]],
```
Based on these coordinates, starting from (C), rotations, flips, and normalization are performed, and in the end we obtain an array of Figs for each piece ID.

## Rotation and Flip

There are four types of rotation: 0°, 90°, 180°, and 270°.
There are two types of flips: front and back.
So, in total, 8 combinations are possible.

```ruby
end.transform_values do |points|                          # (C)
  Array.new( 8 ) do |r_f|
```

For the array of coordinates (points) of a piece, rotations and flips are applied to generate 8 Figs.  
The block variable r_f ranges from 0 to 7, and depending on its value, the number of 90° rotations and whether to flip or not is determined.

### Rotation (rotate)

A 90° rotation can be calculated as *`x, y = -y, x`*.
180° and 270° rotations are obtained by repeating this operation two or three times.  
The number of rotations is *`r_f % 4`*, i.e. 0-3.

```ruby
     ( r_f % 4 ).times { x, y = -y, x }   # rotate
```
The rotation can be either counterclockwise or clockwise; thus, *`x, y = y, -x`* can also be used.

### Flip (flip)

In the first half of the loop (*`r_f: 0-3`*) and the second half (*`r_f: 4-7`*), the number of rotations (*`r_f % 4`*) is the same.
Therefore, flipping is switched on/off between the first and second halves.
If *`r_f < 4`*, no flip is applied.
If *`r_f >= 4`*, the piece is flipped.
Flipping can be calculated as *`x, y = -x, y`*.
```ruby
      ( r_f < 4 )? [x, y] : [-x, y]        # flip
```
It does not matter whether the flip is along the X-axis or Y-axis; *`x, y = x, -y`* could also be used.


## Normalization and Elimination of Duplicates

### Normalization (normalize)

After rotation and flip, the Fig does not necessarily have the top-left cell at *(0,0)*.

First, sort the five coordinates in ascending order.
Since pieces are placed from the top, in comparing coordinates, the Y-coordinate is prioritized over the X-coordinate.

```ruby
    end.sort_by do |x,y|                   # sort
      [y, x]
    end
```
This yields the same result as shown below:
```ruby
    end.sort do |a,b|
      a[1] == b[1] ? a[0] <=> b[0] : a[1] <=> b[1]
    end
```
Next, subtract the first coordinate from each of the five coordinates so that the first coordinate becomes *(0,0)*.
Thus, the desired Fig is obtained.
```ruby
    end.then do |pts|                      # normalize
      pts.map { |x,y| [ x - pts[0][0], y - pts[0][1] ] }
    end
```

### Elimination of Duplicates (uniq)

For symmetric pieces, normalization results in duplicate Figs.  
Since Ruby's uniq compares array elements by value, simply calling uniq removes the duplicates.

```ruby
  Array.new( 8 ) do |r_f|
     .... omitted
  end.uniq                                 # uniq
```

## Restricting the 'F' Fig

For the 6x10 pentomino, there are 2,339 solutions.
However, without any restrictions, four times as many (9,356) solutions are found.
This occurs because the solutions reflected on the X-axis, reflected on the Y-axis, and rotated 180° (i.e., reflected on both axes) are also counted as different solutions.

To eliminate such symmetric solutions, the 8 Figs of 'F' are restricted to two: 0° rotation and 90° rotation.

```ruby
PIECE_DEF['F'].slice!(2 .. -1)             # limit the symmetry of 'F'
```

By *`slice!(2 .. -1)`*, the first two Figs remain.
Note that the restricted piece does not have to be *`'F'`*-any piece with 8 Figs can be used.


# Board: cells

The board is represented as a two-dimensional array:
```ruby
@width, @height = 6, 10
@cells          = Array.new( @height ) { Array.new( @width, :SPACE ) }
```

The size of the board is 6x10.
The initial value of each array element is the constant :SPACE, which represents an empty cell.
When a piece is placed, its ID (such as 'X' or 'F') is stored in the corresponding element.

## Board operations:

### Retrieving ID: at()

```ruby
def at( x, y )
  ( x >= 0 && x < @width  && y >= 0 && y < @height )? @cells[y][x] : nil
end
```
Since *`x, y`* may be outside the board, in that case it returns *`nil`*.

### Checking placement: check?()
```
def check?( x, y, fig )
  fig.all? { |u,v| at( x + u, y + v ) == :SPACE }
end
```
Check whether a Fig:*`fig`* can be placed at position (x, y) on the board.
Because there is a possibility that it may extend outside the board, *`at()`* is used to check.
If all the corresponding coordinates' elements are *`:SPACE`*, the placement is considered possible.

### Placement: place()

```ruby
def place( x, y, fig, id )
  fig.each { |u,v| @cells[y + v][x + u] = id }
end
```
Write the piece's ID (such as 'F' or 'L') onto the board.
Because check? is performed beforehand, the piece cannot extend beyond the board.

A placed piece can be removed by setting its ID to :SPACE.
```ruby
place( x, y, fig, :SPACE )          # unplace
```

### Searching for empty space: find_space()
```ruby
def find_space( x, y )
  while @cells[y][x] != :SPACE
    x += 1
    x, y = [0, y + 1]  if x == @width
  end
  [ x, y ]
end
```
Starting from the arguments *`x, y`*, scan the cells straightforwardly in the X and Y directions.
When an empty cell is found, return that coordinate.  
As long as unplaced pieces remain, there will always be empty cells, so no bounds check is necessary.

# Searching for Solutions

The search proceeds by backtracking.
Every time a piece is placed, the method *`solve()`* is called recursively.
```ruby
def solve( x, y, pieces )
```

*`x, y`* are the initial coordinates used to search for the top-left empty space where a piece can be placed.
pieces is an array of piece IDs that have not yet been placed.
As the placement progresses, the number of unplaced pieces decreases.

## Starting the Search

In the initial call, all pieces are unplaced, and placement starts from *(0,0)*, as follows:

```ruby
solve( 0, 0, %w( F I L N P T U V W X Y Z) )
```

## State During the Search

Below is an example showing the state of the board and pieces during the search.
In the board shown below, as a result of placing 'Y', seven pieces have already been placed.

```
+-----------+-----------+   
| V         | P         |   
|   +-------+       +---+   
|   | W     |       | N |   
|   +---+   +---+---+   |   
|   | X |       |       |   
+---+   +---+   |   +---+   
|           |   |   | L |   
+---+   +---+---+   |   |   
| Y |   | *     |   |   |   
|   +---+       +---+   |   
|       |           |   |   
|   +---+       +---+   |   
|   |           |       |   
|   |           +-------+   
|   |                   |   
+---+                   |   
|                       |   
|                       |   
|                       |   
+-----------------------+   
```
The state of *`pieces`* after placing 'Y' is as follows:
```ruby
  [ "F", "I", "T", "U", "Z" ]     # pieces
```

After this, the remaining pieces will be placed at the position marked with '*' .
The following arguments will be passed to *`solve`*:
```ruby
   solve( 0, 4,  [ "F", "I", "T", "U", "Z" ]  ) 
```
Here, *(0,4)* is the coordinate of the most recently placed 'Y'.

## Backtracking Search: solve()

```ruby
def solve( x, y, pieces )
  if pieces.size > 0
    x, y = find_space( x, y )
    pieces.each_with_index do |id,i|
      rest = pieces.clone.tap { |r| r.delete_at(i) }
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
```
The arguments *`x, y`* are the starting position for searching for the top-left empty cell, and *`pieces`* is the array of piece IDs that have not yet been placed.

If no solution has yet been found, there are still unplaced pieces, so *`if pieces.size > 0`* evaluates to *`true`*.
In that case, one piece is selected from the unplaced pieces, placed on the board, and then *`solve`* is called recursively.

Placing all 12 pieces results in solve() being nested 12 levels deep.
The state of the board after placing each piece is kept within the *`solve()`* context.

Within *`solve()`*, it is necessary to create the remaining array after taking out the *`i`*-th element from *`pieces`*.
Since Ruby's *delete_at()* is destructive, using *`pieces.delete_at(i)`* is not appropriate.
Also, since *delete_at()* returns the removed element, it must be written as follows:
```ruby
      rest = pieces.clone
      rest.delete_at(i)
```
In [simple.rb](simple.rb), a slight trick is used to write the same thing in one line.
```ruby
      rest = pieces.clone.tap { |org| org.delete_at(i) }
```

## Outputting a Solution

When all pieces fit on the board, there are no unplaced pieces, and *`pieces.size`* becomes 0.
At this point, the *`else`* clause of the *`if`* statement is executed.
```ruby
  if pieces.size > 0
    #....  omitted
  else
    @solutions += 1
    printf( "%s%s%d\n",
            (@solutions > 1)? ("\033[%dA" % [@height * 2 + 2]) : "",
            render(),
            @solutions )
  end
```

Here, the solution count (*`@solutions`*) is incremented, and the current board state (*`render()`*) along with the solution number is displayed.  
To prevent the screen from scrolling when displaying multiple solutions, the cursor is moved to the top of the board from the second solution onward before rendering.
The escape sequence string for this is *`"\033[%dA"`*, where *`%d`* is replaced with the number of rows according to the height of the board.


# Board Rendering: render()

The board is displayed as text, yet it remains easy to read, using a simple code.
```ruby
#         2
# (-1,-1) | (0,-1)
#   ---4--+--1----
# (-1, 0) | (0, 0)
#         8
ELEMS = [                                                                 # (A)
  # 0      3     5    6    7     9    10   11   12   13   14   15
  "    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---",
  "    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   "
].map { |s| s.split(',') }

def render()
  Array.new( @height + 1 ) do |y|
    Array.new( @width + 1 ) do |x|
      ids = [ [0,0], [0,1], [1,1], [1,0] ].map { |u,v| at( x-u, y-v ) }   # (B)
      ( ( ids[0] != ids[1] ? 1 : 0 ) +
        ( ids[1] != ids[2] ? 2 : 0 ) +
        ( ids[2] != ids[3] ? 4 : 0 ) +
        ( ids[3] != ids[0] ? 8 : 0 ) )                                    # (C)
    end.then do |codes|
      [ codes.map{ |c| ELEMS[0][c] }.join,                                # (D)
        codes.map{ |c| ELEMS[1][c] }.join ]
    end
  end.join( "\n" )
end
```

While scanning the board line by line, the boundaries between adjacent pieces are checked to generate the full board string.

**(A)**: 
The way each cell's boundary is drawn is divided into 16 patterns, with the boundary elements (*`ELEMS`*) defined in advance.
For a given cell, the IDs of the cell itself, the cell above, the upper-left cell, and the cell to the left are compared to see whether each pair matches.
Each comparison is assigned a value of 1, 2, 4, or 8, and their combination gives a number from 0 to 15.
Each boundary element is a string of characters like +, -, |, and space, with one boundary represented by four characters across and two lines vertically.

**(B)**: The IDs of the target coordinates *(x, y)*, and those above, upper-left, and to the left are retrieved. At this time, calls to *`at()`* may attempt to access coordinates beyond the array size, such as *(-1, -1)* or *(6, 10)*. Therefore, coordinate value checking is required within *`at()`*.

**(C)**: The IDs of adjacent coordinates are compared, and from the results of the four comparisons, a value between 0 and 15 is calculated. This is the pattern value of the boundary element.

**(D)**: According to the pattern value of the boundary element, the selected element is concatenated line by line of text.

Below is an example board with the pattern values 0-15 displayed in hex, showing the relationship between the pattern values and the boundary elements.

```
+---+---+-----------+---+---+-----------+     +---+---+-----------+---+---+-----------+   
|   |   |           |   |   |           |     | 9 | D | D   5   5 | D | D | D   5   5 | C 
|   |   |   +---+   |   |   +-------+   |     |   |   |   +---+   |   |   +-------+   |   
|   |   |   |   |   |   |           |   |     | A | A | A | 9 | C | A | A   3   5 | C | A 
|   |   +---+   +---+   +---+---+   |   |     |   |   +---+   +---+   +---+---+   |   |   
|   |   |       |           |   |   |   |     | A | A | B   6 | B   6   3 | D | C | A | A 
|   |   +---+   +---+---+---+   +---+---+     |   |   +---+   +---+---+---+   +---+---+   
|   |       |       |   |           |   |     | A | A   3 | C   3 | D | D   6   3 | F | E 
|   +-------+---+---+   +---+   +---+   |     |   +-------+---+---+   +---+   +---+   |   
|   |           |   |       |   |       |     | A | B   5   7 | D | E   3 | C | 9   6 | A 
+---+   +-------+   +---+   +---+       |     +---+   +-------+   +---+   +---+       |   
|       |               |       |       |     | B   6 | 9   5   6   3 | C   3 | E   0 | A 
+-------+---------------+-------+-------+     +-------+---------------+-------+-------+   
                                                3   5   7   5   5   5   7   5   7   5   6 
```


# Conclusion

In this article, I have introduced the algorithm behind a Pentomino Solver.  
As a programming exercise, it offers plenty of opportunities for creative problem-solving and is both challenging and fun. 
I believe it's a great subject for learning the fundamentals of programming.
