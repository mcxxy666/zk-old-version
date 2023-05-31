open Datatype;;

(*** parency priority? ***)

let prec_out = 5
let prec_in = 5
let prec_par = 2
let prec_rep = 4
let prec_nu = 1
let prec_check = 2
let prec_dec = 2
let prec_case = 3
let prec_split = 2
let prec_begin = 2
let prec_end = 2

(*** pretty printer ***)

let rec print_stype t = match t with
    TUnit -> "()"
  | TName -> "Name"
  | TPair(t1,t2) -> ("("^(print_stype t1)^"*"^(print_stype t2)^")")
  | TVari(t1,t2) -> ("("^(print_stype t1)^"+"^(print_stype t2)^")")
  | TKey(ty) -> ("Key("^(print_stype ty)^")")
  | TChan(ty) -> ("Ch("^(print_stype ty)^")")
  | TVar(n) -> ("T"^(string_of_int n))

let print_exname x = match x with
    ENname(s) -> s
  | ENindex(n) -> string_of_int n

let rec print_message m = match m with
    Name(x) -> print_exname x
  | Unit -> "()"
  | Pair(m1,m2) -> ("("^(print_message m1)^","^(print_message m2)^")")
  | Inl(m) -> ("inl("^(print_message m)^")")
  | Inr(m) -> ("inr("^(print_message m)^")")
  | Enc(m,k) -> ("{"^(print_message m)^"}_"^(print_message k))

let print_atef a = match a with
    AEend(m) -> ("End <"^(print_message m)^">")
  | AEchk(x) -> ("Chk <"^(print_exname x)^">")

let rec print_efelem el = match el with
    (a,f)::tl -> ((print_atef a)^"->"^(string_of_float f)^" "^(print_efelem tl))
  | [] -> " "

let rec print_effect e = match e with
    Emap(el) -> ("(["^(print_efelem el)^"])")
  | Evar(n) -> ("e"^(string_of_int n))
  | Eplus(e1,e2) -> ("("^(print_effect e1)^"+"^(print_effect e2)^")")
  | Esub(i,x,ef) -> ("(["^x^"/"^(string_of_int i)^"]"^(print_effect ef)^")")

let rec print_etype t = match t with
    ETUnit -> "()"
  | ETName(e) -> ("Name"^(print_effect e))
  | ETPair(t1,t2) -> ("("^(print_etype t1)^"*"^(print_etype t2)^")")
  | ETVari(t1,t2) -> ("("^(print_etype t1)^"+"^(print_etype t2)^")")
  | ETKey(ty) -> ("Key("^(print_etype ty)^")")
  | ETChan(ty) -> ("Ch("^(print_etype ty)^")")
  | ETany -> "Name"

(*** pretty printer for processes ***)

