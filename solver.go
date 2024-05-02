// -*- coding:utf-8 -*-

//
// Pentomino Puzzle Solver with Go
//

package main

import (
  "os"
  "fmt"
  "sort"
  "strings"
  "strconv"
)

const PIECE_DEF_DOC =`
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
`

type Point struct { x int;  y int }
type Fig []Point

const SPACE = ' '

var ELEMS [][]string
var debug_flg bool

func piece_def( id rune) []Point {
  var ret [] Point
  x := 0;   y := 0
  for _, ch := range PIECE_DEF_DOC {
    if  ch == id  { ret = append( ret, Point{ x/2, y } )  }

    if ch == '\n' { y++; x = 0
    } else        { x++ }
  }
  return ret
}

func init() {
  //         2
  // (-1,-1) | (0,-1)
  //   ---4--+--1----
  // (-1, 0) | (0, 0)
  //         8
  elem := []string {
    //0      3     5    6    7     9    10   11   12   13   14   15
    "    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---",
    "    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   ",
  }

  ELEMS = [][]string{
    strings.Split( elem[0], "," ),
    strings.Split( elem[1], "," ),
  }

  debug_flg = false
}

///////////////////////////////////////////////////////////////////

type Piece struct {
  next *Piece
  id   rune
  figs []Fig
}


func NewPiece( id rune, fig_def Fig, next *Piece ) *Piece{

  self := Piece{ id: id, next: next }

  for r_f := 0; r_f < 8; r_f++ {
    var fig []Point
    for _, pt := range fig_def {
      for t := 0; t < ( r_f % 4 ); t++ { pt.x, pt.y = -pt.y, pt.x }
      if r_f >= 4                      { pt.x       = -pt.x       }
      fig = append( fig, pt )
    }

    //sort
    sort.Slice( fig, func( i, j int ) bool {
      if fig[i].y == fig[j].y { return fig[i].x < fig[j].x }
      return fig[i].y < fig[j].y
    })

    // normalize
    for i := len( fig ) - 1; i >= 0; i--  {
      fig[i].x -= fig[0].x
      fig[i].y -= fig[0].y
    }

    // uniq
    if ! strings.Contains( fmt.Sprint(self.figs), fmt.Sprint(fig) ) {
      self.figs = append( self.figs, fig )
    }
  }

  if debug_flg {
    fmt.Printf( "%s: (%d)\n", string(id), len( self.figs ) )
    for _, fig := range self.figs {
      fmt.Printf( "    %s\n", fmt.Sprint(fig) )
    }
  }
  return &self
}

///////////////////////////////////////////////////////////////////

type Board struct {
  cells  [][]rune
  width  int
  height int
}


func NewBoard( width int,  height int ) *Board {
  self := Board{ width: width, height: height }

  for i := 0; i < self.height; i++  {
    var line  []rune
    for j := 0; j < self.width; j++ {
      line = append( line, SPACE )
    }
    self.cells= append( self.cells, line )
  }
  if width * height == 64 {      // 8x8 or 4x16
    self.cells[ height/2 - 1 ][ width/2 - 1] = '@'
    self.cells[ height/2 - 1 ][ width/2    ] = '@'
    self.cells[ height/2     ][ width/2 - 1] = '@'
    self.cells[ height/2     ][ width/2    ] = '@'
  }

  return &self
}


func (self *Board)render() string {
  var lines []string
  for y := 0; y <= self.height; y++ {
    for d := 0; d < 2; d++ {
      line := ""
      for x := 0; x <= self.width; x++ {
        c := 0
        if self.at( x+0, y+0 ) != self.at( x+0, y-1 ) { c += 1 }
        if self.at( x+0, y-1 ) != self.at( x-1, y-1 ) { c += 2 }
        if self.at( x-1, y-1 ) != self.at( x-1, y+0 ) { c += 4 }
        if self.at( x-1, y+0 ) != self.at( x+0, y+0 ) { c += 8 }
        line += ELEMS[ d ][ c ]
      }
      lines = append( lines, line )
    }
  }
  return strings.Join( lines, "\n" )

}


func (self *Board)at( x int, y int ) rune {
  if x >= 0 && x < self.width && y >= 0 && y < self.height {
    return self.cells[y][x]
  }
  return '?'
}


func (self *Board)check( ox int, oy int, fig Fig ) bool {
  for i := range fig  {
    if self.at( ox + fig[i].x, oy + fig[i].y ) != SPACE {
      return false
    }
  }
  return true
}


func (self *Board)place( ox int, oy int, fig Fig, id rune ) {
  for i := range fig  {
    self.cells[ oy + fig[i].y ][ ox + fig[i].x ] = id
  }
}


func(self *Board)find_space( x int, y int ) Point {
  for  self.cells[y][x] != SPACE  {
    x = ( x + 1 ) % self.width
    if x == 0  { y++ }
  }
  return Point{ x, y }
}

///////////////////////////////////////////////////////////////////

type Solver struct {
    Unused  *Piece
    board *Board
    solutions int
}


func NewSolver( width int,  height int ) *Solver {
  self := Solver{ solutions: 0 }

  var pc *Piece = nil
  ids := []rune( "FLINPTUVWXYZ" )         // the first 'X' is dummy
  for i := len(ids) - 1; i >= 0; i--  {
    pc = NewPiece( ids[i], piece_def( ids[i] ), pc )
  }
  self.Unused = NewPiece( '!', [] Point{}, pc )
  // limit the symmetry of 'F'
  if width == height {
    pc.figs = pc.figs[0:1]
  } else {
    pc.figs = pc.figs[0:2]
  }

  self.board = NewBoard( width, height )

  return &self
}


func (self *Solver)solve( x int, y int ) {
  if  self.Unused.next != nil {
    xy   := self.board.find_space( x, y )
    x = xy.x
    y = xy.y                              // update x,y
    prev := self.Unused
    for prev.next != nil {
      pc := prev.next
      prev.next = pc.next
      for _, fig := range pc.figs  {
        if self.board.check( x, y, fig ) == true {
          self.board.place( x, y, fig, pc.id )
          self.solve( x, y )
          self.board.place( x, y, fig, SPACE )
        }
      }
      prev.next = pc
      prev      = pc
    }
  } else {
    self.solutions++
    curs_up := ""
    if self.solutions > 1 { curs_up = fmt.Sprintf( "\033[%dA", self.board.height * 2 + 2 ) }
    fmt.Printf( "%s%s%d\n", curs_up, self.board.render(), self.solutions )
  }
}

///////////////////////////////////////////////////////////////////


func main() {
  width  := 6
  height := 10
  for _, arg := range os.Args {
    if arg == "--debug" { debug_flg = true }
    ar := strings.Split( arg, "x" )
    if len(ar) == 2 {
      w, err := strconv.Atoi( ar[0] )
      if err == nil {
        h, err := strconv.Atoi( ar[1] )
        if err == nil && w >=3 && h >= 3 && ( w * h == 60 || w * h == 64 ) {
          width  = w
          height = h
        }
      }
    }
  }

  solver := NewSolver( width, height )
  solver.solve( 0, 0 )
}
