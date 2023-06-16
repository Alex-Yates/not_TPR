# HOW THE BUILDS WORK

This directory contains a standard set of build scripts that can be used to deploy a set of Flyway projects for SQL Server database migrations.

These scripts were designed with a three specific challenges in mind:

1. The database is *intentionally* different in the various different environemnts (DEV, UAT, PROD) etc, so a conventional deployment process where the same project is deployed to all environments was considered out of scope. Instead, it was expliccitely decided that the scripts for each environment should be managed independently.
1. Some production databases use a 3rd party app that routinely drops objects (including tables) that aren't maintained by the third party app. This is a problem for Flyway because it deploys a Flyway_Schema_History table to the target database (including production) to keep track of which migrations have already been executed. When third party apps drop the Flyway_Schema_History data, and we do not do anything to mitigate it, the next Flyway deployment will fail.
1. The DBA team wants to ensure all DDL changes are reviewed, but they do not wish to review DML scripts. The developers spend a significant portion of their time with DML only scripts, and they do not want their work to be slowed down by unnecessary delays. Hence, it's necessary to differentiate between the scripts that contain DDL, and the scripts that only contain DML.

Below is:
- a brief overfiew of how Flyway works.
- a brief overview of how each of these challenges are solved.
- a more detailed technical description of each of the scripts in the build directory.

## How Flyway works
Flyway is a migration script runner for SQL Server and most other RDBMS platforms. In a flyway project the most important features are:
- *The flyway.conf file*: specifies various details, including the connection string to the target database, and the locations where any sql scripts are stored.
- *The migrations folder*: which holds the database migrations scripts. By default, the migrations are stored in a folder called "migrations" in the flyway root. In our case, we save our scripts in either migrations/DDL or migrations/DML.
The SQL scripts have a specific naming convention. For example, V01_2_3__NewTable.sql tells Flyway that:
- (V) this is a standard migration script. (Other options are "B" for baseline and "U" for undo).
- (01_2_3) this script is for version 01.2.3
- (NewTable) the description is "NewTable"
When executing a deployment, Flyway queries the Flyway_Schema_History table on the target database to find ou which scripts have already been deployed. It then executes any scripts in the migrations folder that have not yet been deployed to the target database.

For more detailed information about how Flyway works, you can find the official documentation here:
https://documentation.red-gate.com/fd

## Challenge 1: Independently managed environments
This repository is for a specific database. In the root of the repo there is a folder called "build" which defines a standard build process to deploy this database to each environment. Additionally, in the root, are multiple additional directories called things like "DEV", "QA", and "PROD". These environment directories hold the Flyway projects that deploy this database, to the specified environments. The build scripts can be executed with a parameter (FlywayRoot) which can be used to specify which Flyway project to deploy ("DEV" or "QA" etc).

We did consider using git branches to achieve this. However, since the branches are never going to be merged back together, the use of git branches adds unnecessary complexity while offering little additional value.

We also considered tryign to standardise all environemtns to use a single Flyway project for consistency. While this would be tremendously beneficial, this seemed like a significant technical challenge. It was decided, as a first step, to start using Flyway, GitHub and Jenkins in the simplest possible way. This brings the benefit of source control, automation, and change management, while providing the team an opportunity to learn the new tooling and technology, before embarking on potential future improvements.

## Challenge 2: Disappearing Flyway_Schema_History tables
If the Flyway_Schema_History table is deleted on the target database, and we do nothing to mitigate it, any Flyway deployments will fail. We considered strategies to protect the Flyway_Schema_History table from deletion, but ultimately were unconfident they would be effective. Instead we decided to effectively backup the table and store it elsewhere. To do this, we use sp_generate_merge, which is available here:
https://github.com/readyroll/generate-sql-merge/blob/master/master.dbo.sp_generate_merge.sql

Following every deployment, Flyway uses sp_generate_merge to script out the data in the Flyway_Schema_history table. We then commit this script back to source control. We are aware that it's a bit of an antipattern for our builds to commit back to source control, but it works pretty well, and it's convenient to have the history data in the Flyway project next to the code. This implementation also has a handy side-affect that the git history for the history data script effectively acts as a deployment log for anyone who cannot access either the target database or Jenkins.

Before the next deployment, our build process first verifies whether the history table exists in the target database and, if not, it redeploys it, along with all the history data that we backed up following the previous deployment.