let rec print_proc prec print_t p = match p with
    Zero ->
      print_string "O"
  | Out(m,n) ->
      (print_string ((print_message m)^"!"^(print_message n)))
  | OutS(m,n) ->
      (print_string ((print_message m)^"!!"^(print_message n)))
  | In(m,x,t,pr) ->
      (print_string (print_message m);print_string "?";
       (match print_t with
	    Some f -> print_string ("("^x^":"^(f t)^")")
	  | None -> print_string x);
       if pr=Zero then () else (print_string ".";print_proc prec_in print_t pr))
  | InS(m,x,t,pr) ->
      (print_string (print_message m);print_string "??";
       (match print_t with
	    Some f -> print_string ("("^x^":"^(f t)^")")
	  | None -> print_string x);
       if pr=Zero then () else (print_string ".";print_proc prec_in print_t pr))
  | Par(pr1,pr2) ->
      (if prec>prec_par then print_string "(";
       print_proc prec_par print_t pr1;print_string "|";print_proc prec_par print_t pr2;
       if prec>prec_par then print_string ")")
  | Rep(pr) ->
      (print_string "*(";print_proc prec print_t pr;print_string ")")
  | Nu(x,t,pr) ->
      (print_string "(";
       (match print_t with
	    Some f -> print_string ("new "^x^":"^(f t))
	  | None -> print_string ("new "^x));
        print_string ")";
        print_proc prec print_t pr)
  | NuS(x,t,pr) ->
      (print_string "(";
       (match print_t with
	    Some f -> print_string ("newS "^x^":"^(f t))
	  | None -> print_string ("newS "^x));
        print_string ")";
        print_proc prec print_t pr)
  | Check(x,n,pr) ->
      (if prec>prec_check then print_string "(";
       print_string ("check "^x^" is "^(print_message n)^".");
       print_proc prec_check print_t pr;
       if prec>prec_check then print_string ")")
  | Dec(m,x,t,k,pr) ->
      (if prec>prec_dec then print_string "(";
       print_string ("decrypt "^(print_message m)^" is ");
       (match print_t with
	    Some f -> print_string ("{"^x^":"^(f t)^"}")
	  | None -> print_string ("{"^x^"}"));
        print_string ("_"^(print_message k)^".");
	print_proc prec_dec print_t pr;
        if prec>prec_dec then print_string ")")
  | Case(m,x,t1,pr1,y,t2,pr2) ->
      (if prec>prec_case then print_string "(";
       print_string ("case "^(print_message m)^" is ");
       (match print_t with
	    Some f -> print_string ("inl("^x^":"^(f t1)^").")
	  | None -> print_string ("inl("^x^")."));
       print_proc prec_case print_t pr1;print_string " is ";
       (match print_t with
	    Some f -> print_string ("inr("^y^":"^(f t2)^").")
	  | None -> print_string ("inr("^y^")."));
        print_proc prec_case print_t pr2;
        if prec>prec_case then print_string ")")
  | Split(m,x,t1,y,t2,pr) ->
      (if prec>prec_split then print_string "(";
       print_string ("split "^(print_message m)^" is ");
       (match print_t with
	    Some f -> print_string ("("^x^":"^(f t1)^","^y^":"^(f t2)^").")
	  | None -> print_string ("("^x^","^y^")."));
        print_proc prec_split print_t pr;
        if prec>prec_split then print_string ")")
  | Match(m,x,y,t2,pr) ->
      (if prec>prec_split then print_string "(";
       print_string ("match "^(print_message m)^" is ");
       (match print_t with
	    Some f -> print_string ("("^x^","^y^":"^(f t2)^").")
	  | None -> print_string ("("^x^","^y^")."));
        print_proc prec_split print_t pr;
        if prec>prec_split then print_string ")")
  | Begin(m,pr) ->
      (if prec>prec_begin then print_string "(";
       print_string ("begin "^(print_message m)^".");
       print_proc prec_begin print_t pr;
       if prec>prec_begin then print_string ")")
  | End(m,pr) ->
      (if prec>prec_end then print_string "(";
       print_string ("end "^(print_message m)^".");
       print_proc prec_end print_t pr;
       if prec>prec_end then print_string ")")

(*** pretty printer for processes with indents ***)

let pp_nl indt = print_string ("\n"^indt)
let inc_indt indt = indt^"  "

let rec sizeof p = match p with
    Zero -> 0
  | Out(m,n) -> 1
  | OutS(m,n) -> 1
  | In(m,x,t,pr) -> 1+(sizeof pr)
  | InS(m,x,t,pr) -> 1+(sizeof pr)
  | Par(pr1,pr2) -> 1+(sizeof pr1)+(sizeof pr2)
  | Rep(pr) -> 1+(sizeof pr)
  | Nu(x,t,pr) -> 2+(sizeof pr)
  | NuS(x,t,pr) -> 2+(sizeof pr)
  | Check(x,n,pr) -> 2+(sizeof pr)
  | Dec(m,x,t,k,pr) -> 4+(sizeof pr)
  | Case(m,x,t1,pr1,y,t2,pr2) -> 5+(sizeof pr1)+(sizeof pr2)
  | Split(m,x,t1,y,t2,pr) -> 5+(sizeof pr)
  | Match(m,x,y,t2,pr) -> 5+(sizeof pr)
  | Begin(m,pr) -> 1+(sizeof pr)
  | End(m,pr) -> 1+(sizeof pr)

let rec pprint_proc indt prec size_lim print_t p =
if (sizeof p)<size_lim then
  print_proc prec print_t p
