open Datatype

(*** type environment ***)
type 'a env = (ex_name * 'a) list

let rec env_lookup x env = match env with
    [] -> raise Not_found
  | (x',ty')::tl -> if x=x' then ty' else (env_lookup x tl)

let env_extend x ty env = (x,ty)::env

let env_map f env = List.map (fun (x,v) -> (x,f v)) env

let rec env_dom env = match env with
    [] -> []
  | (x,_)::tl -> x::(env_dom tl)

(*** free variables ***)

let rec fv_msg m = match m with
    Name(x) -> [x]
  | Unit -> []
  | Pair(m1,m2) -> (fv_msg m1) @ (fv_msg m2)
  | Inl(m) -> fv_msg m
  | Inr(m) -> fv_msg m
  | Enc(m,k) -> (fv_msg m) @ (fv_msg k)

let set_sub s x = 
   List.filter (fun y -> not(x=y)) s

let union s1 s2 = Utilities.merge_and_unify compare s1 s2

let rec fv_proc p = match p with
    Zero -> []
  | Out(m,n) -> union (fv_msg m) (fv_msg n)
  | In(m,x,_,pr) -> union (fv_msg m) (set_sub (fv_proc pr) (ENname(x)))
  | OutS(m,n) -> union (fv_msg m) (fv_msg n)
  | InS(m,x,_,pr) -> union (fv_msg m) (set_sub (fv_proc pr) (ENname(x)))
  | Par(pr1,pr2) -> union (fv_proc pr1) (fv_proc pr2)
  | Rep(pr) -> fv_proc pr
  | Nu(x,_,pr) -> (set_sub (fv_proc pr) (ENname(x)))
  | NuS(x,_,pr) -> (set_sub (fv_proc pr) (ENname(x)))
  | Check(x,n,pr) -> union [ENname(x)] (union (fv_msg n) (fv_proc pr))
  | Dec(m,x,_,k,pr) -> union (fv_msg m) (union (fv_msg k) (set_sub (fv_proc pr) (ENname(x))))
  | Case(m,y,_,pr1,z,_,pr2) -> 
           union (fv_msg m) (union (set_sub (fv_proc pr1) (ENname(y))) (set_sub (fv_proc pr2) (ENname(z))))
  | Split(m,y,_,z,_,pr) -> 
          union (fv_msg m) (set_sub (set_sub (fv_proc pr) (ENname(y))) (ENname(z)))
  | Match(m,y,z,_,pr) -> 
         union (fv_msg m) (union [ENname(y)] (set_sub (fv_proc pr) (ENname(z))))
  | Begin(m,pr) -> union (fv_msg m) (fv_proc pr)
  | End(m,pr) -> union (fv_msg m) (fv_proc pr)

exception Stype_failure of stype * stype
exception Unknown_variable of ex_name

let comp_subst subs s1 s2 = 
  let s2' = List.map (fun (ty1,ty2) -> (ty1,subs s1 ty2)) s2 in
  let s1' = List.filter (fun (ty1,ty2) -> List.for_all (fun (ty1',ty2') -> ty1!=ty1') s2) s1 in
    s1' @ s2'

let subst_var s t1 t2 = 
  try
    List.assoc t1 s
  with
    Not_found -> t2

let rec tsubst s t = match t with
    TUnit -> TUnit
  | TName -> TName
  | TPair(ty1,ty2) -> TPair(tsubst s ty1,tsubst s ty2)
  | TVari(ty1,ty2) -> TVari(tsubst s ty1,tsubst s ty2)
  | TKey(ty) -> TKey(tsubst s ty)
  | TChan(ty) -> TChan(tsubst s ty)
  | TVar(n) -> subst_var s (TVar(n)) t

let rec map_for_t f p = match p with
    Zero -> Zero
  | Out(m,n) -> Out(m,n)
  | In(m,x,ty,pr) -> In(m,x,f ty,map_for_t f pr)
  | OutS(m,n) -> OutS(m,n)
  | InS(m,x,ty,pr) -> InS(m,x,f ty,map_for_t f pr)
  | Par(pr1,pr2) -> Par(map_for_t f pr1,map_for_t f pr2)
  | Rep(pr) -> Rep(map_for_t f pr)
  | Nu(x,ty,pr) -> Nu(x,f ty,map_for_t f pr)
  | NuS(x,ty,pr) -> NuS(x,f ty,map_for_t f pr)
  | Check(x,n,pr) -> Check(x,n,map_for_t f pr)
  | Dec(m,x,ty,k,pr) -> Dec(m,x,f ty,k,map_for_t f pr)
  | Case(m,y,ty,pr1,z,tz,pr2) -> Case(m,y,f ty,map_for_t f pr1,z,f tz,map_for_t f pr2)
  | Split(m,y,ty,z,tz,pr) -> Split(m,y,f ty,z,f tz,map_for_t f pr)
  | Match(m,y,z,tz,pr) -> Match(m,y,z,f tz,map_for_t f pr)
  | Begin(m,pr) -> Begin(m,map_for_t f pr)
  | End(m,pr) -> End(m,map_for_t f pr)

