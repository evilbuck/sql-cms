# dpl-cms

This is a general-purpose application for creating per-Customer Workflows of interdependent SQL Transforms that convert a set of Import DataFiles on S3 to a set of Export DataFiles on S3.

A Workflow may be Run multiple times, and each time the system will deposit its Export DataFiles in a namespaced S3 "directory". Every Run occurs within a newly-created Postgres (or, soon, Redshift) schema.

The following entities exist in the **public** Postgres (or, soon, Redshift) schema:

- **User**: You, the SQL Analyst

- **Customer**: The Customer with which every Workflow and DataFile must be associated

- **DataFile**: Comes in 2 varieties:

  - **Import DataFile**: A specification of the location of a tabular flat-file that already exists on S3 (e.g. a CSV file)

  - **Export DataFile**: A specification of the desired location to which the system will write a tabular flat-file on S3 (e.g. a CSV file)

- **Workflow**: A named, per-Customer collection of the following, each described in detail below:

  - Various types of SQL Transform and their TransformDependencies, TransformValidations, and (for some types of Transform) DataFiles

  - DataQualityReports

  - Notifications

  - Runs and their RunStepLogs

- **Notification**: An association of a Workflow with a User for the purpose of notifying the User whenenever a Run of that Workflow successfully or unsuccessfully completes.

- **Transform**: A named, optionally-parametrized SQL query that may be optionally associated with an Import or Export DataFile and that specifies one of the following Runners for the SQL:

  - **RailsMigrationRunner**: Evals the contents of the sql field as a Ruby Migration (because hand-writing boilerplate DDL sucks); supports every feature that Rails Migrations support

  - **CopyFromRunner**: Requires association with an Import DataFile, and requires that its sql field be a `COPY ... FROM STDIN ...` type of SQL statement

  - **SqlRunner**: Allows its sql field to be any type of DDL statement (CREATE) or DML statement (INSERT, UPDATE, DELETE, but not SELECT, since that would be pointless) other than those that read from or write to files.

  - **CopyToRunner**: Requires association with an Export DataFile, and requires that its sql field be a `COPY ... TO STDOUT ...` type of SQL statement

  - **AutoLoadRunner**: **Not yet implemented** - Will require only an association to an Import DataFile, and will introspect on the DataFile's header, create a table with string columns based upon the sql-identifier-coerced version of the headers, and load the table from the file.

  - **UnloadRunner**: **Not yet implemented** -  Will be a Redshift-specific version of CopyToRunner

- **TransformDependency**: An association of one Transform with another where the Prerequisite Transform must be run before the Postrequisite Transform.  Every Workflow has a TransformDependency-based DAG that is resolved at runtime into a list of groups of Transforms, where each Transform in a group may be run in parallel

- **TransformValidation**: An association of a Transform to a parameterized Validation that specifies the parameters required for the Validation.  When a TransformValidation fails, that Transform is considered to have failed, and execution halts in failure after that Transform's group completes.

- **Validation**: A named, reusable, manditorily-parametrized SQL query that validates the result of a Transform, e.g. to verify that all rows in a table have a value for a given column, are unique, reference values in another table, etc.  Similar in intent to Rails Validations.  Upon failure, returns the IDs of all invlalid rows.

- **DataQualityReport**: A named, optionally-parametrized SELECT SQL statement that is run after all Transforms have completed.  The system will store the tabular data returned by the SQL as well as include that data in the Notification email that is sent after a successful Run.

- **Run**: A record of the postgres-schema_name, current status, and execution_plan of a given Run of a Workflow.  When a User creates a Run for a Workflow, the system serializes the Workflow and *all* its dependent objects into the execution_plan field, and execution of the Run proceeds against that field.  This allows a Workflow to be changed at any time without affecting any current Runs.

- **RunStepLog**: A per-Run record of the execution of a single Transform or DataQualityReport that in success cases stores the result of running the SQL and in failure cases either stores TransformValidation failures or - in the case of an Exception being raised - the error message

## Environment Setup for local development

As cribbed from the clarity repo, to get the DPL CMS running natively on your local machine:

1) Install XCode from the Apple App Store - you need it to build native extensions of plugins and gems.

2) Install Homebrew - you need it to manage package installation and updates

  * Go to http://brew.sh/ and follow the installation instructions.
  * When prompted, install XCode command line tools.
  * At the end of the installation, run `brew doctor` as instructed.

