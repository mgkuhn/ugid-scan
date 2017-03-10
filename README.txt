ugif-scan/filer
---------------

Markus Kuhn

ugid-scan/filter is a simple search engine for locating files in NFS
exports of the departmental filer "elmer" that have certain undesired
uid or gid values. It is an aide to help with renumbering historic or
accidental uid/gid assignments, towards implementing the number
allocation scheme described at

  https://wiki.cam.ac.uk/cl-sys-admin/UID/GID_allocation

The tool consists of two components: ugig-scan and ugid-filter

A) ugid-scan

This tool crawls elmer's NFS directories /Nfs/Mounts/elmer-vol[0-9]
and builds an index file ugid-list, which contains the pathnames of
all directories that contain files with certain uid or gid values.

The index only covers problematic historic/accidental uid/gid ranges
that need cleanup, and is therefore not intended as a general-purpose
search tool. It ignores files with uid and gid values that follow the
above allocation scheme.

A typical scan takes a bit over 24 hours.

ugid-scan should be run periodically (e.g., each Saturday morning) as
root from a machine with the following properties:

  - Non-Kerberized root access to elmer, such that all directories and
    file inodes can be read without access control

  - NFSv3 mounts, such that numeric uid and gid can be acquired
    without any LDAP/idmapd-dependent conversions

  - Mount option "nodiratime" or "noatime" should be set for
    /Nfs/Mounts/elmer-vol*, otherwise the scan will update the access
    time field in the inode of every directory scanned, which can
    create additional backup load

ugid-scan currently has no command-line options and writes three files
into the current working directory:

  ugid-list   is the index of files created, about 0.5 gigabytes long

  ugid-list~  is the temporary name of ugid-list while it is written
              (to be renamed into ugid-list when finished)

  ugid-log    is a progress-report log file that indicates how much
              time the scan spent in various parts of the name space

B) ugid-find

This tool reads ugid-list and performs queries on it. It accepts a
sequence of commands on the command line. There are two types of
commands. Selection commands perform queries and deposit lists of
pathnames on a stack. Output commands print the list of pathnames on
the stack in different forms.

Selection commands:

  uiddir=<range1>  select all directories that contain (as an immediate
                   child node) a file and directory owned by a uid
                   in the integer range <range1>

  giddir=<range2>  select all directories that contain (as an immediate
                   child node) a file and directory belonging to a
                   gid in the integer range <range2>

  uid=<range1>     select all files and directories owned by a uid in <range1>

  gid=<range2>     select all files and directories with gid in <range2>

  uid=<range1>:<range2>
                   select all files or directories owned by a uid in <range1>
                   that also have a gid in <range2>

  gid=<range1>:<range2>
                   select all files or directories with gid in <range2>
                   that also have a uid in <range1>

The output of uid=<range1>:<range2> and gid=<range1>:<range2> should
be identical, but the runtime may differ due to different search
strategies. Prefer uid=<range1>:<range2> if you expect the output of
uiddir=<range1> to be small and use gid=<range1>:<range2> if you
expect the output of giddir=<range2> to be small.

A <range> can be a comma-separated list of ids or id-ranges (with
hyphen), or it can be a single numeric id or range prefixed with ^
meaning "not". Example ranges are "101,110-115,10000-", "^3600" and
"^3600-3609".

Note that the tool deliberately does not use any symbolic group user
or group names from the getent or LDAP "passwd" and "group" tables.
This is to avoid accidents by ambiguities in the assignment of these
names.

Output commands:

  print            output all pathnames on stack as LF-terminated strings

  print0           output all pathnames on stack as NUL-terminated strings
                   (for piping into "xargs -0r")

  ll               output all pathnames with "ls -lnd"

  count            output the length of the pathname lists on the stack


Usage examples:

$ ./ugid-find uid=101 count

$ ./ugid-find gid=^3601:3601 ll

$ ./ugid-find gid=^3601:3601 print0 | xargs -0r ls -lnd

$ ./ugid-find gid=^3601:3601 print0 | xargs -0r chgrp -hc 9601

