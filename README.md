## Based on [antlr sqlite3 grammar-v4](https://github.com/antlr/grammars-v4/tree/3a73a199cc31fb600c5d7b0f141cedd168933e20/sql/sqlite)

## modifications
- ...
- switch SQLite to Postgres
- support postgres style type cast(eg. `::int`)
- discard `expr [NOT] MATCH expr`
- discard `expr [NOT] GLOB expr`
- discard `expr [NOT] REGEXP expr`
- discard `REPLACE INTO`
- discard `INSERT OR REPLACE INTO`
- discard `LIMIT x,y`
- discard `NATURAL JOIN`
- discard `TABLE_NAME INDEXED BY INDEX_NAME`
- discard `TABLE_NAME NOT INDEXED`
- discard `UPDATE OR (ROLLBACK|ABORT|REPLACE|FAIL|IGNORE)`
- discard `expr NOT NULL`
- change `expr IS [NOT] expr` to `expr IS [NOT] (NULL|TRUE|FALSE)`; NOTE: if right argument is true/false, expr 
  should also be true/false(Postgres will error), but parser cannot validate this
- discard bitwise operator `~ | & << >> ||`
- discard `==` operator
- change entry RULE of parser to `statements`
- rename Lexer and Parser to `SQLLexer` and `SQLParser`
- refactor `expr`, reflect Postgres operator precedence
- discard `collation` in `ordering_term`
- remove blob literal lexer rule