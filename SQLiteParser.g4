/*
 * The MIT License (MIT)
 *
 * Copyright (c) 2014 by Bart Kiers
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
 * associated documentation files (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge, publish, distribute,
 * sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all copies or
 * substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
 * NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 * Project : sqlite-parser; an ANTLR4 grammar for SQLite https://github.com/bkiers/sqlite-parser
 * Developed by:
 *     Bart Kiers, bart@big-o.nl
 *     Martin Mirchev, marti_2203@abv.bg
 *     Mike Lische, mike@lischke-online.de
 */

// $antlr-format alignTrailingComments on, columnLimit 130, minEmptyLines 1, maxEmptyLinesToKeep 1, reflowComments off
// $antlr-format useTab off, allowShortRulesOnASingleLine off, allowShortBlocksOnASingleLine on, alignSemicolons ownLine

parser grammar SQLiteParser;

options {
    tokenVocab = SQLiteLexer;
}

parse: (sql_stmt_list)* EOF
;

sql_stmt_list:
    SCOL* sql_stmt (SCOL+ sql_stmt)* SCOL*
;

sql_stmt: (
        delete_stmt
        | insert_stmt
        | select_stmt
        | update_stmt
    )
;

indexed_column: column_name
;

cte_table_name:
    table_name (OPEN_PAR column_name (COMMA column_name)* CLOSE_PAR)?
;

common_table_expression:
    cte_table_name AS_ OPEN_PAR select_stmt_core CLOSE_PAR
;

common_table_stmt: //additional structures
    WITH_ common_table_expression (COMMA common_table_expression)*
;

delete_stmt:
    common_table_stmt?
    DELETE_ FROM_ qualified_table_name
    (WHERE_ expr)?
    returning_clause?
;

/*
 SQLite understands the following binary operators, in order from highest to lowest precedence:
    ||
    * / %
    + -
    << >> & |
    < <= > >=
    = == != <> IS IS NOT IN LIKE GLOB MATCH REGEXP
    AND
    OR
 */
expr:
    // primary expressions(those dont fit operator pattern), order is irrelevant
    literal_value
    | BIND_PARAMETER
    | (table_name DOT)? column_name
    | ((NOT_)? EXISTS_)? OPEN_PAR select_stmt_core CLOSE_PAR
    // order is relevant for the rest
    | OPEN_PAR elevate_expr=expr CLOSE_PAR
    | (MINUS | PLUS | TILDE) unary_expr=expr
    | expr COLLATE_ collation_name
    | expr PIPE2 expr
    | expr ( STAR | DIV | MOD) expr
    | expr ( PLUS | MINUS) expr
    | expr ( LT2 | GT2 | AMP | PIPE) expr
    | expr ( LT | LT_EQ | GT | GT_EQ) expr
    // below are all operators with the same precedence
    | expr (
        ASSIGN
        | EQ
        | NOT_EQ1
        | NOT_EQ2
        | IS_ NOT_?
        | IS_ NOT_? DISTINCT_ FROM_
        | NOT_? (IN_ | GLOB_ | MATCH_ | REGEXP_)
    ) expr
    | expr NOT_? LIKE_ expr (ESCAPE_ expr)?
    | expr NOT_? BETWEEN_ expr AND_ expr
    | expr ( ISNULL_ | NOTNULL_ | NOT_ NULL_)
    //
    | NOT_ unary_expr=expr
    | expr AND_ expr
    | expr OR_ expr
    | OPEN_PAR expr_list+=expr (COMMA expr_list+=expr)* CLOSE_PAR
    | function_name OPEN_PAR ((DISTINCT_? expr (COMMA expr)*) | STAR)? CLOSE_PAR
    | CASE_ case_expr=expr? (WHEN_ when_expr+=expr THEN_ then_expr+=expr)+ (ELSE_ else_expr=expr)? END_
;

literal_value:
    NUMERIC_LITERAL
    | STRING_LITERAL
    | NULL_
    | TRUE_
    | FALSE_
;

value_row:
    OPEN_PAR expr (COMMA expr)* CLOSE_PAR
;

values_clause:
    VALUES_ value_row (COMMA value_row)*
;

insert_stmt:
    common_table_stmt?
    (REPLACE_ | INSERT_ | INSERT_ OR_ REPLACE_) INTO_ table_name
    (AS_ table_alias)?
    (OPEN_PAR column_name ( COMMA column_name)* CLOSE_PAR)?
    values_clause
    upsert_clause?
    returning_clause?
;

returning_clause:
    RETURNING_ returning_clause_result_column (COMMA returning_clause_result_column)*
;

// @yaiba eaiser to parse this way
upsert_update:
    (column_name | column_name_list) ASSIGN expr
;

upsert_clause:
    ON_ CONFLICT_
    (OPEN_PAR indexed_column (COMMA indexed_column)* CLOSE_PAR (WHERE_ target_expr=expr)?)?
    DO_
    (
        NOTHING_
        | UPDATE_ SET_
            (
                upsert_update (COMMA upsert_update)*
                (WHERE_ update_expr=expr)?
            )
    )
;

select_stmt_core:
    select_core
    (compound_operator select_core)*
    order_by_stmt?
    limit_stmt?
;

select_stmt:
    common_table_stmt?
    select_stmt_core
;

join_clause:
    table_or_subquery (join_operator table_or_subquery join_constraint)*
;

select_core:
    SELECT_ DISTINCT_?
    result_column (COMMA result_column)*
    (FROM_ (table_or_subquery | join_clause))?
    (WHERE_ whereExpr=expr)?
    (
      GROUP_ BY_ groupByExpr+=expr (COMMA groupByExpr+=expr)*
      (HAVING_ havingExpr=expr)?
    )?