let tsubst_for_proc s = map_for_t (tsubst s)

let tinfVar x env =
  try
    env_lookup x env
  with
    Not_found -> raise (Unknown_variable(x))


let fresh_tyvar =
  let cnt = ref 0 in
  let body () =
    let v = !cnt in
      cnt := v + 1; v
  in body

let fresh_tv() = TVar(fresh_tyvar())

let rec tinfV m env = match m with
    Name(x) -> (tinfVar x env,[]) 
  | Unit -> (TUnit,[])
  | Pair(m1,m2) -> 
      let (ty1,sc1) = tinfV m1 env in
      let (ty2,sc2) = tinfV m2 env in
	(TPair(ty1,ty2),sc1 @ sc2)
  | Inl(m') -> 
      let (ty,sc) = tinfV m' env in
	(TVari(ty, fresh_tv()),sc)
  | Inr(m') ->
      let (ty,sc) = tinfV m' env in
	(TVari(fresh_tv(),ty),sc)
  | Enc(m',k) -> 
      let (ty_m,sc_m) = tinfV m' env in
      let (ty_k,sc_k) = tinfV k env in
	(TName,[(ty_k,TKey(ty_m))] @ sc_m @ sc_k)

(*** Simple Type Infefence: unit procexp -> stype procexp * st_constraints ***)
let rec tinf p env = match p with
    Zero -> (Zero,[])
  | Out(m,n) -> 
      let (ty_m,sc_m) = tinfV m env in
      let (ty_n,sc_n) = tinfV n env in
	(Out(m,n),sc_m @ sc_n @ [(ty_m,TName)])
  | OutS(m,n) -> 
      let (ty_m,sc_m) = tinfV m env in
      let (ty_n,sc_n) = tinfV n env in
	(OutS(m,n),sc_m @ sc_n @ [(ty_m,TChan(ty_n))])
  | In(m,x,_,pr) -> 
      let (ty_m,sc_m) = tinfV m env in
      let xn = fresh_tyvar () in
      let ty_x = TVar(xn) in
      let env' = env_extend (ENname(x)) ty_x env in
      let (pr',sc_p) = tinf pr env' in
	(In(m,x,ty_x,pr'),sc_m @ sc_p @ [(ty_m,TName)])
  | InS(m,x,_,pr) -> 
      let (ty_m,sc_m) = tinfV m env in
      let xn = fresh_tyvar () in
      let ty_x = TVar(xn) in
      let env' = env_extend (ENname(x)) ty_x env in
      let (pr',sc_p) = tinf pr env' in
	(InS(m,x,ty_x,pr'),sc_m @ sc_p @ [(ty_m,TChan(ty_x))])
  | Par(pr1,pr2) -> 
      let (pr1',sc1) = tinf pr1 env in
      let (pr2',sc2) = tinf pr2 env in
	(Par(pr1',pr2'),sc1 @ sc2)
  | Rep(pr) -> 
      let (pr',sc_p) = tinf pr env in
	(Rep(pr'),sc_p)
  | Nu(x,_,pr) -> 
      let xn = fresh_tyvar () in
      let ty_x = TVar(xn) in
      let env' = env_extend (ENname(x)) ty_x env in
      let (pr',sc_p) = tinf pr env' in
	(Nu(x,ty_x,pr'),sc_p)
  | NuS(x,_,pr) -> 
      let xn = fresh_tyvar () in
      let ty_x = TVar(xn) in
      let env' = env_extend (ENname(x)) (TChan(ty_x)) env in
      let (pr',sc_p) = tinf pr env' in
	(NuS(x,TChan(ty_x),pr'),sc_p)
  | Check(x,n,pr) -> 
      let (ty_n,sc_n) = tinfV n env in
      let (pr',sc_p) = tinf pr env in
	(Check(x,n,pr'),sc_n @ sc_p @ [(ty_n,TName)])
  | Dec(m,x,_,k,pr) -> 
      let (ty_m,sc_m) = tinfV m env in
      let (ty_k,sc_k) = tinfV k env in
      let xn = fresh_tyvar () in
      let ty_x = TVar(xn) in
      let env' = env_extend (ENname(x)) ty_x env in
      let (pr',sc_p) = tinf pr env' in
	(Dec(m,x,ty_x,k,pr'),sc_m @ sc_k @ sc_p @ [(ty_m,TName);(ty_k,TKey(ty_x))])
  | Case(m,y,_,pr1,z,_,pr2) -> 
      let (ty_m,sc_m) = tinfV m env in
      let yn = fresh_tyvar () in
      let ty_y = TVar(yn) in
      let env' = env_extend (ENname(y)) ty_y env in
      let (pr1',sc_p1) = tinf pr1 env' in
      let zn = fresh_tyvar () in
      let ty_z = TVar(zn) in
      let env'' = env_extend (ENname(z)) ty_z env in
      let (pr2',sc_p2) = tinf pr2 env'' in
	(Case(m,y,ty_y,pr1',z,ty_z,pr2'),sc_m @ sc_p1 @ sc_p2 @ [(ty_m,TVari(ty_y,ty_z))])
  | Split(m,y,_,z,_,pr) -> 
      let (ty_m,sc_m) = tinfV m env in
      let yn = fresh_tyvar () in
      let ty_y = TVar(yn) in
      let zn = fresh_tyvar () in
      let ty_z = TVar(zn) in 
      let env' = env_extend (ENname(z)) ty_z (env_extend (ENname(y)) ty_y env) in
      let (pr',sc_p) = tinf pr env' in
	(Split(m,y,ty_y,z,ty_z,pr'),sc_m @ sc_p @ [(ty_m,TPair(ty_y,ty_z))])
  | Match(m,y,z,_,pr) -> 
      let (ty_m,sc_m) = tinfV m env in
      let ty_y = tinfVar (ENname(y)) env in
      let zn = fresh_tyvar () in
      let ty_z = TVar(zn) in 
      let env' = env_extend (ENname(z)) ty_z (env_extend (ENname(y)) ty_y env) in
      let (pr',sc_p) = tinf pr env' in
	(Match(m,y,z,ty_z,pr'),sc_m @ sc_p @ [(ty_m,TPair(TName,ty_z)); (ty_y, TName)])
  | Begin(m,pr) -> 
      let (ty_m,sc_m) = tinfV m env in
      let (pr',sc_p) = tinf pr env in
	(Begin(m,pr'),sc_m @ sc_p)
  | End(m,pr) -> 
      let (ty_m,sc_m) = tinfV m env in
      let (pr',sc_p) = tinf pr env in
	(End(m,pr'),sc_m @ sc_p)

let unif c =
  let subst_for_c s c =
    List.map (fun (ty1,ty2) -> (tsubst s ty1,tsubst s ty2)) c
  in
  let rec unif_aux (c,s) = match c with
      [] -> s
    | (ty1,ty2)::tl -> if ty1=ty2 then unif_aux (tl,s) else match (ty1,ty2) with
	  (TVar(n),_) -> 
	    let s1 = [(TVar(n),ty2)] in
	    let s2 = comp_subst tsubst s1 s in
	    let t1' = subst_for_c s1 tl in 
	      unif_aux (t1',s2)
	| (_,TVar(n)) -> unif_aux ((ty2,ty1)::tl,s)
	| (TPair(ty1,ty2),TPair(ty1',ty2')) -> unif_aux ((ty1,ty1')::((ty2,ty2')::tl),s)
	| (TVari(ty1,ty2),TVari(ty1',ty2')) -> unif_aux ((ty1,ty1')::((ty2,ty2')::tl),s)
	| (TKey(ty),TKey(ty')) -> unif_aux ((ty,ty')::tl,s)
	| (TChan(ty),TChan(ty')) -> unif_aux ((ty,ty')::tl,s)
	| _ -> raise (Stype_failure(ty1,ty2))
  in
    unif_aux (c,[])

let rec specify_type t = match t with
    TUnit -> TUnit
  | TName -> TName
  | TPair(ty1,ty2) -> TPair(specify_type ty1,specify_type ty2)
  | TVari(ty1,ty2) -> TVari(specify_type ty1,specify_type ty2)
  | TKey(ty) -> TKey(specify_type ty)
  | TChan(ty) -> TChan(specify_type ty)
  | TVar(n) -> TName

(*** stype_inf: unit procexp -> stype procexp * stype env ***)
let rec stype_inf (p: unit procexp) = 
  let fv = fv_proc p in
  let env = List.fold_left (fun env -> fun x -> env_extend x TName env) [] fv in
  let (p',c) = tinf p env in
  let s = unif c in
  let p'' = tsubst_for_proc s p' in
  let p''' = map_for_t specify_type p'' in
  let env' = env_map (tsubst s) env in
    (p''',env')

