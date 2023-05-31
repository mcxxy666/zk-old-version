
(* The type of tokens. *)

type token = 
  | ZERO
  | UNIT
  | SPLIT
  | RPAREN
  | REP
  | PERIOD
  | PAR
  | OUTPUTS
  | OUTPUT
  | NUS
  | NU
  | MATCH
  | LPAREN
  | IS
  | INT of (int)
  | INR
  | INPUTS
  | INPUT
  | INL
  | IDENT of (string)
  | ERPAREN
  | EOF
  | END
  | ELPAREN
  | DECRYPT
  | COMMA
  | COLON
  | CHECK
  | CASE
  | BEGIN

(* This exception is raised by the monolithic API functions. *)

exception Error

(* The monolithic API. *)

val main: (Lexing.lexbuf -> token) -> Lexing.lexbuf -> (unit Datatype.procexp)