We also considered storing the flyway_schema_history table on a different database, but this did not work. We tried using a synonym on the target database that pointed to a flyway_schema_history table on a different database (it's easier to redeply this as a predeploy step, than it is to redeploy a whole table an it's data!), but this didn't work either. After the failed synonym attempt we switched to the solution described above. However, we have since learned that if we had used a View, rather than a Synonym, this would have worked. Potentially, using a View to hide our Flyway_Schema_History table in a different database would have been a simpler solution and it's something to consider for a future iteration. It would certainly be simpler and may be much simpler to maintain. However, there are concerns about this. Using a View like this is not officially supported and senior engineers at Redgate (the Flyway vendor) seem unsure about why this strategy works for Views, but not for Synonyms. Given the lack of support or any clarity from Redgate about why it even works, I'm skeptical about how safe it is to assume it will continue to work in the future.

## Challenge 3: DML vs DDL
Within the migrations folder in each Flyway root are two subdirectories. One for DML, and another for DDL. Developers should put their scripts in the appropriate directory. Scripts in the DML directory will not be flagged for DBA review, but scripts in the DDL directory will be flagged for review.

This is all very well and good, but there remains a concern that a developer may (accidentally, one would assume) put a DDL script into the DML directory and inadvertantly bypass the review. It therefore remains necessary to verify that none of the scripts in the DML directory contain DDL statements.

Parsing T-SQL for DDL is notoriously tricky. For example "CREATE TABLE dbo.RealTable" is DDL, but "CREATE TABLE #tempTable" is not. With this in mind, we decided against any form of text parsing. Instead, we adopt a strategy of executing all the pending migrations against a temp test database, and we execute the DML scripts as a user that only has datareadwriter permissions. If any of the DML scripts fail on the test database, that's either a sign that the script contains DDL, or that there is an error in the code. In either case, it's a good job we caught the issue early, before the DBA review or any production deployments.

## Technical overview of the scripts in this directory

### flyway-migrate.jenkinsfile <<< --- START HERE
This is effectively a coordinator file. The one script to rule them all. We give it to Jenkins and Jenkins uses it to interpret what it needs to do.

The JenkinsFile is divided into 3 key sections:

- *agent*: specifies which build agent(s) the scripts should run on.
- *parameters*: values specified by the Jenkins user when they trigger a job. For example, "FLYWAYROOT" specifies the relative path to the flyway project. (Effectively allowing the Jenkins user to select the "DEV" or "QA" projects.)
- *stages*: the things Jenkins will do. Effectively, running four scripts: pre-deploy.ps1, migrate.ps1, testForDDL.ps1, and update_fsh_data.ps1

### functions.psm1
Contains a few helper PowerShell functions that are referenced by the other scripts. Moving al our functions to the psm1 file reduces duplication and helps to keep the other PowerShell scripts shorter and simpler.

### pre-deploy.ps1, create_flyway_schema_history_table.sql, and sp_generate_merge.sql
pre-deploy.ps1 does the following prep work ahead of the Flyway deployment:

1. Verifies that sp_generate_merge exists on the target database. If not, it deploys it (using sp_generate_merge.sql). This ensures deployments work, regardless of whether the project has been deployed before, or whether sp_generate_merge has since been dropped on the target server.
1. Verifies the flyway_schema_history table exists on the target database. If not, it redeploys it. If a flyway_schema_history_data.sql script exists in the flyway root (see update_fsh_data.ps1, below), this script is used to populate the flyway_schema_history table with the deployment history data.

### migrate.ps1 and 
Runs flyway to perform the actual migration. Scripts saved in "DDL" directories are executed as the default jenkins user (which has admin credentials). Hence, any scripts added to this directory should be reviewed by a DBA. Any other database scripts are executed as a temporary DML only login. These scripts cannot execute DDL changes, and hence do not need to be reviewed by DBAs.

### update_fsh_data.ps1
Uses sp_generate_merge.sql to script out the flyway_schema_history data and saves it to a flyway_schema_history_data.sql in the flyway root. Then commits and pushes any updates back to source control so that it's safe and ready for future deploys.

## To Do: Remaining tasks
1. Clean up the code. (This version works, but I've gone down a few rabbit holes along the way, and there is probably some redundant code lying around. Also, COMMENTS!)
1. Update all conf files.
1. Update migrate (and any other flyway calls) to us the locations and url from the flyway.conf file
1. Make the DML user the default, and only use sa if explicitly DML. (What if someone adds another folder?)
1. What if someone grants more creds to the dml_only user login in between builds? Should we drop/recreate it? Should we update permissions during build to explicitly deny DDL?
1. Clean up old temp DBs.
1. Ensure that diff reports are not being commited to source control following the info command in testFortDDL.ps1
