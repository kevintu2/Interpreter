
type stackVal = 
  | I of int 
  | S of string 
  | N of string
  | B of bool 
  | U
  | E
  | Closure of string * (command list) * env
  | InOutClosure of string * (command list) * env

and command = PushI of stackVal 
             | PushS of stackVal 
             | PushN of stackVal 
             | PushB of stackVal
             | Push of stackVal
             | Add | Sub | Mul | Div | Rem | Neg
             | Concat
             | And | Or | Not
             | Equal | LessThan
             | If
             | Pop
             | Swap
             | Block of command list (* handle blocks together *)
             | Createfun of (string * string * (command list))
             | InOutFun of (string * string * (command list))
             | Return
             | Bind
             | Call
             | Quit


and env = (string * stackVal) list
let insert (s:string) (sv : stackVal) (env: env) : env = (s,sv)::env

let rec fetch (name :string)  (env: (string * stackVal) list) : stackVal option = 
    match env with
      | (name' , v) :: rest -> if name = name' then Some v else fetch name rest
      | []                  -> None
      
let empEnv = []


let rec run (commands : command list) (stack: stackVal list) (env: env) : (stackVal list * env) = 
  
  let res (sv : stackVal) : stackVal = 
    match sv with 
      | N n -> (match fetch n env with  
                  | Some n' -> n' 
                  | None    -> N n)
      | sv -> sv
  in let bad rest : stackVal list * env = run rest (E :: stack) env 
  in match (commands , stack)  with
  | (Quit        :: _   , _         ) -> (stack,env)
  | ([]                 , _         ) -> (stack,env) 
  
  | (PushI (I i) :: rest, _         ) -> run rest (I i :: stack) env
  
  | (PushS (S s) :: rest, _         ) -> run rest (S s :: stack) env
  
  | (PushN (N n) :: rest, _         ) -> run rest (N n :: stack) env
  
  | (PushB (B b) :: rest, _         ) -> run rest (B b :: stack) env
  
  | (Push U      :: rest, _         ) -> run rest (U :: stack) env
  | (Push E      :: rest, _         ) -> run rest (E :: stack) env
  
  | (Add         :: rest, x ::y ::s') -> (match (res x, res y) with 
                                          | (I i, I j) -> run rest (I (i+j) :: s') env 
                                          | _ -> bad rest)
  
  | (Sub         :: rest, x ::y ::s') -> (match (res x, res y) with 
                                          | (I i, I j) -> run rest (I (i-j) :: s') env 
                                          | _ -> bad rest)
  
  | (Mul         :: rest, x ::y ::s') -> (match (res x, res y) with 
                                          | (I i, I j) -> run rest (I (i*j) :: s') env 
                                          | _ -> bad rest)
  
  | (Div         :: rest, x ::y ::s') -> (match (res x, res y) with 
                                          | (I i, I 0) -> bad rest
                                          | (I i, I j) -> run rest (I (i/j) :: s') env 
                                          | _ -> bad rest)
  
  | (Rem         :: rest, x ::y ::s') -> (match (res x, res y) with 
                                          | (I i, I 0) -> bad rest
                                          | (I i, I j) -> run rest (I (i mod j) :: s') env 
                                          | _ -> bad rest)
  
  | (Neg         :: rest, x :: s'   ) -> (match (res x) with 
                                          | (I i) -> run rest (I (-i) :: s') env 
                                          | _ -> bad rest)

  | (Concat      :: rest, x ::y ::s') -> (match (res x, res y) with 
                                          | (S i, S j) -> run rest (S (i ^ j) :: s') env 
                                          | _ -> bad rest)
  
  | (And         :: rest, x ::y ::s') -> (match (res x, res y) with 
                                          | (B i, B j) -> run rest (B (i && j) :: s') env 
                                          | _ -> bad rest)
  
  | (Or          :: rest, x ::y ::s') -> (match (res x, res y) with 
                                          | (B i, B j) -> run rest (B (i || j) :: s') env 
                                          | _ -> bad rest)
  
  | (Not         :: rest, x :: s'   ) -> (match (res x) with 
                                          | (B i) -> run rest (B (not i) :: s') env 
                                          | _ -> bad rest)
  
  | (Equal       :: rest, x ::y ::s') -> (match (res x, res y) with 
                                          | (I i, I j) -> run rest (B (i = j) :: s') env 
                                          | _ -> bad rest)

  | (LessThan    :: rest, x ::y ::s') -> (match (res x, res y) with 
                                          | (I i, I j) -> run rest (B (i < j) :: s') env 
                                          | _ -> bad rest)
                                             
  | (If          :: rest,x::y::z::s') -> (match res z with 
                                          | B true  -> run rest (y :: s') env 
                                          | B false -> run rest (x :: s') env 
                                          | _ -> bad rest)
  
  | (Pop         :: rest, _ :: s'   ) -> run rest s' env
  
  | (Swap        :: rest, x ::y ::s') -> run rest (y::x::s') env
  
  
  | (Bind        :: rest, N n::x::s') -> (match res x with
                                          | E   -> bad rest
                                          | N _ -> bad rest 
                                          | sv  -> run rest (U :: s') (insert n sv env)) 
  
  | (Block ls    :: rest, s'        ) -> let (top :: _, _) = run ls [] env 
                                         in  run rest (top :: s') env

  | (Call        :: rest, parameter :: name :: s') -> (match ((res parameter),(res name)) with
                                                      | (N _, _) -> bad rest
                                                      | (E, _) -> bad rest
                                                      | (sv, Closure (param ,cl,funcenv)) -> (match run cl [] (insert param sv funcenv) with
                                                                                    | (x :: _,_) -> run rest (x::s') env 
                                                                                    | (_ , _) -> bad rest)
                                                      | (sv, InOutClosure (param ,cl,funcenv)) -> (match run cl stack (insert param sv funcenv) with
                                                                                      | (x :: _, funcenv) -> (match (parameter, fetch param funcenv) with
                                                                                                                | (N n, Some value) -> run rest (s') (insert n value env)
                                                                                                                | _ -> bad rest
                                                                                      )
                                                                                      | ([], funcenv) -> bad rest                  
                                                      ) 
                                                      | (sv, _) -> bad rest
  )

  | (Createfun (n, parameter, closure)  :: rest, s') -> let cl = Closure (parameter, closure, env) in run rest (U :: s') (insert n cl env)

  | (InOutFun (n, parameter, closure) :: rest, s') -> let cl = InOutClosure (parameter, closure, env) in run rest (U :: s') (insert n cl env)
  
  | (Return      :: rest, x:: _   ) -> ((res x) :: [],env)

  | (_           :: rest, _         ) -> bad rest


  
  
  

let e2 = run [PushI (I 1); PushI (I 1); Add] [] empEnv
let e3 = run [PushN (N "x"); PushI (I 1); Add] [] (insert "x" (I 7) empEnv)
let e4 = run [PushN (N "x"); PushI (I 1); Add] [] empEnv
let e5 = run [PushI (I 500); PushI (I 2); Mul; PushI (I 2);  Div] [] empEnv
let e6 = run [PushS (S "world!"); PushS (S "hello "); Concat] [] empEnv
let e7 = run [PushI (I 7); PushI (I 8); LessThan] [] empEnv
let e8 = run [PushI (I 7); PushI (I 7); Equal] [] empEnv
let e9 = run [PushI (I 13); PushN (N "a"); Bind; PushI (I 3); PushN (N "name1"); Bind;  PushN (N "a"); PushN (N "name1"); Add] [] empEnv
let e10 = run [PushB (B true); PushS (S "o"); PushS (S "j"); If] [] empEnv
(* ... *)



let to_string (s : stackVal) : string = 
  match s with
  | I i -> string_of_int i 
  | S s  -> s
  | N n -> n
  | B b -> "<" ^ string_of_bool b ^ ">"
  | U   -> "<unit>"
  | E   -> "<error>"
  



let explode (s:string) : char list =
  let rec expl i l =
    if i < 0 
    then l 
    else expl (i - 1) (String.get s i :: l)
  in expl (String.length s - 1) []

let implode (cl:char list) : string = 
  String.concat "" (List.map (String.make 1) cl)

 
let is_alpha (c:char): bool = 
  (Char.code 'a' <= Char.code c && Char.code c <= Char.code 'z')
  || (Char.code 'A' <= Char.code c && Char.code c <= Char.code 'Z')

let is_digit (c:char): bool = 
 Char.code '0' <= Char.code c && Char.code c <= Char.code '9'


let is_funname (c:char): bool =
  (Char.code 'a' <= Char.code c && Char.code c <= Char.code 'z')
  || (Char.code 'A' <= Char.code c && Char.code c <= Char.code 'Z') || (Char.code '0' <= Char.code c && Char.code c <= Char.code '9')  || (c == '_')

let rec take_while' (p: 'a -> bool) (es : 'a list) : ('a list) * ('a list) = 
  match es with
  | []      -> ([],[])
  | x :: xs -> if p x then let (chars, rest) = take_while' p xs in  (x :: chars, rest) else ([], x :: xs)

let take_while (p:char -> bool) (s:string) : string * string = 
  let (echars, erest) = take_while' p (explode s) 
  in (implode echars, implode erest)


let parse_int (s : string) : int option = 
    match int_of_string s with    
    | n -> Some n
    | exception _ -> None

let parse_string (s : string) : string option = 
    if String.length s > 1 && String.get s 0 = '"' && String.get s (String.length s - 1) = '"'
    then  Some (String.sub s 1 (String.length s - 2)) 
    else None


let parse_name (s : string) : string option = 
    if String.length s > 0 && ( let c = (String.get s 0) in is_alpha c ||  c = '_')
    then  Some s 
    else None
    
    
    
let parse_constant (s:string) : stackVal = 
    let s' = String.trim s in
    match s' with
    | "<true>"  -> B true
    | "<false>" -> B false
    | "<unit>"  -> U
    | _ -> match parse_int s' with
           | Some i -> I i
           | None -> match parse_string s' with
                     | Some s -> S s
                     | None -> match parse_name s' with
                               | Some s -> N s
                               | None -> E



let parse_single_command (s:string) : command = 
    match take_while is_alpha (String.trim s) with
    | ("PushI"   , p) -> PushI (parse_constant p)
    | ("PushS"   , p) -> PushS (parse_constant p)
    | ("PushN"   , p) -> PushN (parse_constant p)
    | ("PushB"   , p) -> PushB (parse_constant p)
    | ("Push"    , p) -> Push (parse_constant p)
    | ("Add"     , _) -> Add
    | ("Sub"     , _) -> Sub
    | ("Mul"     , _) -> Mul
    | ("Div"     , _) -> Div
    | ("Rem"     , _) -> Rem
    | ("Neg"     , _) -> Neg
    | ("Pop"     , _) -> Pop
    | ("Swap"    , _) -> Swap
    | ("Concat"  , _) -> Concat
    | ("And"     , _) -> And
    | ("Or"      , _) -> Or
    | ("Not"     , _) -> Not
    | ("LessThan", _) -> LessThan
    | ("Equal"   , _) -> Equal
    | ("If"      , _) -> If
    | ("Bind"    , _) -> Bind
    | ("Call"    , _) -> Call
    | ("Return"  , _) -> Return
    | ("Quit"    , _) -> Quit
    


let rec parse_until_end (ls :string list) :  (command list) * (string list)  =  
    match ls with 
    | []              -> ([], [])
    
    | "End" ::     tl ->  ([], tl)
    | "Begin" ::     tl ->  let (cls, rest) = parse_until_end tl
                            in let block = Block cls
                            in let (cls', rest') = parse_until_end rest
                            in (block :: cls', rest')
    | "FunEnd" :: tl -> ([],tl)
    
    | h ::     tl         -> match take_while is_funname (String.trim h) with
                              | ("Fun", parameter) -> let (name, param) = take_while is_funname (String.trim parameter) in 
                                let (cls, rest) = parse_until_end tl in
                                let cfun = Createfun (String.trim name, String.trim param, cls) in
                                let (cls',rest') = parse_until_end rest in (cfun :: cls', rest')
                              | ("InOutFun", parameter) -> let (name, param) = take_while is_funname (String.trim parameter) in 
                                let (cls, rest) = parse_until_end tl in
                                let cfun = InOutFun (String.trim name, String.trim param, cls) in
                                let (cls',rest') = parse_until_end rest in (cfun :: cls', rest')

                              | _ ->
                                let com = parse_single_command h
                                in let (cls, rest) = parse_until_end tl
                                in (com :: cls, rest)

let pe0 = parse_until_end ["Fun test000"; "Call"]  
let pe1 = parse_until_end ["Pop";"Pop";"Pop";"Pop"]
let pe2 = parse_until_end ["Pop";"Pop";"End";"Pop";"Pop"]
let pe3 = parse_until_end ["Begin";"Pop";"End";"Pop"]
let pe4 = parse_until_end ["Begin";"Pop";"End";"Begin";"Begin";"Pop";"End";"Pop";"End";"Pop"]

(* walk through a recursion *)
let pe51 = parse_until_end ["Neg";"Neg";"End";"Pop";"Pop"] (* ([Neg, Neg] , ["Pop";"Pop"]) *)
let pe52 = parse_until_end [      "Neg";"End";"Pop";"Pop"] (* ([     Neg] , ["Pop";"Pop"]) *)
let pe53 = parse_until_end [            "End";"Pop";"Pop"] (* ([        ] , ["Pop";"Pop"]) *)


let pe6 = parse_until_end ["PushB <true>";"Neg";"PushI 10";"Sub";"Quit"] (* ([PushB (B true); Neg; ...],[]) *)
let pe7 = parse_until_end ["Neg";"Pop"] (* ([Neg, Pop],[]) *)
let pe8 = parse_until_end ["Pop";"Neg";"Pop"] (* ([Pop,Neg, Pop],[]) *)

(* walk through a recursion *)
let pe91 = parse_until_end ["Pop";"Neg";"Pop";"End";"Sub";"Quit"] (* ([Pop,Neg, Pop],["Sub";"Quit"]) *)
let pe92 = parse_until_end [      "Neg";"Pop";"End";"Sub";"Quit"] (* ([    Neg, Pop],["Sub";"Quit"]) *)
let pe93 = parse_until_end [            "Pop";"End";"Sub";"Quit"] (* ([         Pop],["Sub";"Quit"]) *)
let pe94 = parse_until_end [                  "End";"Sub";"Quit"] (* ([            ],["Sub";"Quit"]) *)



let pe10 = parse_until_end [ "Begin";  "Begin";  "Pop" ;  "End";  "End"]


let parse_commands (ls :string list) : command list =
  let (coms, _) = parse_until_end ls 
  in coms
  
let pe20 = parse_commands ["PushB <true>";"Neg";"PushI 10";"Sub";"Quit"]
let pe21 = parse_commands [ "Begin"; "Begin"; "Pop" ; "End"; "End"]

let pe22 = parse_commands [ "Begin"; "Pop" ; "End";] (*  [Block [Pop]] *)

let pe23 = parse_commands [ "Begin"; "Begin"; "Pop" ; "End"; "Begin"; "Pop" ; "End"; "End"] (* [Block [Block [Pop]; Block [Pop]] *)
let pe24 = parse_commands [ "Pop" ; "End"; "Pop" ; "Pop" ] (*  ([Pop], ["Pop" ; "Pop" ] ) *)

let rec read_lines (ch : in_channel) : string list =
  match input_line ch with 
    | str                    -> str :: read_lines ch
    | exception  End_of_file -> [] 
    
    
(* from lab 3 *)
let rec write_lines (ch) (ls : string list ) : unit =
  match ls with
    | []      -> ()
    | x :: xs -> let _ = Printf.fprintf ch "%s\n" x in write_lines ch xs

  


let interpreter (inputFile : string) (outputFile : string) : unit =
  let ic = open_in inputFile in
  let lines_in = List.map String.trim (read_lines ic) in
  let _ = close_in ic in
  
  let commands = parse_commands lines_in in
  let (stack,_) = run commands [] empEnv in
  let lines_out = List.map to_string stack in
  
  let oc = open_out outputFile in
  let _ = write_lines oc lines_out in
  let _ = close_out oc in ()

let test (inputFile: string) : command list =
  let ic = open_in inputFile in
  let lines_in = List.map String.trim (read_lines ic) in
  let _ = close_in ic in
  
  let commands = parse_commands lines_in in commands
