// -*- coding:utf-8 -*-

//
// Pentomino Puzzle Solver with F#
//

open System
open System.Collections.Generic
type Fig = (int * int) list

let mutable debugFlag = false

let pieceDef =
    let pieceDOC = [
        "+-------+-------+-------+-------+-------+-------+"
        "|       |   I   |  L    |  N    |       |       |"
        "|   F F |   I   |  L    |  N    |  P P  | T T T |"
        "| F F   |   I   |  L    |  N N  |  P P  |   T   |"
        "|   F   |   I   |  L L  |    N  |  P    |   T   |"
        "|       |   I   |       |       |       |       |"
        "+-------+-------+-------+-------+-------+-------+"
        "|       | V     | W     |   X   |    Y  | Z Z   |"
        "| U   U | V     | W W   | X X X |  Y Y  |   Z   |"
        "| U U U | V V V |   W W |   X   |    Y  |   Z Z |"
        "|       |       |       |       |    Y  |       |"
        "+-------+-------+-------+-------+-------+-------+"
    ]
    let dic = Dictionary<char, Fig>()
    for y, line in pieceDOC |> List.indexed do
        for x, c in line |> Seq.indexed do
            dic[c] <- (x / 2, y) :: if dic.ContainsKey c then dic[c] else []
    dic

//////////////////////////////////////////////////////////////////

type Piece(id: char, figDef: Fig, next: Piece option) =
    member val Id = id
    member val Next = next with get, set

    member val Figs =
        [0..7]
        |> List.map (fun r_f ->                       // rotate and flip
            figDef
            |> List.map (fun xy ->
                let x, y = [1..(r_f % 4)]                         // rotate
                           |> List.fold (fun (x, y) _ -> (-y, x)) xy
                if r_f < 4 then (x, y) else (-x, y) )             // flip
            |> List.sortBy (fun (x, y) -> y, x)                   // sort
            |> (fun fig ->
                    let x0, y0 = fig[0]                           // normalize
                    fig |> List.map (fun (x, y) -> (x - x0, y - y0)))
        )
        |> List.distinct                                          // uniq
        |> (fun figs -> if debugFlag then
                            printfn "%c: (%d)" id figs.Length
                            figs |> List.iter (printfn "    %A")
                        figs)
        with get, set

//////////////////////////////////////////////////////////////////


type Board(width: int, height: int) as self =
    let cells = Array.init height (fun _ -> Array.create width ' ' )

    static let rec transpose = function
        | (_::_)::_ as M ->
             List.map List.head M :: transpose (List.map List.tail M)
        | _ -> []

    static let ELEMS =
        [ "    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---";
          "    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   "
        ]
        |> List.map (fun s -> s.Split ',' |> Array.toList )
        |> transpose

    do
        if width * height = 64 then
            self.Place (width/2-1) (height/2-1) [(0,0);(0,1);(1,0);(1,1)] '@'


    member this.W  = width
    member this.H  = height


    member this.At x y =
        if x >= 0 && x < this.W && y >= 0 && y < this.H
            then cells[y][x]  else  '?'


    member this.Place x y fig id =
        fig |> List.iter (fun (dx, dy) -> cells[y + dy][x + dx] <- id )


    member this.Check x y fig =
        fig |> List.forall (fun (dx, dy) -> this.At (x + dx) (y + dy) = ' ')


    member this.FindSpace x_  y_ =
        let mutable (x, y) = (x_, y_)
        while this.At x y <> ' ' do
            x <- x + 1
            if x = this.W then x <- 0;  y <- y + 1
        (x, y)


    member bd.Render() =
       [0..bd.H] |> List.map (fun y ->
         [0..bd.W] |> List.map (fun x ->
           ELEMS[ (if bd.At (x+0) (y+0) <> bd.At (x+0) (y-1) then 1 else 0)+
                  (if bd.At (x+0) (y-1) <> bd.At (x-1) (y-1) then 2 else 0)+
                  (if bd.At (x-1) (y-1) <> bd.At (x-1) (y+0) then 4 else 0)+
                  (if bd.At (x-1) (y+0) <> bd.At (x+0) (y+0) then 8 else 0) ]
         )
         |> transpose |> List.map (fun e -> e |> String.concat "")
       )
       |> List.concat |> String.concat "\n"


//////////////////////////////////////////////////////////////////

type Solver(width: int, height: int) =
    let mutable solutions = 0
    let mutable unused    = None : Piece option
    let board             = Board(width, height)

    do
        let mutable pc = None
        "FLINPTUVWXYZ".ToCharArray() |> Array.rev |> Array.iter (fun id ->
            pc <- Some( Piece(id, pieceDef.[id], pc) )
        )
        unused <- Some( Piece('!', [(0,0)], pc) )    // pc.Id = 'F'
        // limit the symmetry of 'F'
        pc.Value.Figs <-
            pc.Value.Figs |> List.take (if width = height then 1 else 2)

    member this.Solve x y =
        let mutable prev = unused.Value
        if prev.Next.IsSome then
            let x, y = board.FindSpace x y
            while prev.Next.IsSome do
                let mutable pc = prev.Next.Value
                prev.Next <- pc.Next
                pc.Figs |> List.iter (fun fig ->
                    if board.Check x y fig then
                        board.Place x y fig pc.Id
                        this.Solve x y
                        board.Place x y fig ' '
                )
                prev.Next <- Some pc
                prev      <- pc
         else
             solutions <- solutions + 1
             let curs_up =
                 if solutions > 1 then $"\u001b[%d{board.H*2+2}A" else ""
             printfn "%s%s%d" curs_up (board.Render()) solutions

//////////////////////////////////////////////////////////////////


let mutable size = (6, 10)
for arg in Environment.GetCommandLineArgs() do
    if arg = "--debug" then debugFlag <- true
    let check w h = w >= 3 && h >= 3 && (w * h = 60 || w * h = 64)
    match arg.Split 'x' |> Array.map (fun s -> System.Int32.TryParse s) with
    | [| (true, w); (true, h) |] when check w h -> size <- (w, h)
    | [| (true, w); (true, h) |]  -> printfn "Wrong size: %s" arg
    | _ -> ()

let solver = Solver( size )
solver.Solve 0 0
