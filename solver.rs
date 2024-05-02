// -*- coding:utf-8 -*-

//
// Pentomino Puzzle Solver with Rust
//

use std::env;
use std::fmt;
use std::cmp::Ordering;

static PIECE_DEF_DOC :&str = r#"
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
"#;

fn piece_def( id: char ) -> Vec<Vec<i32>> {
  let mut x = 0;
  let mut y = 0;
  let mut defs: Vec<Vec<i32>> = vec![];
  for ch in PIECE_DEF_DOC.chars() {
    if ch == id   { defs.append( &mut vec![vec![ x/2, y ] ] ); }
    if ch == '\n' { y = y + 1; x = 0; }
    else          { x = x + 1;        }
  }
  defs
}

///////////////////////////////////////////////////////////////
//
//#[derive(Debug)]
#[derive(Eq)]
#[derive(Clone)]
pub struct Point {
  pub x: i32,
  pub y: i32,
}

//
// '(x,y)' で表示
//
impl fmt::Debug for Point {
  fn fmt( &self, f: &mut fmt::Formatter<'_> ) -> fmt::Result {
    write!( f, "({},{})", &self.x, &self.y )
  }
}

// 比較
impl Ord for Point {
  fn cmp(&self, other: &Self) -> Ordering {
    [self.y, self.x].cmp( &[ other.y, other.x ] )
  }
}

impl PartialOrd for Point {
  fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
    Some(self.cmp(other))
  }
}

impl PartialEq for Point  {
  fn eq(&self, other: &Self) -> bool {
    self.x == other.x && self.y == other.y
  }
}

/////////////////////////////////////////////////////////////////

type Fig = Vec<Point>;

static mut DEBUG_FLG: bool = false;

struct Piece {
  id:   char,
  figs: Vec<Fig>,
}

impl Piece {
  fn new( id: char, pts: Vec<Vec<i32>> ) -> Piece {
    let mut figs = vec![];
    let mut figs_str =  "".to_string();
    for r_f in 0 .. 8 {                    // rotation & flip
      let mut fig: Fig = vec![];
      for i in 0 .. pts.len() {
        let  (mut x, mut y) = ( pts[i][0], pts[i][1] );
        for _ in 0 .. r_f % 4 {                // rotate
          let x_ = x;  x = -y;  y = x_;
        }
        if r_f >= 4  { x = -x; }               // flip
        fig.push( Point{x,y} );
      }
      fig.sort();                              // sort
      let norm: Fig = fig.iter().              // normalize
        map( |pt| Point{ x: pt.x - fig[0].x, y: pt.y - fig[0].y } ).
        collect();

      let norm_str = format!( "{:?}", norm );
      if ! figs_str.contains( &norm_str ) {    // uniq
        figs.push( norm );
        figs_str.push_str( &norm_str );
      }
    }

    let pc = Piece{ id, figs };

    if true == unsafe {DEBUG_FLG} {
       println!( "{}", pc.to_s() );
    }

    pc
  }  //impl Piece


  fn to_s(&self) -> String {
    let mut str = format!( "{}:({})\n", self.id, self.figs.len() );

    for fig in &self.figs {
      str.push_str( &format!( "{:?}\n", fig ) );
    }

    return str;
  }
}

/////////////////////////////////////////////////////////////////

struct Board<'a> {
  width:  i32,
  height: i32,
  cells: Vec<Vec<char>>,

  elems: Vec<Vec<&'a str>>,
}

