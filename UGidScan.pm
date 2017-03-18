package UGidScan;

use strict;

sub read_text_list {
    my ($class, $dbfn) = @_;
    my $dbf;
    my %uid;
    my %gid;
    print STDERR "Reading list '$dbfn' ...";
    open($dbf, '<', $dbfn) || die("Can't read '$dbfn': $!\n");
    local $/ = "\0\n";
    while (<$dbf>) {
	if (/\Au\s*(\d+):\s*(\d+):(.*)\0\n\z/) {
	    push @{$uid{$1}}, $3;
	} elsif (/\Ag\s*(\d+):\s*(\d+):(.*)\0\n\z/) {
	    push @{$gid{$1}}, $3;
	} else {
	    die("Unexpected record in '$dbfn':\n$_");
	}
    }
    close $dbf;
    printf(STDERR " done (%d uids, %d gids).\n",
	   scalar keys(%uid), scalar keys(%gid));
    my %db = ( uid => \%uid, gid => \%gid );
    $db{uids} = [ sort {$a <=> $b} keys %uid ];
    $db{gids} = [ sort {$a <=> $b} keys %gid ];

    return bless \%db => $class;
}

# Converts from the hash of hashes format used in ugid-scan
# into the hash of arrays format used to serialize into an index file
sub read_hash_list {
    my ($class, $uid_hash, $gid_hash) = @_;

    my %uid;
    my %gid;
    for my $u (keys %$uid_hash) {
	push @{$uid{$u}}, sort keys %{$uid_hash->{$u}};
    }
    for my $g (keys %$gid_hash) {
	push @{$gid{$g}}, sort keys %{$gid_hash->{$g}};
    }

    my %db = ( uid => \%uid, gid => \%gid );
    $db{uids} = [ sort {$a <=> $b} keys %uid ];
    $db{gids} = [ sort {$a <=> $b} keys %gid ];

    return bless \%db => $class;
}

# List all directories that contain files with uids from a given range
sub uid_range_dirs {
    my ($db, $range) = @_;
    my $filter = Filter->new($range);
    my @uids = grep { $filter->matches0($_) } @{$db->{uids}};

    # warn about searching for excluded uids
    if (exists $db->{excluded_uids}) {
	my $excluded = Filter->new($db->{excluded_uids});
	my @not_in_index = grep { $excluded->matches($_) } $filter->corners;
	warn("Warning: uids $db->{excluded_uids} were excluded during scan,\n",
	     "         which includes ", join(', ', @not_in_index), "\n")
	    if @not_in_index;
    }

    return [sort map { @{$db->{uid}{$_}} } @uids ];
}

# List all directories that contain files with gids from a given range
sub gid_range_dirs {
    my ($db, $range) = @_;
    my $filter = Filter->new($range);
    my @gids = grep { $filter->matches0($_) } @{$db->{gids}};

    # warn about searching for excluded gids
    if (exists $db->{excluded_gids}) {
	my $excluded = Filter->new($db->{excluded_gids});
	my @not_in_index = grep { $excluded->matches($_) } $filter->corners;
	warn("Warning: gids $db->{excluded_gids} were excluded during scan,\n",
	     "         which includes ", join(', ', @not_in_index), "\n")
	    if @not_in_index;
    }

    return [sort {$a cmp $b} map { @{$db->{gid}{$_}} } @gids ];
}

sub count_dirs {
    my ($db) = @_;
    my $uid_dirs = 0;
    my $gid_dirs = 0;
    for my $uid (@{$db->{uids}}) {
	$uid_dirs += scalar(@{$db->{uid}{$uid}});
    }
    for my $gid (@{$db->{gids}}) {
	$gid_dirs += scalar(@{$db->{gid}{$gid}});
    }
    return ($uid_dirs, $gid_dirs);
}

package Filter;

# Prepare a filter (uid/gid ranges) expression
#
# A numeric range expression of the form "-99,300-399,1000-"
# is converted into an array of start-end integer pairs, where
# undef means ±infinity. Example [undef=>99, 300=>399, 1000=>undef].
# Also ^ negates a range. For example the excluding range "^300-399"
# is converted into [undef=>299, 400=>undef]. A number matches a
# range if it is within at least one of the listed intervals.
sub new {
    my ($class, $exp) = @_;
    my @filter;

    for $_ (split(/,/, $exp // '')) {
	if (/^(\d+)$/) {
	    push @filter, $1 => $1;
	} elsif (/^(\d*)-(\d*)$/) {
	    push @filter, $1 => $2;
	} elsif (/^\^(\d+)$/) {
	    push @filter, (undef) => $1-1, $1+1 => undef;
	} elsif (/^\^(\d*)-(\d*)$/) {
	    push @filter, (undef) => $1-1 if  length($1);
	    push @filter,    $2+1 => undef if length($2);
	} else {
	    die("Unknown filter expression '$_'!\n")
	}
    }

    # replace empty strings with undef
    @filter = map { (defined $_ && length($_) > 0) ? $_ : undef } @filter;

    return bless [@filter] => $class;
}

# Apply a filter (uid/gid ranges) expression.
# Return 1 if $id is within the ranges specified by $filter
sub matches {
    my ($filter, $id) = @_;

    my @filter = @{$filter};
    while (my ($min, $max) = splice(@filter, 0, 2)) {
	next if defined $min && $id < $min;
	next if defined $max && $id > $max;
	return 1;
    }
    return 0;
}

# Apply a filter (uid/gid ranges) expression.
# Return 1 if $id is within the ranges specified by $filter
# of if the filter expression was empty.
sub matches0 {
    my ($filter, $id) = @_;

    return 1 unless @{$filter};
    return $filter->matches($id);
}

# Output corner cases in a filter's ranges
sub corners {
    my ($filter) = @_;
    my @corners;
    my @filter = @{$filter};
    while (my ($min, $max) = splice(@filter, 0, 2)) {
	push @corners, $min if defined $min;
	push @corners, $max if defined $max && (!defined $min || $max > $min);
    }
    return sort {$a <=> $b} @corners;
}

1;
