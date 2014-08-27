(* There are two operations:

   * shifting the board in some direction, which always succeeds (although
     it's sometimes the identity)

   * populating an empty square, which may fail *)

(* Types.  We take squares rather than tiles as fundamental -- i.e. a
   square contains a tile; a tile does not have coordinates. *)

(* Squares *)

type provenance = { shift : int; value : int }

type tile = int * provenance list

type square = tile option 

let empty = None
let t2 = Some (2, [])
and t4 = Some (4, [])
and t8 = Some (8, [])
and t16 = Some (16, [])
and t32 = Some (32, [])
and t64 = Some (64, [])
and t128 = Some (128, [])
and t256 = Some (256, [])
and t512 = Some (512, [])
and t1024 = Some (1024, [])
and t2048 = Some (2048, [])

(* Replace the provenance of a square with the no-move provenance. *)
let clear_provenance t =
  match t with
  | None -> None
  | Some (t, _) -> Some (t, [{ shift = 0; value = t}] )

(* Update the provenance of a square after a shift. *)
let shift_square t =
  match t with
  | None -> None
  | Some (t, []) -> Some(t, [{ shift = 1; value = t }])
  | Some (t, m :: _) -> Some (t, [{ m with shift = m.shift + 1 }])

let square_value t =
  match t with
  | None -> None
  | Some (v, _) -> Some v

let square_provenance t =
  match t with
  | None -> []
  | Some (_, p) -> p

let string_of_square = function
| Some (s, _) -> string_of_int s
| None -> " "

let is_new_tile t =
  match t with
  | None -> false
  | Some (_, []) -> true
  | Some (_, _) -> false

let is_square_2048 t =
  match t with
  | Some (2048, _) -> true
  | _ -> false  

(* Board *)

type row = square list
type board = row list

let create_board () =
  [ [t2; empty; empty; empty];
    [empty; empty; empty; empty];
    [empty; empty; empty; empty];
    [empty; empty; empty; t2]; ]

(* On to the insertion.  First, some functions for determining whether the
   board is full.  *)

let is_row_full r =
  let is_some = function
  | None -> false
  | Some _ -> true
  in
  List.for_all is_some r

let rec is_moveable_row r =
  (* A row is moveable if it contains empty squares, or if adjacent
     tiles have the same value *)
  match r with
      [] -> false
    | None :: _ -> true
    | Some (x, _) :: Some (y, _) :: _ when x = y -> true
    | Some _ :: rest -> is_moveable_row rest

let is_board_full b = List.for_all is_row_full b

let is_board_winning = List.exists (List.exists is_square_2048)

(* optionally replace a single item in a list *)
let rec replace_one p l = match l with
| [] -> None
| x :: xs ->
    begin match p x with
    | Some y -> Some (y :: xs)
    | None ->
        begin match replace_one p xs with
        | None -> None
        | Some ys -> Some (x :: ys)
        end
    end

(* Populate the first empty spot in a row. *)
let insert_into_row (sq : square) (l : row) : row option =
  replace_one (function None -> Some sq | Some _ -> None) l

(* Populate the first empty spot on a board. *)
let insert_square sq : board -> board option =
  replace_one (insert_into_row sq)

let board_size board = match board with
| [] -> (0, 0)
| r :: _  -> List.length r, List.length board

let fold_board f acc board =
  let col y (x, acc) square = x + 1, (f acc (x, y) square) in
  let row (y, acc) row = y + 1, snd (List.fold_left (col y) (0, acc) row) in
  snd (List.fold_left row (0, acc) (List.rev board))

(* Moves *)

type move = L | R | U | D

(* Let's start with the shifts. *)

(* [shift_left] is the central function, and defines the change in a single
   row under a left shift.  The other three shifts can be defined in terms of
   [shift_left] (see [shift]); [shift_left_helper] is an auxiliary function
   that accumulates empty squares. *)
let rec shift_left_helper : row -> row -> row =
  (* invariant: length list + length accum = length rhs.
     Alternatively: everything on the left must appear on the right,
     including accum.
  *)
  fun list empties -> match list with
  | [] ->
     empties
  | None :: rest ->
     shift_left_helper (List.map shift_square rest) (None :: empties)
  | Some (x, xprov) :: Some (y, {shift; value} :: _) :: rest when x = y ->
     Some (x + y, xprov @ [{shift = shift + 1; value}]) :: shift_left_helper (List.map shift_square rest) (None :: empties)
  | Some x :: None :: rest ->
     shift_left_helper (Some x :: List.map shift_square rest) (None :: empties)
  | Some (x, prov) :: r ->
     Some (x, prov) :: shift_left_helper r empties

(* [shift_left] starts with an empty accumulator *)
let shift_left l = shift_left_helper (List.map clear_provenance l) []
let shift_right l = List.rev (shift_left (List.rev l))

(* This is partial.  There's also an implementation in Jane Street's Core. *)
let rec transpose = function
  | [] -> []
  | [] :: _ -> []
  | x -> List.(map hd x :: transpose (map tl x))

let rec shift_board : move -> board -> board = fun move board ->
  match move with
  | L -> List.map shift_left board
  | R -> List.map shift_right board
  | U -> transpose (shift_board L (transpose board))
  | D -> transpose (shift_board R (transpose board))

let game_move move board =
  let board' = shift_board move board in
  match insert_square t2 board' with
  | None -> board'
  | Some board'' -> board''

let square_score t =
  match t with
  | None -> 0
  | Some (t, m1 :: m2 :: _) -> m1.value + m2.value
  | Some (t, _) -> 0

let sum = List.fold_left (+) 0

let move_row_score row =
 sum (List.map square_score row)

let last_move_score board =
 sum (List.map move_row_score board)

let is_game_over b =
   not (List.exists is_moveable_row b || List.exists is_moveable_row (transpose b))