else
  match p with
    Zero ->
      print_string "O"
  | Out(m,n) ->
      (print_string ((print_message m)^"!"^(print_message n));
       let indt' = inc_indt indt in
	 pp_nl indt')
  | OutS(m,n) ->
      (print_string ((print_message m)^"!!"^(print_message n));
       let indt' = inc_indt indt in
	 pp_nl indt')
  | In(m,x,t,pr) ->
      (print_string (print_message m);print_string "?";
       (match print_t with
	    Some f -> print_string ("("^x^":"^(f t)^")")
	  | None -> print_string x));
       if pr=Zero then ()
       else (print_string ".";
	     let indt' = inc_indt indt in
	       (pp_nl indt';pprint_proc indt' prec_in size_lim print_t pr))
  | InS(m,x,t,pr) ->
      (print_string (print_message m);print_string "??";
       (match print_t with
	    Some f -> print_string ("("^x^":"^(f t)^")")
	  | None -> print_string x));
       if pr=Zero then ()
       else (print_string ".";
	     let indt' = inc_indt indt in
	       (pp_nl indt';pprint_proc indt' prec_in size_lim print_t pr))
  | Par(pr1,pr2) ->
      (if prec>prec_par then print_string "(";
       pprint_proc indt prec_par size_lim print_t pr1;
       print_string "|";pp_nl indt;
       pprint_proc indt prec_par size_lim print_t pr2;
       if prec>prec_par then print_string ")")
  | Rep(pr) ->
      (print_string "*(";
       pprint_proc (inc_indt indt) prec_rep size_lim print_t pr;
       print_string ")")
  | Nu(x,t,pr) ->
      (print_string "(";
       (match print_t with
	    Some f -> print_string ("new "^x^":"^(f t))
	  | None -> print_string ("new "^x)));
       print_string ")";
       (pp_nl indt;pprint_proc indt prec size_lim print_t pr)
  | NuS(x,t,pr) ->
      (print_string "(";
       (match print_t with
	    Some f -> print_string ("newS "^x^":"^(f t))
	  | None -> print_string ("newS "^x)));
       print_string ")";
       (pp_nl indt;pprint_proc indt prec size_lim print_t pr)
  | Check(x,n,pr) ->
      (if prec>prec_check then print_string "(";
       print_string ("check "^x^" is "^(print_message n)^".");
       let indt' = inc_indt indt in
	 (pp_nl indt';pprint_proc indt' prec_check size_lim print_t pr);
       if prec>prec_check then print_string ")")
  | Dec(m,x,t,k,pr) ->
      (if prec>prec_dec then print_string "(";
       print_string ("decrypt "^(print_message m)^" is ");
       (match print_t with
	    Some f -> print_string ("{"^x^":"^(f t)^"}")
	  | None -> print_string ("{"^x^"}"));
        print_string ("_"^(print_message k)^".");
	let indt' = (inc_indt indt) in
	  (pp_nl indt';pprint_proc indt' prec_dec size_lim print_t pr);
        if prec>prec_dec then print_string ")")
  | Case(m,x,t1,pr1,y,t2,pr2) ->
      let indt' = (inc_indt indt) in
	(if prec>prec_case then print_string "(";
	 print_string ("case "^(print_message m)^" is ");
	 (match print_t with
	    Some f -> print_string ("inl("^x^":"^(f t1)^").")
	  | None -> print_string ("inl("^x^")."));
	 pp_nl indt';
	 pprint_proc indt' prec_case size_lim print_t pr1;
	 pp_nl indt';
	 print_string " is ";
	 (match print_t with
	    Some f -> print_string ("inr("^y^":"^(f t2)^").")
	  | None -> print_string ("inr("^y^")."));
	 pp_nl indt';
	 pprint_proc indt' prec_case size_lim print_t pr2;
	 pp_nl indt';
	 if prec>prec_case then print_string ")")
  | Split(m,x,t1,y,t2,pr) ->
      (if prec>prec_split then print_string "(";
       print_string ("split "^(print_message m)^" is ");
       (match print_t with
	    Some f -> print_string ("("^x^":"^(f t1)^","^y^":"^(f t2)^").")
	  | None -> print_string ("("^x^","^y^")."));
	let indt' = (inc_indt indt) in
          (pp_nl indt';pprint_proc indt' prec_split size_lim print_t pr);
        if prec>prec_split then print_string ")")
  | Match(m,x,y,t2,pr) ->
      (if prec>prec_split then print_string "(";
       print_string ("match "^(print_message m)^" is ");
       (match print_t with
	    Some f -> print_string ("("^x^","^y^":"^(f t2)^").")
	  | None -> print_string ("("^x^","^y^")."));
	let indt' = (inc_indt indt) in
          (pp_nl indt';pprint_proc indt' prec_split size_lim print_t pr);
        if prec>prec_split then print_string ")")
  | Begin(m,pr) ->
      (if prec>prec_begin then print_string "(";
       print_string ("begin "^(print_message m)^".");
       let indt' = (inc_indt indt) in
	 (pp_nl indt';pprint_proc indt' prec_begin size_lim print_t pr);
       if prec>prec_begin then print_string ")")
  | End(m,pr) ->
      (if prec>prec_end then print_string "(";
       print_string ("end "^(print_message m)^".");
       let indt' = (inc_indt indt) in
	 (pp_nl indt';pprint_proc indt' prec_end size_lim print_t pr);
       if prec>prec_end then print_string ")")

let pp_proc print_t p = pprint_proc "" 0 7 print_t p
