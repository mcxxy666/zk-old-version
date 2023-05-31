{
  open Parser
}

let space = [' ' '\t' '\n' '\r']
let digit = ['0'-'9']
let lower = ['a'-'z']
let upper = ['A'-'Z']

rule token = parse
| space+
    { token lexbuf }
| "/*"
    { comment lexbuf;
      token lexbuf }
| "()"
    { UNIT }
| "?"
    { INPUT }
| "??"
    { INPUTS }
| "!"
    { OUTPUT }
| "!!"
    { OUTPUTS }
| ":" 
    { COLON }
| ","
    { COMMA }
| "."
    { PERIOD }
| "O"
    { ZERO }
| "*" 
    { REP }
| "|"
    { PAR }
| "{"
    { ELPAREN }
| "}" 
    { ERPAREN }
| "("
    { LPAREN }
| ")"
    { RPAREN }
| "new"
    { NU }
| "news"
    { NUS }
| "check"
    { CHECK }
| "decrypt"
    { DECRYPT }
| "case"
    { CASE }
| "split"
    { SPLIT }
| "match"
    { MATCH }
| "begin"
    { BEGIN }
| "end"
    { END }
| "is"
    { IS }
| "inl"
    { INL }
| "inr"
    { INR }
| digit+
    { INT(int_of_string (Lexing.lexeme lexbuf)) }
| lower (digit|lower|upper|'_')*
    { IDENT(Lexing.lexeme lexbuf) }
| eof
    { EOF }
| _
    { Format.eprintf "unknown token %s near characters %d-%d@."
	(Lexing.lexeme lexbuf)
	(Lexing.lexeme_start lexbuf)
	(Lexing.lexeme_end lexbuf);
      failwith "lex error!" }
and comment = parse
| "*/"
    { () }
| "/*"
    { comment lexbuf;
      comment lexbuf }
| eof
    { failwith "unterminated comment" }
| _
    { comment lexbuf }
