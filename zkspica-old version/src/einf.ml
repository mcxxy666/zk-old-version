open Datatype
open Utilities
exception TypeError of string
exception TODO
exception Teq of etype * etype

type et_env = (name * etype) list
let one = 1.
let zero = 0.

let ef_zero = Emap([])
let ef_check en = Emap [(AEchk(en), one)]
let ef_end m = Emap [(AEend(m), one)]
let unT = ETName(ef_zero)

let eplus(e1, e2) =
  if e1=ef_zero then e2
  else if e2=ef_zero then e1
  else Eplus(e1,e2)

let current_evid = ref 0;;
let fresh_evid() =
  (current_evid := !current_evid + 1;
   !current_evid);;

let rec teq t1 t2 = 
  if (t1=t2 || t1=ETany || t2=ETany) then []
  else match (t1,t2) with
    (ETName(e1),ETName(e2)) -> [ECeq(e1,e2)]
  | (ETKey(t1),ETKey(t2)) -> teq t1 t2
  | (ETChan(t1),ETChan(t2)) -> teq t1 t2
  | (ETPair(t1,t2),ETPair(t1',t2')) -> (teq t1 t1') @ (teq t2 t2')
  | (ETVari(t1,t2),ETVari(t1',t2')) -> (teq t1 t1') @ (teq t2 t2')
  | _ -> raise (Teq (t1, t2)) 
(***  | _ -> raise (Fatal "teq") ***)

let rec tpub ty = match ty with
    ETUnit -> []
  | ETName(e) -> [ECsub(e,Emap([]))]
  | ETKey(t) -> (tpub t)
  | ETChan(t) -> raise (TypeError "tpub")
  | ETPair(t1,t2) -> (tpub t1)@(tpub t2)
  | ETVari(t1,t2) -> (tpub t1)@(tpub t2)
  | ETany -> []

let rec genT ty =
  match ty with
    ETName(_) -> []
  | ETKey(_) -> []
  | _ -> raise (TypeError "genT")

let shift_name n =
  match n with
    ENname(_) -> n
  | ENindex(i) -> ENindex(i+1)

let shift_names ns =
  List.map shift_name ns

let rec wfT ty ns = 
  match ty with
    ETUnit -> []
  | ETName(e) -> [ECfn(e, ns)]
  | ETKey(t) -> wfT t ns
  | ETChan(t) -> wfT t ns
  | ETPair(t1,t2) -> 
       let ec1 = (wfT t1 ns) in
       let ns' = [ENindex(0)]@ (shift_names ns) in
       let ec2 = wfT t2 ns' in
         ec1@ec2
  | ETVari(t1,t2) -> (wfT t1 ns)@(wfT t2 ns)
  | ETany -> []

let wfE e ns = [ECfn(e, ns)]

let name2exname n = ENname n
let dom env = (List.map name2exname (List.map fst env))

let rec sty2ety sty =
  match sty with
    TUnit -> ETUnit
  | TName -> ETName(Evar(fresh_evid()))
  | TPair(t1,t2) -> ETPair(sty2ety t1, sty2ety t2)
  | TVari(t1,t2) -> ETVari(sty2ety t1, sty2ety t2)
  | TKey(t) -> ETKey(sty2ety t)
  | TChan(t) -> ETChan(sty2ety t)
  | TVar(_) -> ETName(Evar(fresh_evid()))

let stenv2etenv stenv =
  List.map 
  (fun (n, st) -> (match n with ENname(m) -> (m, sty2ety st) | _ -> raise (Fatal "stenv2etenv")))
  stenv

let rec ef_subst e n ind =
  Esub(ind, n, e)
(***  match e with
 ***   Emap(l) ->
 ***       let l' = List.map (fun (a, r) -> (atom_subst a n ind, r)) in
 ***       let l'' = List.sort compare l' in
 ***         Emap(merge_atoms l'')
 *** | Evar(ev) -> Esub
 ***)

let rec et_subst t n ind =
  match t with
    ETUnit -> ETUnit
  | ETName(e) -> ETName(ef_subst e n ind)
  | ETPair(t1,t2) -> ETPair(et_subst t1 n ind, et_subst t2 n (ind+1))
  | ETVari(t1,t2) -> ETVari(et_subst t1 n ind, et_subst t2 n ind)
  | ETKey(t1) -> ETKey(et_subst t1 n ind)
  | ETChan(t1) -> ETChan(et_subst t1 n ind)
  | ETany -> ETany

let rec imitate_etype t =
  match t with
    ETUnit -> ETUnit
  | ETName(e) -> ETName(Evar(fresh_evid()))
  | ETPair(t1,t2) -> ETPair(imitate_etype t1, imitate_etype t2)
  | ETVari(t1,t2) -> ETVari(imitate_etype t1, imitate_etype t2)
  | ETKey(t1) -> ETKey(imitate_etype t1)
  | ETChan(t1) -> ETChan(imitate_etype t1)
  | ETany -> ETany

