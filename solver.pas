// -*- coding:utf-8 -*-

//
// Pentomino Puzzle Solver with Pascal
//

program PentominoSolver;

{$mode objfpc}{$H+}

uses
  SysUtils, StrUtils, Math, Classes, fgl, RegExpr;

type
  TPoint = Record
    x, y: Integer;
  end;
  TFig = array of TPoint;
  TCharFigMap = specialize TFPGMap<char, TFig>;

const
  PIECE_DEF_DOC =
                  '+-------+-------+-------+-------+-------+-------+.' +
                  '|       |   I   |  L    |  N    |       |       |.' +
                  '|   F F |   I   |  L    |  N    |  P P  | T T T |.' +
                  '| F F   |   I   |  L    |  N N  |  P P  |   T   |.' +
                  '|   F   |   I   |  L L  |    N  |  P    |   T   |.' +
                  '|       |   I   |       |       |       |       |.' +
                  '+-------+-------+-------+-------+-------+-------+.' +
                  '|       | V     | W     |   X   |    Y  | Z Z   |.' +
                  '| U   U | V     | W W   | X X X |  Y Y  |   Z   |.' +
                  '| U U U | V V V |   W W |   X   |    Y  |   Z Z |.' +
                  '|       |       |       |       |    Y  |       |.' +
                  '+-------+-------+-------+-------+-------+-------+.';

var
  debug_flg: Boolean = false;


function FigEqual( const A, B: TFig ): Boolean;
var
  i: Integer;
begin
  for i := 0 to High( A ) do
     if not( (A[i].x = B[i].x) and (A[i].y = B[i].y) ) then Exit( false );
  result := true;
end;


function Fig2String( const fig: TFig ): String;
var
  i: Integer;
begin
  result := '[ ';
  for i := 0 to High( fig ) do
    result += format( '(%2d,%2d)%s',
                      [ fig[i].x, fig[i].y,
                        IfThen( i < High( fig ), ', ', '' )
                      ] );
  result += ' ]';
end;


procedure SortFig( var F: TFig );
var
  i, j: Integer;
  t: TPoint;
begin
  for i := 0 to High(F) do
    for j := i + 1 to High(F) do
      if (F[j].y < F[i].y) or ((F[j].y = F[i].y) and (F[j].x < F[i].x)) then
        begin
          t := F[i];
          F[i] := F[j];
          F[j] := t;
        end;
end;


function MakePieceDef: TCharFigMap;
var
  fig_def: TCharFigMap;
  x, y, i: Integer;
  c      : Char;
  s      : String;
  pts    : array of TPoint;
begin
  fig_def := TCharFigMap.Create;
  x := 0;
  y := 0;

  s := PIECE_DEF_DOC;
  for i := 1 to Length( s ) do
    begin
      c := s[i];
      if fig_def.IndexOf( c ) < 0 then
        begin
          SetLength( pts, 0 );
          fig_def.Add( c, pts );
        end;
      pts := fig_def[ c ];
      SetLength( pts, Length( pts ) + 1 );
      pts[ High( pts ) ].x := x Div 2;
      pts[ High( pts ) ].y := y;
      fig_def[ c ] := pts;

      if c = '.' then
        begin
          x := 0;
          Inc( y );
        end
      else
        Inc( x );
    end;

  result := fig_def;
end;

//Piece
type
  TPiece = Class
    figs: array of TFig;
    id: Char;
    next: TPiece;
    constructor Create( const id_: Char; const def_: TFig; next_: TPiece );
  end;


constructor TPiece.Create( const id_: Char; const def_: TFig; next_: TPiece );
var
  r_f, i, j, n, tmp: Integer;
  fig      : TFig;
  figs_str : String;
