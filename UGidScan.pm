package UGidScan;

use strict;

sub read_text_list {
    my ($dbfn) = @_;
    my $dbf;
    my %uid;
    my %gid;
    print STDERR "Reading list '$dbfn' ...";
    open($dbf, '<', $dbfn) || die("Can't read '$dbfn': $!\n");
    local $/ = "\0\n";
    while (<$dbf>) {
	if (/\Au\s*(\d+):\s*(\d+):(.*)\0\n\z/) {
	    $uid{$1}{$3} = $2;
	} elsif (/\Ag\s*(\d+):\s*(\d+):(.*)\0\n\z/) {
	    $gid{$1}{$3} = $2;
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
    
    return bless \%db;
}

# List all directories that contain files with uids from a given range
sub uid_range_dirs {
    my ($db, $range) = @_;
    my $filter = Filter->new($range);
    return [sort {$a cmp $b}
	    map { keys %{$db->{uid}{$_}} }
	    grep { $filter->matches($_) } @{$db->{uids}}];
}

# List all directories that contain files with gids from a given range
sub gid_range_dirs {
    my ($db, $range) = @_;
    my $filter = Filter->new($range);
    return [sort {$a cmp $b}
	    map { keys %{$db->{gid}{$_}} }
	    grep { $filter->matches($_) } @{$db->{gids}}];
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
    
    @filter = map { (defined $_ && length($_) > 0) ? $_ : undef } @filter;

    return bless [@filter] => $class;
}

# Apply a filter (uid/gid ranges) expression.
# Return 1 if $id is within the ranges specified by $filter
# of if the filter expression was empty.
sub matches {
    my ($filter, $id) = @_;

    return 1 unless @{$filter};
    my @filter = @{$filter};
    while (my ($min, $max) = splice(@filter, 0, 2)) {
	next if defined $min && $id < $min;
	next if defined $max && $id > $max;
	return 1;
    }
    return 0;
}

1;