impl Board<'_> {
  const SPACE:  char = ' ';

  //            2
  //    (-1,-1) | (0,-1)
  //        4 --+-- 1
  //    (-1, 0) | (0, 0)
  //            8
  const ELEM: [&'static str;2] = [
    //#0     3     5    6    7     9    10   11   12   13   14   15
    "    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---",
    "    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   "
  ];

  fn new( width: i32, height: i32 ) -> Board<'static> {
    let mut v: Vec<Vec<char>> = vec![];
    for _y in 0 .. height {
      v.push( vec![ Board::SPACE; width as usize ] );
    }
    if  width * height == 64 {
      let cx = (width  / 2) as usize;
      let cy = (height / 2) as usize;
      v[ cy - 1 ][ cx  - 1 ] = '@';    v[ cy - 1 ][ cx ] = '@';
      v[ cy     ][ cx  - 1 ] = '@';    v[ cy     ][ cx ] = '@';
    }

    let elems: Vec<Vec<&str>> =
      vec![ Board::ELEM[0].split(',').collect(),
            Board::ELEM[1].split(',').collect() ];
    Board{ width: width, height: height, cells: v, elems }
  }


  fn at( &self, x: i32, y: i32 ) -> char {
    if  x >= 0 && x < self.width  && y >= 0 && y < self.height {
      return self.cells[ y as usize ][ x as usize ];
    }
    return '?'
  }


  fn check( &self, xy: &Point, fig: &Fig ) -> bool {
    fig.iter().all( |pt| self.at( xy.x + pt.x, xy.y + pt.y) == Board::SPACE )
  }


  fn place( &mut self, xy: &Point, fig: &Fig, id:char ) {
    for pt in fig {
      self.cells[ (xy.y + pt.y) as usize ][ (xy.x + pt.x) as usize ] = id;
    }
  }


  fn find_space( &self, xy: &Point ) -> Point {
    let mut x = xy.x;
    let mut y = xy.y;
    loop {
      if self.at( x, y ) == Board::SPACE { break; }
      x = ( x + 1 ) % self.width;
      if x == 0 { y += 1; }
    }
    Point{ x, y }
  }


  fn render( &mut self) -> String {

    let mut ret: Vec<String> = vec![];
    for y in 0 .. self.height + 1 {
      for d in 0 .. 2 {
        let mut lines = String::new();
        for x in 0 .. self.width + 1  {
          let mut idx: usize = 0;
          if self.at( x,   y   ) != self.at( x,   y-1 ) { idx |= 1 }
          if self.at( x,   y-1 ) != self.at( x-1, y-1 ) { idx |= 2 }
          if self.at( x-1, y-1 ) != self.at( x-1, y   ) { idx |= 4 }
          if self.at( x-1, y   ) != self.at( x,   y   ) { idx |= 8 }

          lines.push_str( self.elems[d][ idx ] );
        }
        ret.push( lines );
      }
    }

    return ret.join( "\n" );
  }
} // impl Board

/////////////////////////////////////////////////////////////////

struct Solver<'a> {
  board:     Board<'a>,
  solutions: i32,

  pieces:    Vec<Box<Piece>>,
  next:      Vec<usize>,
  unused:    usize,
}

impl Solver<'_> {

  fn new( width: i32, height: i32 ) -> Solver<'static> {
    let board = Board::new( width, height );
    let next  = vec![ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 0 ];

    // Piece を heap に確保して保持する
    let mut pieces: Vec<Box<Piece>> = vec![];

    for id in "FLINPTUVWXYZ".chars() {
      let pc = Box::new( Piece::new( id, piece_def( id ) ) );
      pieces.push( pc );
    }
    // limit the symmetry of 'F'
    pieces[0].figs.resize( if width == height {1} else {2}, vec![] );
    pieces.insert( 0, Box::new( Piece::new( '!', vec![] ) ) );   // dumy piece
    Solver{ board, solutions: 0, pieces, next, unused: 0 }
  }


  fn solve( &mut self, xy_ :&Point ) {
    if self.next[ self.unused ] != 0 {

      let xy = self.board.find_space( &xy_ );
      let mut prev = self.unused;
      loop {
        let cur = self.next[ prev ];
        if cur == 0 { break; }
        self.next[ prev ] = self.next[ cur ];
        let pc: *const Piece = & *self.pieces[ cur ];
        for fig in unsafe{ &(*pc).figs } {
          if self.board.check( &xy, fig ) == true {
            self.board.place( &xy, fig, unsafe{ (*pc).id } );
            self.solve( &xy );
            self.board.place( &xy, fig, Board::SPACE );
          }
        }
        self.next[ prev ] = cur;
        prev = cur;
      }
    }
    else {
      self.solutions += 1;
      let curs_up = if self.solutions > 1 {
                      format!( "\x1b[{}A", self.board.height * 2 + 2 ) }
                    else {
                      String::from("")
                    };
      println!( "{}{}{}", curs_up, self.board.render(), self.solutions );
    }
  }

}  //impl Solver

/////////////////////////////////////////////////////////////////

fn main() {
  let mut width  =  6;
  let mut height = 10;

  let args: Vec<String> = env::args().collect();
   for arg in args {
     if arg == "--debug" {
       //println!( "{}", arg );
       unsafe { DEBUG_FLG = true; }
     }
     let sz: Result<Vec<i32>, _> = arg.split('x')
       .map(|s| s.trim().parse::<i32>())
       .collect();
     if let Ok(sz) = sz {
       if sz.len() == 2 && sz[0] >= 3 && sz[1] >= 3  &&
         (sz[0] * sz[1] == 60 || sz[0] * sz[1] == 64 ) {
         width = sz[0];
         height = sz[1];
       }
     }
   }

  let mut solver = Solver::new( width, height );
  solver.solve( &Point{x: 0, y: 0} );
}