3) Install Postgres version 9.4.x - you need the 9.4.x line because our other apps are using 9.4 in production

  * If you have one (or more!) previous version(s) of Postgres installed **and** you don't care about saving any data, first do the following for every previous version you have, substituting your version(s) for 9.3:

  ```
  sudo /Library/PostgreSQL/9.3/uninstall-postgresql.app/Contents/MacOS/installbuilder.sh
  ```

    Then, nuke the data folders and the stupid, useless ini file:

  ```
  sudo rm -rf /Library/PostgreSQL
  sudo rm /etc/postgres-reg.ini
  ```

    If you need to save data and upgrade it into your 9.4 installation, you're on your own, though you'll start by googling `pg_upgrade`

  * If you don't already have Postgres installed on your machine you can try these two options:


    * Use the "Graphical installer" from http://www.postgresql.org/download/macosx/

      * It may need to resize shared memory and reboot your system before continuing; that's OK

      * Accept all the defaults you're prompted for

      * When prompted, set the password for the postgres user as: test123

      * At the end of the RDBMS installation, do *not* install StackBuilder - you don't need it

      * After installation, you might need to add Postgres to your PATH variable: `export PATH=/Library/PostgreSQL/9.4/bin:$PATH`

      * If you want to easily type `psql` and be logged in and have your DB set to dpl-cms:

        * Create the file ~/.pgpass with these contents: `*:*:*:postgres:test123`

        * Add the following alias to your shell config file (.bashrc, .zshrc, etc): `alias psql='psql -Upostgres -w -d dpl_cms_development`

    * Or install version 9.4.x from http://postgresapp.com

        Then add `/Applications/Postgres.app/Contents/Versions/9.4/bin` to your $PATH.

    The data management Rake task use Postgres command-line utilities (`pg_dump`, most importantly), so make sure the correct version is in your $PATH by running `pg_dump --version`.

4) Install Redis

  ```
  brew install redis
  brew services start redis # to automatically run it at startup
  ```

  Note: The test and development environments use different redis databases, so when using the `redis-cli` command line interface remember to select proper one:

  ```
  redis-cli -n 0 // for development
  redis-cli -n 1 // for test
  ```

5) Install git and git bash completion: `brew install git bash-completion`

  * Follow instructions nested in the output of the above to add auto-loading of git bash completion in your .bashrc

6) Clone the git repo:

  ```
  git clone https://github.com/brightbytes/dpl-cms.git
  ```

  Or use ssh if you prefer (You will need to generate an ssh key first. Instructions can be found here: https://help.github.com/articles/generating-an-ssh-key/)

  ```
  git clone git@github.com:brightbytes/dpl-cms.git
  ```

 Configure git:

  In the dpl-cms repo directory, substitute the correct values and run the following:

  ```
  git config --global user.name "Your Name"
  git config --global user.email "you@brightbytes.net"
  ```

  Also, these configurations are required at Brightbytes:

  ```
  git config --global branch.master.mergeoptions "--no-ff"
  git config --global push.default simple
  git config --global remote.origin.push HEAD
  ```

  Add the remotes to your .git/config:

  ```
  [remote "production"]
    url = git@heroku.com:dpl-cms.git
    fetch = +refs/heads/*:refs/remotes/production/*
  [heroku]
    remote = production
  ```
  Additional optional settings may be configured by running the following from the dpl-cms repo directory; feel free to review before executing:

  ```
  bin/git-config.sh
  ```

7) Install a ruby version manager (either rvm or rbenv, both described below)

  * Install rvm - you need it to manage the installed Ruby versions and gemsets

    See https://rvm.io for current instructions.  The last time I checked, they were:

    ```
    brew install gnupg gnupg2  # GnuPG
    gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3  # to verify authenticity of the download once downloaded
    \curl -sSL https://get.rvm.io | bash -s stable  # to download it
    ```

    * If you're running Lion, rvm will bitch at you to get gcc via 4 brew-related steps.  Control-C out and copy/paste those commands at the terminal prompt.

    * Deposit the following in your .bashrc (or .zshrc) and also run them now:

    ```
    export PATH=$PATH:$HOME/.rvm/bin # Add RVM to PATH so you can use it anywhere
    [[ -s "$HOME/.rvm/scripts/rvm" ]] && . "$HOME/.rvm/scripts/rvm" # Automatically prompt to install Ruby if it's not installed yet upon cd into a Ruby repo dir
    ```

    * CD into each repo you pulled down (except bb_data) and copy/paste the `rvm use` command to the terminal prompt.  If you're on on Mavericks and it fails, just run the command again, and it should succeed.

  * Or install rbenv

  ```
  brew update
  brew install rbenv
  rbenv init
  ```

  Refer to documentation at https://github.com/rbenv/rbenv for further details

## Project Setup

1) Add environment variables

  * Create a .env file in your dpl-cms project folder with the following contents:

    ```
    export PORT=3000
    export RACK_ENV=development

    # For files stored in Amazon S3
    #export S3_ACCESS_ID=
    #export S3_SECRET_ACCESS_KEY=

    # For connecting to staging Redis from your local machine
    #export OPENREDIS_URL=
    ```

  * Use [dotenv](https://github.com/bkeepers/dotenv) to import this file automatically when you enter the `dpl-cms` directory.

  * OR, simply add your .env file to your .bashrc or .bash_profile

    ```
    source ~/<path_to_your>/.env
    ```

2) Reset your environment and load Postgres with the Demo Workflow:

  ```
  rake one_ring
  ```

  Run the above script every time you want to re-initialize your dev environment to baseline.

3) Start web-servers:

  * In order to run the application in development environment you need both a web server and a sidekiq queue worker.

  * To start both unicorn and sidekiq in the same process, run:

  ```
  foreman start
  ```

  * To run them separately - which I prefer because `thin` provides more-useful logging than `unicorn` does, and I've also had `foreman` wedge my machine to the point that it could only be fixed by a rebo

  ```
  # Start thin in one terminal tab:
  rails s
  ```

  ```
  # Start sidekiq in another terminal tab:
  bundle exec sidekiq
  ```
