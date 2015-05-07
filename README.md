# NAME

Mojolicious::Command::migration — MySQL migration tool for Mojolicious

# VERSION

version 0.12

# SYNOPSIS

     Usage: APPLICATION migration [COMMAND] [OPTIONS]
    
       mojo migration prepare
     
     Commands:
       status     : Current database and schema version
       install    : Install a version to the database.
       prepare    : Makes deployment files for your database
       upgrade    : Upgrade the database.
       downgrade  : Downgrade the database.
    

# DESCRIPTION

[Mojolicious::Command::migration](https://metacpan.org/pod/Mojolicious::Command::migration) MySQL migration tool.

# USAGE

[Mojolicious::Command::migration](https://metacpan.org/pod/Mojolicious::Command::migration) uses app->db for mysql connection and following configuration:

    {
      'user'       => 'USER',
      'password'   => 'PASSWORD',
      'datasource' => { 'database' => 'DB_NAME'},
    }

from

    $ app->config->{db}->{mysql}

All deploy files saves to relative directory 'share/'. You can change it with 'MOJO\_MIGRATION\_SHARE' environment.
Current project state saves to 'tmp/.deploy\_status' file. You can change directory with 'MOJO\_MIGRATION\_TMP' environment.

Note: we create directories automatically

# COMMANDS

## status

    $ app migration status
    Schema version: 21
    Deployed database is 20

Returns the state of the deployed database (if it is deployed) and the state of the current schema version. Sends this as a string to STDOUT

## prepare

Makes deployment files for the current schema. If deployment files exist, will fail unless you "overwrite\_migrations".

    # have changes
    $ app migration prepare
    Schema version: 21
    New version is 22
    Deploy to 22
    
    # no changes
    $ app migration prepare
    Schema version: 21
    Nothing to upgrade. Exit

## install

Installs either the current schema version (if already prepared) or the target version specified via any to\_version flags.

If you try to install to a database that has already been installed (not empty), you'll get an error. Use flag force to set current database to schema version without changes database.

    # last
    $ app migration install
    Schema version: 21
    Deploy database to 21
    
    # target version
    $ app migration install --to-version 10
    Schema version: 21
    Deploy database to 10

    # force install
    $ app migration install --force
    Schema version: 21
    Force deploy to 21

## upgrade

Use flag --force to set current database to schema version without changes database.

    # last
    $ app migration upgrade
    Schema version: 21
    Database version: 20
    Upgrade to 21
    
    # target version
    $ app migration upgrade --to-version 10
    Schema version: 21
    Database version: 8
    Upgrade to 10

    # force upgrade
    $ app migration upgrade --force
    Schema version: 21
    Database version: 8
    Force upgrade to 21

## downgrade

Use flag --force to set current database to schema version without changes database.

    # last
    $ app migration downgrade
    Schema version: 21
    Database version: 20
    Downgrade to 21
    
    # target version
    $ app migration downgrade --to-version 10
    Schema version: 21
    Database version: 8
    Downgrade to 10

    # force downgrade
    $ app migration downgrade --force
    Schema version: 21
    Database version: 8
    Force downgrade to 21

# Custom upgrade and downgrade

You can customize upgrade and downgrade by adding additional SQL scripts to path of action. All scripts will be executed in alphabetical order.

    # share/migration/MySQL/upgrade/10-11/001_auto.sql is automatic
    # share/migration/MySQL/upgrade/10-11/002_some_script.sql is additional sctipt
    $ app migration upgrade
    Schema version: 11
    Database version: 10
    Upgrade to 11
    Exec file: share/migrations/MySQL/upgrade/10-11/001_auto.sql
    Exec file: share/migrations/MySQL/upgrade/10-11/002_some_script.sql

# SOURCE REPOSITORY

[https://github.com/likhatskiy/Mojolicious-Command-migration](https://github.com/likhatskiy/Mojolicious-Command-migration)

# AUTHOR

Alexey Likhatskiy, <likhatskiy@gmail.com>

# LICENSE AND COPYRIGHT

Copyright (C) 2015 "Alexey Likhatskiy"

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.
