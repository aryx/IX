\title{chidb}{1}{apps}

# NAME
chidb – a small SQL database

# SYNOPSIS
**chidb** \[ **-c** *command* ] \[ **-v** ] \[ **-h** ] \[ *database* ]

# DESCRIPTION
*Chidb* is the twin of chidb, the database written for teaching at the
University of Chicago: SQL compiled to a program for a register
machine, which runs it over B-trees of pages of a fixed size, in one
file, the *database*.

It reads a statement a line from the standard input, after the prompt
`chidb>`, until the input ends; the rows of a query are written one a
line, their values separated by `|`. The prompt is written even when
the input is not a terminal, as chidb's is.

**-c** *command*
:    The one statement or command run, and no prompt.

**-v**
:    What it does, said on the standard error; given twice, more.

**-h**
:    chidb's line of usage. **--help** says more, with examples.

The SQL it compiles: `CREATE TABLE`, `CREATE INDEX` on one column,
`INSERT INTO ... VALUES`, and `SELECT` from one table or from a
`NATURAL JOIN` of two, its `WHERE` comparisons of a column with a value
joined by `AND`. A `WHERE` on an indexed column is a seek in the index,
any other a scan of the table. `EXPLAIN` before a statement writes its
program instead of running it.

A line starting with a dot is a command of the shell's:

`.open` *file*
:    Another database.

`.headers on`
:    The columns' names before the rows.

`.mode column`
:    The values in columns of 10 letters, not separated by `|`.

`.parse "`*sql*`"`, `.opt "`*sql*`"`
:    The statement's tree, and the tree the optimizer made of it.

`.help`
:    The commands.

# EXAMPLES
```
chidb books.cdb
chidb> CREATE TABLE books (id INTEGER PRIMARY KEY, title TEXT, year INTEGER);
chidb> INSERT INTO books VALUES (1, 'SICP', 1985);
chidb> SELECT * FROM books WHERE year > 1980;
1|SICP|1985
chidb -c 'SELECT title FROM books;' books.cdb
```

# DIAGNOSTICS
A statement that is not read, or that the compiler does not do, is
`SQL syntax error.` on the standard output, as chidb says it.

# BUGS
As chidb's: `DELETE` is read but not compiled (its machine and its
B-tree have no deletion), and `UPDATE` not read: both are `SQL syntax
error.` A `WHERE` with an `OR`, or comparing two columns, is too.
