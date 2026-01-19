(* -*- coding:utf-8 -*- *)

(*
 *  Pentomino Puzzle Solver with OCaml
 *)

open Printf

let piece_doc = {|
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
|}

(* def by command line arg *)
type config = {
  w : int;
  h : int;
  dbg_flag : bool;
}


let map_join delim f lst =
  String.concat delim ( List.map( f ) lst )

(*
 * Pieces
 *)

let rotate_and_flip fig =
  let rotate fig = fig |> List.map (fun (x,y) -> (-y, x))
  and flip   fig = fig |> List.map (fun (x,y) -> (-x, y))
  and normalize pts =
    let sorted  = pts|> List.sort (fun (x,y) (u,v) -> compare (y,x) (v,u)) in
    let (ox,oy) = sorted |> List.hd in
    sorted |> List.map (fun (x,y) -> (x-ox, y-oy))
  in
  let rec rotations fig n acc =
    if n = 0 then acc else rotations (rotate fig) (n-1) (fig :: acc)
  in
  rotations fig 4 [] @ rotations (flip fig) 4 []
  |> List.map ( fun fig -> fig |> normalize )
  |> List.sort_uniq compare


let parse_pieces () : (char, (int * int) list list ) Hashtbl.t =
  let org_fig = Hashtbl.create 12  in
  String.split_on_char '\n' piece_doc
  |> List.iteri (fun y line ->
         line |> String.to_seq |> List.of_seq
         |> List.iteri (fun x c ->
                let xy = (x/2, y) in
                if c >= 'A' && c <= 'Z' then
                  if Hashtbl.mem org_fig c then
                    Hashtbl.replace org_fig c (xy :: (Hashtbl.find org_fig c))
                  else
                    Hashtbl.add org_fig c [xy]
              )
       );
  let pieces  = Hashtbl.create 12  in
  org_fig |> Hashtbl.iter (fun id fig ->
      Hashtbl.add pieces id ( fig |> rotate_and_flip )
  );
  pieces

(*
 * Board
 *)
type board = {
  w : int;
  h : int;
  cells : char array;
}

let init_board (cfg : config) =
  let (w,h) = (cfg.w, cfg.h) in
  let cells = Array.make (w * h) ' ' in
  if w * h = 64 then begin
      let w2 = w / 2 and h2 = h / 2 in
      for y = h2 - 1 to h2 do
        for x = w2 - 1 to w2 do
          cells.(y * w + x) <- '@'
        done
      done
    end;
  { w; h; cells }


let at bd x y =
  if x >= 0 && x < bd.w && y >= 0 && y < bd.h
  then bd.cells.( y * bd.w + x)
  else '?'


let check bd ox oy fig =
  fig |> List.for_all (fun (x,y) -> at bd (ox + x) (oy + y) = ' ')


let place bd ox oy fig id =
  let cells = Array.copy bd.cells in
  fig |> List.iter (fun (x,y) -> cells.( (oy + y) * bd.w + (ox + x) ) <- id  );
  { bd with cells }


let rec find_space bd idx = 
  if bd.cells.( idx ) = ' ' then idx else find_space bd (idx + 1)


let elems = [
  String.split_on_char ',' "    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---";
  String.split_on_char ',' "    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   ";
]

let render bd =
  List.init( bd.h + 1 ) (fun y ->
      let codes = List.init ( bd.w + 1 ) (fun x ->
            (if at bd (x-0) (y-0) <> at bd (x-0) (y-1) then 1 else 0) +
            (if at bd (x-0) (y-1) <> at bd (x-1) (y-1) then 2 else 0) +
            (if at bd (x-1) (y-1) <> at bd (x-1) (y-0) then 4 else 0) +
            (if at bd (x-1) (y-0) <> at bd (x-0) (y-0) then 8 else 0)
            )
      in
      elems |> map_join "\n" (fun elem ->
                   codes |> map_join "" (List.nth elem)
                 )
    )
  |> String.concat "\n"


(*
 * Solver
 *)
let solutions = ref 0

let rec solve bd idx pieces ids =
  if List.length ids = 0 then begin
      incr solutions;
      let curs_up =
        if !solutions > 1 then sprintf "\x1b[%dA" (2 * bd.h + 2) else ""
      in
      printf "%s%s%d\n" curs_up (render bd) !solutions;
      flush stdout
    end
  else
    let idx = find_space bd idx in
    let x   = idx mod bd.w  and  y = idx / bd.w in
    ids
    |> List.iter (fun id ->
           Hashtbl.find pieces id
           |> List.iter (fun fig ->
                  if check bd x y fig then begin
                      let bd   = place bd x y fig id
                      and rest = List.filter (fun id' -> id' <> id) ids in
                      solve bd idx pieces rest
                    end
                )
         )

(*
 * Parse Arg
 *)
let parse_args () : config =
  let args     = Array.to_list Sys.argv |> List.tl in
  let dbg_flag = args |> List.exists ((=) "--debug")
  and size_arg = args |> List.find_opt (fun s -> String.contains s 'x')
  and default  = (6, 10) in

  let w, h =
    match size_arg with
    | Some s ->
        begin match String.split_on_char 'x' s with
        | [ws; hs] ->
            let w = int_of_string_opt ws
            and h = int_of_string_opt hs in
            begin match w, h with
            | Some w, Some h when w * h = 60 || w * h = 64 ->
                (w, h)
            | _ -> default
            end
        | _ -> default
        end
    | None -> default
  in
  { w; h; dbg_flag }

(*
 * main
 *)
let () =
  let cfg    = parse_args () in
  let bd     = init_board cfg in
  let pieces = parse_pieces () in
  let take n lst = List.init n (List.nth lst) (* for Ver 4.x *) in

  (* limit symetries of 'F' *)
  Hashtbl.replace pieces 'F'
    ( (Hashtbl.find pieces 'F') |> take (if cfg.w = cfg.h then 1 else 2) );

  if cfg.dbg_flag then begin
      let to_s fig =
        fig |> map_join ", " (fun (x,y) -> sprintf "(%d,%d)" x y )
      in
      Hashtbl.iter (fun id figs ->
          printf "%c: (%d)\n" id ( figs |> List.length );
          List.iter(fun fig -> printf "    [%s]\n" ( fig |> to_s ) ) figs
        ) pieces
    end;
  solve bd 0 pieces ( "FILNPTUVWXYZ" |> String.to_seq |> List.of_seq )