begin
  id := id_;
  next := next_;
  SetLength( figs, 0 );
  figs_str := '';
  for r_f := 0 to 7 do          // rotate and flip
    begin
      fig := Copy( def_, 0, Length( def_ ) );
      for i := 0 to High( fig ) do
        begin
          for n := 1 to ( r_f mod 4 ) do               // rotate
            begin
              tmp := fig[i].y;
              fig[i].y := fig[i].x;
              fig[i].x := -tmp;
            end;
          if r_f >= 4 then
            fig[i].x := - fig[i].x;                    // flip
        end;

      SortFig( fig );                                  // sort

      for j := High( fig ) downto 0 do                 // normalize
        begin
          fig[j].x := fig[j].x - fig[0].x;;
          fig[j].y := fig[j].y - fig[0].y;;
        end;

      if Pos( Fig2String( fig ), figs_str ) = 0 then   // uniq
        begin
          figs_str += Fig2String( fig );
          SetLength( figs, Length( figs ) + 1 );
          figs[ High( figs ) ] := fig;
        end;
    end;

  if debug_flg then
    begin
      WriteLn( format( '%s: (%d)', [ id, Length( figs ) ] ) );
      for i := 0 to High( figs ) do
        WriteLn( '    ', Fig2String( figs[i] ) );
    end;
end;

type
  TStr16Array = array[0..15] of String;


// Board
type
  TBoard = Class
    const
      SPACE = ' ';
      ELM0 = '    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---';
      ELM1 = '    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   ';

    Private
      cells: array of array of Char;
      ELEMS: array[0..1] of array of String;
      function  At( x, y: Integer ): Char;
    Public
      width, height: Integer;
      constructor Create( w, h: Integer );
      function  Check (const o: TPoint; const fig: TFig ): Boolean;
      procedure Place( const o: TPoint; const fig: TFig; id: Char );
      function  FindSpace( const xy: TPoint ): TPoint;
      function  Render: String;
  end;


constructor TBoard.Create( w, h: Integer );
var
  y, x   : Integer;
  hole   : TFig;
  center :  TPoint;
begin
  width  := w;
  height := h;
  SetLength( cells, h );
  for y := 0 to h - 1 do
    begin
      SetLength( cells[y], w );
      for x := 0 to w - 1 do
        cells[y][x] := SPACE;
    end;
  if (w * h = 64) then  // 8x8 or 4x16
    begin
      SetLength( hole, 4 );
      hole[0].x := 0;    hole[0].y := 0;
      hole[1].x := 0;    hole[1].y := 1;
      hole[2].x := 1;    hole[2].y := 0;
      hole[3].x := 1;    hole[3].y := 1;
      center.x := w Div 2 - 1;
      center.y := h Div 2 - 1;
      Place( center, hole, '@' );
    end;
  ELEMS[0] := SplitString( ELM0, ',' );
  ELEMS[1] := SplitString( ELM1, ',' );
end;


function TBoard.At( x, y: Integer ): Char;
begin
  if (x >= 0) and (x < width) and (y >= 0) and (y < height) then
    Exit( cells[y][x] )
  else
    Exit( '?' );
end;


function TBoard.Check( const o: TPoint; const fig: TFig ): Boolean;
var
    i: Integer;
begin
  for i := 0 to High( fig ) do
    begin
      if At( o.x + fig[i].x, o.y + fig[i].y ) <> SPACE then Exit( false );
    end;
  result := true;
end;


procedure TBoard.Place( const o: TPoint; const fig: TFig; id: Char );
var
  i: Integer;
begin
  for i := 0 to High( fig ) do
    cells[o.y + fig[i].y][o.x + fig[i].x] := id;
end;


function TBoard.FindSpace( const xy: TPoint ): TPoint;
var
  x, y: Integer;
begin
  x := xy.x;
  y := xy.y;
  While cells[y][x] <> SPACE do
    begin
      Inc( x );
      if x = width then
        begin
           x := 0;
           Inc( y );
        end;
     end;
  result.x := x;
  result.y := y;
end;


function TBoard.Render: String;
var
  y, d, x, code: Integer;
