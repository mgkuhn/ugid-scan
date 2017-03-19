ugid-scan/find
--------------

Markus Kuhn

ugid-scan/find is a simple search engine for locating files on a POSIX
filesystem by uid and/or gid value. Its original purpose was to make
renumbering historic or accidental uid/gid assignments very easy.

The tool consists of two commands: ugid-scan and ugid-filter

The ugid-scan command crawls recursively through one or several
directory trees (without following symbolic links), in order to build
the index file "ugid-list.sdb". Depending on the size of the
filesystem, such a scan may take many minutes or hours, and might be
performed as a regular over-night cron job.

The resulting "ugid-list.sdb" index file contains for each uid and for
each gid value encountered a list of the pathnames of all directories
that contain files with that uid resp. gid value. There are two
reasons for why it stores only directory-level information about where
files with certain uids and gids are located:

  - Firstly, the index remains much smaller this way than
    if we stored information about each file encountered.

  - Secondly, the index remains useful for longer this way. Files are
    created and deleted far more often than directories, and files in
    the same directory often share the same uid:gid combinations.

Therefore, the ugid-find tool uses the directory-level index to guide
its search to certain directories, where it then searches for
individual files. This way, the ugid-find results remain more
up-to-date and reflect many of the changes that happened since the
last run of ugid-scan.

You can reduce the size of the index by using options -u and -g to
exclude certain numeric uid and gid ranges from being indexed.

Best run ugid-scan as root. Where NFS filesystems are scanned,
preferably mount using NFSv3 exports without root squash.

Run "ugid-scan --help" for command-line options of the scanner.

Run "ugid-find --help" for command-line options of the search tool.

The "uiddir" and "giddir" command options of "ugid-find" output the
content of the index, namely lists of directories in which files with
the given uids or gids are located. The "uid" and "gid" commands
search through these directories (non-recursively) and output a list
of files that match the searched values.

Very long lists of files or directories can be reduced using the
"dirnames" and "prefixes" commands, for example to get a shorter list
of starting points that can then be fed into e.g. "xargs chown".
