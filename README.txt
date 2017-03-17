ugid-scan/find
--------------

Markus Kuhn

ugid-scan/find is a simple search engine for locating files that have
certain undesired uid or gid values. Its main purpose is to help with
renumbering historic or accidental uid/gid assignments.

The tool consists of two components: ugid-scan and ugid-filter

A) ugid-scan

This tool crawls one or several directories (without following
symbolic links) and builds an index file "ugid-list.sdb" that contains
the pathnames of all directories that contain files with uid or gid
values that have not been excluded by options -u and -g.

Best run ugid-scan as root. Where NFS filesystems are scanned,
preferably mount using NFSv3 exports without root squash.

Run "ugid-scan --help" for command-line options.

B) ugid-find

This tool reads ugid-list.sdb and performs queries on it.

Run "ugid-find --help" for command-line options.