begin
  result := '';
  for y := 0 to height do
    begin
      for d := 0 to 1 do
        begin
          for x := 0 to width do
            begin
               code := 0;
               if At( x+0, y+0 ) <> At( x+0, y-1 ) then code += 1;
               if At( x+0, y-1 ) <> At( x-1, y-1 ) then code += 2;
               if At( x-1, y-1 ) <> At( x-1, y+0 ) then code += 4;
               if At( x-1, y+0 ) <> At( x+0, y+0 ) then code += 8;
               result += ELEMS[d][code];
            end;
          if ( y < height ) or ( d < 1 ) then  result += #10;
        end;
    end;
end;


// Solver
type
  TSolver = Class
    Private
      solutions: Integer;
      board: TBoard;
      Unused: TPiece;

    Public
      constructor Create( width, height: Integer );
      destructor Destroy;  override;
      procedure Solve( const xy_: TPoint );
  end;


constructor TSolver.Create( width, height: Integer );
const
  ids = 'FLINPTUVWXYZ';
var
  pieceDef : TCharFigMap;
  i        : Integer;
  pc       : TPiece;
begin
  solutions := 0;
  pieceDef  := MakePieceDef;
  board     := TBoard.Create( width, height );
  pc        := Nil;

  for i := Length( ids ) downto 1 do
      pc := TPiece.Create( ids[i], pieceDef[ ids[i] ], pc ) ;
  // a dummy piece
  Unused := TPiece.Create( '!', Nil, pc );   // pc.id = 'F'

  // limit the symmetry of 'F'
  SetLength( pc.figs, IfThen( width = height, 1, 2 ) );

  pieceDef.Free;
end;


destructor TSolver.Destroy;
var
  p, q: TPiece;
begin
  board.Free;
  p := Unused;
  While p <> Nil do
    begin
      q := p.next;
      p.Free;
      p := q;
    end;
  inherited Destroy;
end;


procedure TSolver.Solve( const xy_: TPoint );
var
  xy       : TPoint;
  prev, pc : TPiece;
  fig      : TFig;
  i        : Integer;
  curs_up  : String;
begin
  if Unused.next <> Nil then
    begin
      xy   := board.FindSpace( xy_ );
      prev := Unused;
      While prev.next <> Nil do
        begin
          pc := prev.next;
          prev.next := pc.next;
          for i := 0 to High( pc.figs ) do
            begin
              fig := pc.figs[i];
              if board.Check( xy, fig ) then
                begin
                  board.Place( xy, fig, pc.id );
                  Solve( xy );
                  board.Place( xy, fig, TBoard.SPACE );
                end;
            end;
          pc.next   := prev.next;
          prev.next := pc;
          prev      := pc;
        end;
    end
  else
    begin
      Inc( solutions );
      curs_up := IfThen( solutions > 1,
                         format( #27'[%dA', [board.height * 2 + 2] ), '' );
      Writeln( curs_up, board.Render, solutions );
    end;
 end;


// ---------- M A I N ----------
var
  width, height, w, h, i : Integer;
  solver: TSolver;
  start : TPoint;
  rege  : TRegExpr;
begin
  width := 6;
  height := 10;

  rege := TRegExpr.Create;
  rege.expression := '^\s*(\d+)[^\d](\d+)\s*$';

  for i := 1 to ParamCount do
    begin
      if ( ParamStr(i) = '--debug' ) or ( ParamStr(i) = '-d' ) then
        debug_flg := true;
      if rege.Exec( ParamStr(i) ) then
        begin
          w := StrToInt( rege.Match[1] );
          h := StrToInt( rege.Match[2] );
          if (w >= 3) and (h >= 3) and ((w * h = 60) or (w * h = 64)) then
            begin
              width  := w;
              height := h;
            end;
        end;
    end;
  rege.Free;

  start.x := 0;
  start.y := 0;

  solver := TSolver.Create( width, height );
  solver.Solve( start );

  solver.Free;
end.
