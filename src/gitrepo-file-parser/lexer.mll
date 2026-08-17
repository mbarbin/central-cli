(*********************************************************************************)
(*  central-cli - Manage history between sub-repos and their monorepo            *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

{
  open Parser
}

let whitespace = [' ' '\t']+
let newline = '\n' | "\r\n"

rule read = parse
 | whitespace                                   { read lexbuf }
 | newline                                      { Lexing.new_line lexbuf;
                                                  read lexbuf }
 | ([';'] [^'\n']*) as text                     { COMMENT text }
 | "[subrepo]"                                  { SUBREPO }
 | "remote"                                     { REMOTE }
 | "branch"                                     { BRANCH }
 | "commit"                                     { COMMIT }
 | "parent"                                     { PARENT }
 | "method"                                     { METHOD }
 | "rebase"                                     { REBASE }
 | "merge"                                      { MERGE }
 | "cmdver"                                     { CMDVER }
 | '='                                          { EQUAL }
 | (['A'-'Z' 'a'-'z' '0'-'9'
     '_' '-' '\'' '/' '~' '.'
    ]+ as lexem)                                 { LEXEM lexem }
 | eof                                          { EOF }