;

table_or_subquery:
    table_name (AS_ table_alias)?
    | OPEN_PAR select_stmt_core CLOSE_PAR (AS_ table_alias)?
;

result_column:
    STAR
    | table_name DOT STAR
    | expr (AS_ column_alias)?
;

returning_clause_result_column:
    STAR
    | expr (AS_ column_alias)?
;

join_operator:
    NATURAL_?
    ((LEFT_ | RIGHT_ | FULL_) OUTER_? | INNER_)?
    JOIN_
;

join_constraint:
    ON_ expr
;

compound_operator:
    UNION_ ALL_?
    | INTERSECT_
    | EXCEPT_
;

update_set_subclause:
    (column_name | column_name_list) ASSIGN expr
;

update_stmt:
    common_table_stmt?
    UPDATE_ (OR_ (ROLLBACK_ | ABORT_ | REPLACE_ | FAIL_ | IGNORE_))?
    qualified_table_name
    SET_ update_set_subclause (COMMA update_set_subclause)*
    (FROM_ (table_or_subquery | join_clause))?
    (WHERE_ expr)?
    returning_clause?
;

column_name_list:
    OPEN_PAR column_name (COMMA column_name)* CLOSE_PAR
;

qualified_table_name:
    table_name (AS_ alias)?
    (INDEXED_ BY_ index_name | NOT_ INDEXED_)?
;

order_by_stmt:
    ORDER_ BY_ ordering_term (COMMA ordering_term)*
;

limit_stmt:
    LIMIT_ expr ((OFFSET_ | COMMA) expr)?
;

ordering_term:
    expr
    (COLLATE_ collation_name)?
    asc_desc?
    (NULLS_ (FIRST_ | LAST_))?
;

asc_desc:
    ASC_
    | DESC_
;

// unknown

column_alias:
    IDENTIFIER
    | STRING_LITERAL
;

keyword:
    ABORT_
    | ACTION_
    | ADD_
    | AFTER_
    | ALL_
    | ALTER_
    | ANALYZE_
    | AND_
    | AS_
    | ASC_
    | ATTACH_
    | AUTOINCREMENT_
    | BEFORE_
    | BEGIN_
    | BETWEEN_
    | BY_
    | CASCADE_
    | CASE_
//    | CAST_
    | CHECK_
    | COLLATE_
    | COLUMN_
    | COMMIT_
    | CONFLICT_
    | CONSTRAINT_
    | CREATE_
    | CROSS_
//    | CURRENT_DATE_
//    | CURRENT_TIME_
//    | CURRENT_TIMESTAMP_
    | DATABASE_
    | DEFAULT_
    | DEFERRABLE_
    | DEFERRED_
    | DELETE_
    | DESC_
    | DETACH_
    | DISTINCT_
    | DROP_
    | EACH_
    | ELSE_
    | END_
    | ESCAPE_
    | EXCEPT_
    | EXCLUSIVE_
    | EXISTS_
    | EXPLAIN_
    | FAIL_
    | FOR_
    | FOREIGN_
    | FROM_
    | FULL_
    | GLOB_
    | GROUP_
    | HAVING_
    | IF_
    | IGNORE_
    | IMMEDIATE_
    | IN_
    | INDEX_
    | INDEXED_
    | INITIALLY_
    | INNER_
    | INSERT_
    | INSTEAD_
    | INTERSECT_
    | INTO_
    | IS_
    | ISNULL_
    | JOIN_
    | KEY_
    | LEFT_
    | LIKE_
    | LIMIT_
    | MATCH_
    | NATURAL_
    | NO_
    | NOT_
    | NOTNULL_
    | NULL_
    | OF_
    | OFFSET_
    | ON_
    | OR_
    | ORDER_
    | OUTER_
    | PLAN_
    | PRAGMA_
    | PRIMARY_
    | QUERY_
    | RAISE_
//    | RECURSIVE_
    | REFERENCES_
    | REGEXP_
    | REINDEX_
    | RELEASE_
    | RENAME_
    | REPLACE_
    | RESTRICT_
    | RIGHT_
    | ROLLBACK_
    | ROW_
    | ROWS_
    | SAVEPOINT_
    | SELECT_
    | SET_
    | TABLE_
    | TEMP_
    | TEMPORARY_
    | THEN_
    | TO_
    | TRANSACTION_
    | TRIGGER_
    | UNION_
    | UNIQUE_
    | UPDATE_
    | USING_
    | VACUUM_
    | VALUES_
    | VIEW_
    | VIRTUAL_
    | WHEN_
    | WHERE_
    | WITH_
    | WITHOUT_
    | FIRST_VALUE_
    | OVER_
    | PARTITION_
    | RANGE_
    | PRECEDING_
    | UNBOUNDED_
    | CURRENT_
    | FOLLOWING_
    | CUME_DIST_
    | DENSE_RANK_
    | LAG_
    | LAST_VALUE_
    | LEAD_
    | NTH_VALUE_
    | NTILE_
    | PERCENT_RANK_
    | RANK_
    | ROW_NUMBER_
    | GENERATED_
    | ALWAYS_
    | STORED_
    | TRUE_
    | FALSE_
    | WINDOW_
    | NULLS_
    | FIRST_
    | LAST_
    | FILTER_
    | GROUPS_
    | EXCLUDE_
;

// TODO: check all names below

function_name:
    any_name
;

table_name:
    any_name
;

column_name:
    any_name
;

collation_name:
    any_name
;

index_name:
    any_name
;

table_alias:
    any_name
;

alias:
    any_name
;

any_name:
    IDENTIFIER
    | keyword
    | STRING_LITERAL
    | OPEN_PAR any_name CLOSE_PAR
;
