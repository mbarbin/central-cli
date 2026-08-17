/*********************************************************************************/
/*  central-cli - Manage history between sub-repos and their monorepo            */
/*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  */
/*  SPDX-License-Identifier: MIT                                                 */
/*********************************************************************************/

%{
%}

%token EOF
%token <string> COMMENT
%token <string> LEXEM
%token SUBREPO
%token REMOTE
%token BRANCH
%token COMMIT
%token PARENT
%token METHOD
%token CMDVER
%token REBASE
%token MERGE
%token EQUAL

%type <Gitrepo_file.t> file

%start file

%%

file:
  | header=COMMENT* SUBREPO fields=field+ EOF
     { { Gitrepo_file.
         header
       ; remote = (Config_field.remote fields)
       ; branch = (Config_field.branch fields)
       ; commit = (Config_field.commit fields)
       ; parent = (Config_field.parent fields)
       ; method_ = (Config_field.method_ fields)
       ; cmdver = (Config_field.cmdver fields)
       }
     }
;

field:
  | REMOTE EQUAL lexem=LEXEM
    { Config_field.Remote
       (Loc.Txt.create $loc(lexem) (`Repo_root (Vcs.Repo_root.v lexem)))
    }
  | BRANCH EQUAL lexem=LEXEM
    { Config_field.Branch
       (Loc.Txt.create $loc(lexem) (Vcs.Branch_name.v lexem))
    }
  | COMMIT EQUAL lexem=LEXEM
    { Config_field.Commit
       (Loc.Txt.create $loc(lexem) (Vcs.Rev.v lexem))
    }
  | PARENT EQUAL lexem=LEXEM
    { Config_field.Parent
       (Loc.Txt.create $loc(lexem) (Vcs.Rev.v lexem))
    }
  | METHOD EQUAL _lexem=REBASE
    { Config_field.Method
       (Loc.Txt.create $loc(_lexem) `Rebase)
    }
  | METHOD EQUAL _lexem=MERGE
    { Config_field.Method
       (Loc.Txt.create $loc(_lexem) `Merge)
    }
  | CMDVER EQUAL lexem=LEXEM
    { Config_field.Cmdver
       (Loc.Txt.create $loc(lexem) lexem)
    }
;