let rec msg_inf (env: et_env) (m: message): effect * etype * ef_constraint =
  match m with
    Name(ENname n) ->
      let t1 = try List.assoc n env with Not_found -> raise (Fatal (n^" is undefined")) in
        (match t1 with
          ETName(ef) ->
              let evid = fresh_evid() in
              let ef' = Evar(evid) in
              let t = ETName (eplus(ef, ef')) in
                (ef', t, [])
        | _ -> (ef_zero, t1, [])
        )
  | Name _ -> raise (Fatal "msg_inf")
  | Unit -> (ef_zero, ETUnit, [])
  | Pair(m1,m2) ->
     let (ef1,t1,ec1) = msg_inf env m1 in
     let (ef2,t2,ec2) = msg_inf env m2 in
       (match m1 with
         Name(ENname n) ->
            let t2' = imitate_etype t2 in
            let t2'' = et_subst t2' n 0 in
              (eplus(ef1,ef2), ETPair(t1,t2'), ec1@ec2@(teq t2 t2''))
       | _ -> (eplus(ef1,ef2), ETPair(t1,t2), ec1@ec2)
        )
  | Inl(m1) -> 
     let (ef1,t1,ec1) = msg_inf env m1 in
       (ef1, ETVari(t1, ETany), ec1)
  | Inr(m1) -> 
     let (ef1,t1,ec1) = msg_inf env m1 in
       (ef1, ETVari(ETany, t1), ec1)
  | Enc(m1,m2) ->
     let (ef1,t1,ec1) = msg_inf env m1 in
     let (ef2,t2,ec2) = msg_inf env m2 in
       ( match t2 with
            ETKey(t0) ->
               (eplus(ef1,ef2), unT, (teq t0 t1)@ec1@ec2)
          | _ -> raise (TypeError "msg_inf")
       )

(*** etype_inf: et_env -> stype procexp -> effect * ef_constraint ***)
let rec etype_inf (env: et_env) (p: stype procexp) = 
 match p with
    Zero -> (ef_zero,[], Zero)
  | Out(m,n) ->
      let (ef_m,ty_m,_) = msg_inf env m in
      let (ef_n,ty_n,ec_n) = msg_inf env n in
      let ec1 = (teq ty_m unT) @ (tpub ty_n) in
      (*** let ec2 = [ECeq(ef_m,Emap([]))] in ***)
	(ef_n, ec_n@ec1, Out(m,n))
  | OutS(m,n) ->
      let (ef_m,ty_m,_) = msg_inf env m in
      let (ef_n,ty_n,ec_n) = msg_inf env n in
      let ec1 = (teq ty_m (ETChan(ty_n))) in
      (***  let ec2 = [ECeq(ef_m,Emap([]))] in ***)
	(ef_n, ec_n@ec1, OutS(m,n))
  | In(m,y,sty,pr) ->
      let (ef_m,ty_m,_) = msg_inf env m in
      let ty_n = sty2ety sty in
      let env' = env_extend y ty_n env in
      let (ef,ec0, pr') = etype_inf env' pr in
      let ec1 = (teq ty_m unT) @ (tpub ty_n) in
      let ec2 = [ECnotin(ENname y,ef)] in
      let ec3 = wfT ty_n (dom env) in
	(ef, ec0@ec1@ec2@ec3, In(m,y,ty_n,pr'))
  | InS(m,y,sty,pr) ->
      let (ef_m,ty_m,_) = msg_inf env m in
      let ty_n = sty2ety sty in
      let env' = env_extend y ty_n env in
      let (ef,ec0, pr') = etype_inf env' pr in
      let ec1 = (teq ty_m (ETChan(ty_n))) in
      let ec2 = [ECnotin(ENname y,ef)] in
      let ec3 = wfT ty_n (dom env) in
	(ef, ec0@ec1@ec2@ec3, InS(m,y,ty_n,pr'))
  | Par(pr1,pr2) ->
      let (ef1,ec1, pr1') = etype_inf env pr1 in
      let (ef2,ec2, pr2') = etype_inf env pr2 in
      let ro = fresh_evid () in
	(eplus(ef1,ef2),ec1 @ ec2, Par(pr1',pr2'))
  | Rep(pr) ->
      let (ef,ec,pr') = etype_inf env pr in
      let ec_e = [ECsub(ef,ef_zero)] in
	(ef_zero,ec @ ec_e, Rep(pr'))
  | Nu(x,sty,pr) -> 
      let ty_x = sty2ety sty in
      let env' = env_extend x ty_x env in
      let (ef,ec, pr') = etype_inf env' pr in
      let ro = fresh_evid () in
      let ec1 = (wfT ty_x (dom  env)) @ (genT ty_x) @ (wfE (Evar(ro)) (dom env))in
      let ec2 = [ECsub(ef, Eplus(Evar(ro), ef_check(ENname(x))));ECnotin(ENname x,Evar(ro))] in
	(Evar(ro),ec @ ec1@ec2, Nu(x, ty_x, pr'))
  | NuS(x,sty,pr) -> 
      let ty_x = sty2ety sty in
      let env' = env_extend x ty_x env in
      let (ef,ec, pr') = etype_inf env' pr in
      let ro = fresh_evid () in
      let ec1 = (wfT ty_x (dom  env)) @ (wfE (Evar(ro)) (dom env))in
      let ec2 = [ECsub(ef, Eplus(Evar(ro), ef_check(ENname(x))));ECnotin(ENname x,Evar(ro))] in
	(Evar(ro),ec @ ec1@ec2, NuS(x, ty_x, pr'))
  | Check(name,n,pr) ->
      let en = ENname(name) in
      let (ef_m,ty_m,ec_m) = msg_inf env (Name(en)) in
      let (ef_n,ef0,ec_n) = 
         (match (msg_inf env n) with
            (ef_n,ETName(ef0),ec_n) -> (ef_n,ef0,ec_n)
            | _ -> raise (TypeError "einf")) in
      let (ef_p,ec_p, pr') = etype_inf env pr in
      let ef = Emap([]) in
      let ro = fresh_evid () in
      let ec_t = (teq ty_m unT) in
      let ec_e = [ECsub(ef_p, eplus(Evar(ro),ef0)); ECsub(ef_n,ef_zero); ECsub(ef_m,ef_zero)] in 
	(eplus(Evar(ro), ef_check(en)),ec_p @ ec_m @ ec_n @ ec_t @ ec_e, Check(name,n,pr'))
  | Dec(m,y,sty, k,pr) ->
      let (ef_m,ty_m,ec_m) = msg_inf env m in
      let (ef_k,ty_k,ec_k) = msg_inf env k in
      let ty_y = sty2ety sty in
      let env' = env_extend y ty_y env in
      let (ef,ec, pr') = etype_inf env' pr in
      let ec_t = (teq ty_m unT) @ (teq ty_k (ETKey(ty_y)))@(wfT ty_y (dom env))in
      let ec_e = [ECsub(ef_m,ef_zero);ECeq(ef_k,ef_zero);ECnotin(ENname y,ef)] in
	(ef,ec @ ec_m @ ec_k @ ec_t @ ec_e, Dec(m,y,ty_y,k,pr'))
  | Case(m,y,sty1,pr1,z,sty2,pr2) ->
      let (ef_m,ty_m,ec_m) = msg_inf env m in
      let ty_y = sty2ety sty1 in
      let env1 = env_extend y ty_y env in
      let ty_z = sty2ety sty2 in
      let env2 = env_extend z ty_z env in
      let (ef1,ec1,pr1') = etype_inf env1 pr1 in
      let (ef2,ec2,pr2') = etype_inf env2 pr2 in
      let ro = fresh_evid () in
      let ef = Evar(ro) in
      let ec_t = (teq ty_m (ETVari(ty_y,ty_z)))@(wfT ty_y (dom env))@(wfT ty_z (dom env)) in
      let ec_e = [ECsub(ef1,ef); ECsub(ef2,ef);ECnotin(ENname y,ef);ECnotin(ENname z,ef)] in
	(Evar(ro),ec1 @ ec2 @ ec_m @ ec_t @ ec_e, Case(m,y,ty_y,pr1',z,ty_z,pr2'))
  | Split(m,y,sty1,z,sty2,pr) ->
      let (ef_m,ty_m,ec_m) = msg_inf env m in
      let ty_y = sty2ety sty1 in
      let ty_z = sty2ety sty2 in
      let ty_z' = et_subst ty_z y 0 in
      let env' = env_extend y ty_y env in
      let env'' = env_extend z ty_z' env' in
      let (ef,ec, pr') = etype_inf env'' pr in
      let ec_t = teq ty_m (ETPair(ty_y,ty_z)) in
      let ec_e = [ECnotin(ENname y,ef);ECnotin(ENname z,ef)] in
	(ef,ec @ ec_m @ ec_t @ ec_e, Split(m,y,ty_y,z,ty_z',pr'))
  | Match(m,a,y,sty,pr) ->
      let (ef_m,ty_m,ec_m) = msg_inf env m in
      let ty_y = sty2ety sty in
      let ty_y' = et_subst ty_y a 0 in
      let env' = env_extend y ty_y' env in
      let (ef,ec, pr') = etype_inf env' pr in
      let ec_t = teq ty_m (ETPair(unT,ty_y)) in
      let ec_e = [ECnotin(ENname y,ef)] in
	(ef,ec @ ec_m @ ec_t @ ec_e, Match(m,a,y,ty_y',pr'))
  | Begin(m,pr) -> 
      let (ef,ec,pr') = etype_inf env pr in
      let ro = fresh_evid () in
      let ec_e = [ECsub(ef, eplus(Evar(ro), ef_end(m)))] in
	(Evar(ro),ec @ ec_e, Begin(m,pr'))
  | End(m,pr) ->
      let (ef,ec, pr') = etype_inf env pr in
	(eplus(ef, ef_end(m)),ec, End(m,pr'));;

let einf stenv p =
  let etenv = stenv2etenv stenv in
  let (ef, ec1, p1) = etype_inf etenv p in
  let ec2 = List.flatten (List.map (fun (x,t)->tpub t) etenv) in
  let ec3 = [ECsub(ef,ef_zero)] in
    (ec3@ec2@ec1, p1)

  