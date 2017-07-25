# pdbkup
Parallel Distributed Backup

# Dependencies
* [GNU Parallel](https://www.gnu.org/software/parallel/)
* [DAR](http://dar.linux.free.fr/)
* [Globus CLI](https://github.com/globus/globus-cli)
* The filesystem to be backed up implements snapshots AND
  snapshots are actively being produced.
### Automatically included dependencies
There are some other git projects this code makes use of.  They are included as
submodules and will be included automatically when this repo is cloned (hence
the `--recursive` option to clone).  They are documented here to give credit to
the authors of those projects.
* https://github.com/rudimeier/bash_ini_parser
* https://github.com/pixelb/crudini

# Installation
1. `cd <INSTALL PATH>`
1. `git clone --recursive https://github.com/ncsa/pdbkup.git`
1. Update *PDBKUP_BASE* with value of *INSTALL_PATH* in file `bin/run.sh`
1. Review settings in `conf/settings.ini` (see the Configuration section below)

# Usage
## Create backups
```
# SCAN FILESYSTEM, CREATE FILELIST, CREATE PARALLEL JOBLIST
[root@lsst-backup01 ~]# /gpfs/fs0/DR/pdbkup/bin/run.sh bkup init
 
# START WORKERS ON MULTIPLE NODES
[root@adm01 ~]# xdsh backup01,test[09-10] /gpfs/fs0/DR/pdbkup/bin/run.sh bkup startworker
 
# SEE WHAT WORKERS ARE DOING
[root@adm01 ~]# xdsh backup01,test[09-10] /gpfs/fs0/DR/pdbkup/bin/run.sh bkup ps
 
# CHECK OVERALL PROGRESS
[root@lsst-backup01 ~]# /gpfs/fs0/DR/pdbkup/bin/run.sh bkup status 
 
# LIST CURRENT AND HISTORICAL BACKUPS
[root@lsst-backup01 ~]# /gpfs/fs0/DR/pdbkup/bin/run.sh bkup ls
 
# CHECK PROGRESS OF PARALLEL TASKS
[root@lsst-backup01 ~]# /gpfs/fs0/DR/pdbkup/bin/run.sh bkup dbstatus
 
# GET USAGE SYNOPSIS
[root@lsst-backup01 fs0]# /gpfs/fs0/DR/pdbkup/bin/run.sh bkup
```

## Transfer backups into long term storage
```
# CREATE NEW TRANSFER TASK CONTAINING ALL FILES READY TO TRANSFER
[root@lsst-backup01 fs0]# /gpfs/fs0/DR/pdbkup/bin/run.sh txfr startnew
 
# MONITOR ACTIVE TRANSFERS
[root@lsst-backup01 fs0]# /gpfs/fs0/DR/pdbkup/bin/run.sh txfr ls
 
# RENEW ENDPOINT CREDENTIALS (if needed)
[root@lsst-backup01 fs0]# /gpfs/fs0/DR/pdbkup/bin/run.sh txfr update-credentials

# VIEW TXFR USAGE SYNOPSIS
[root@lsst-backup01 fs0]# /gpfs/fs0/DR/pdbkup/bin/run.sh txfr
```

## Cleanup
```
# PURGE OLD FILES (only successfully transferred files)
[root@lsst-backup01 fs0]# /gpfs/fs0/DR/pdbkup/bin/run.sh txfr clean
 
# CLEAN UP (TASK QUEUE) DATABASES
[root@lsst-backup01 fs0]# /gpfs/fs0/DR/pdbkup/bin/run.sh bkup dbclean
 
# PURGE OLD FILES NO LONGER NEEDED (ARCHIVES TRANSFERRED TO LONG TERM STORAGE)
[root@lsst-backup01 fs0]# /gpfs/fs0/DR/pdbkup/bin/run.sh bkup purge
```

# Configuration
All configuration is managed through the single file `config/settings.ini`.
Below is a description of each section and related settings.
## GENERAL
* DATADIR
  * A directory structure will be created here inside of which will be stored
    all the temporary DAR archive files (before they transfer to long term
storage), task queues (that will be used by parallel). Ensure DATADIR is
a location that has enough capacity; which should be at least as large as all
the data that will be backed up.
* INFODIR
  * A directory structure will be created here that will store all the
    permanent information about each backup.  Everything below here defines
state or status of each backup as well as information necessary for restores.

## GLOBUS
* ENDPOINT_LOCAL
  * Name or UUID of local endpoint
  * local endpoint should have access to the `DATADIR` from the `General` section
    (above)
* ENDPOINT_REMOTE
  * Name or UUID of remote endpoint
  * The offsite location where disaster recovery files will be transferred to
* BASEDIR_REMOTE
  * Directory under which the archives should be stored
  * On the remote side, directories will be created as necessary to create
    a logical structure for the archive files.
* USERNAME
  * Access globus as this user
* CLI
  * Path to local `globus` command

## PARALLEL
GNU Parallel uses a database for a task queue.  This section defines how to
interact with the database. Not all fields will be used; leave blank any irrelevant fields.  For instance,
if using sqlite3, then user, pass, host, port will be empty (likewise for csv).

* DB_VENDOR
* DB_USER
* DB_PASS
* DB_HOST
* DB_PORT
* DB_DBNAME
* DB_TABLE
* WORKDIR
  * Directory in which csv or sqlite file will be stored.
  * Will be automatically created inside `DATADIR` (from the `General` section
    above)
* MAX_PROCS
  * How many processes to run in parallel on each node
* MIN_VERSION = 20170222
  * Minimum required version of parallel.
  * Options `--sqlmaster` and `--sqlworker` are relatively new and don't work 
    well before Jan 2017.  Change this only at your own risk.

For more information and for a list of valid strings for DB_VENDOR, see:
* [GNU Parallel option --sqlmaster](https://www.gnu.org/software/parallel/man.html)
* [Saving to an SQL base (advanced)](https://www.gnu.org/software/parallel/parallel_tutorial.html#Saving-to-an-SQL-base-advanced)


## DAR
* CMD
  * Path to dar binary/executable
No need to change anything else in this section.

## PAR
Unused for now. Possible future enhancement.

## TXFR
No need to change anything in this section.

## PURGE
No need to change anything in this section.

## DEFAULTS
These are defaults that apply to the DIRS that will be backed up. Most often,
all the dirs to be backed up are all part of the same filesystem or same type
of filesystem, so it suffices to set relevant settings in one place.
* SNAPDIR
  * Name of snapdir, relative to the DIR path
* SNAPDIR_DATE_FORMAT
  * If each snapshot has a date as part of it's name, specify that format here
  * Syntax is same as used by the `date` command
* ARCHIVE_MAX_SIZE
  * Size limit, in Bytes, of a single archive file
* ARCHIVE_MAX_SIZE=536870912000
* ARCHIVE_MAX_FILES 
  * maximum number of files in a single archive
  * Adjust this based on median file size in the DIR
  * so that archive files can reach ARCHIVE_MAX_SIZE
  * Make this higher for filesystems with lots of small files

Any of these defaults can be overridden on a per DIR basis by creating
a section matching the name of the KEY in the `DIRS` section and then put the
new setting and value in that section.  It will apply only to that DIRKEY

## DIRS
* Create a unique "key" for each filesystem that needs to be backed up
* The value for each "key" is the absolute path to the mountpoint

There are additional comments and examples in the default `conf/settings.ini`
file.
