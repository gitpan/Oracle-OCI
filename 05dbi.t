
use strict;
use Test;
use Data::Dumper;

use DBI;
use Oracle::OCI qw(:all);

$ENV{ORACLE_SID} ||= 'ORCL'; # not sure is TWO_TASK will work, try it :)
my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';
my ($user, $pass) = split /\//, $dbuser;


sub dvoid_p_str {
    my $string_ref = \$_[0] || \"";
    my $ptr_to_string = unpack("L", pack("p", $$string_ref));
    return ($ptr_to_string, length($$string_ref)) if wantarray;
    return $ptr_to_string;
}


# --- connected using DBI ---

my $dbh = DBI->connect('dbi:Oracle:', $user, $pass);
ok $dbh;

my $status;

# test ability to use DBI/DBD::Oracle handle
# Note in this case we use both explicit and implicit conversion
ok $status=OCIAttrGet(get_oci_handle($dbh, OCI_HTYPE_ENV), my $cache_max_size, 0, OCI_ATTR_CACHE_MAX_SIZE, $dbh), 0;
print "OCI_ATTR_CACHE_MAX_SIZE='$cache_max_size' from DBD::Oracle connection\n";

my $table = 'oracle_oci_test__drop_me';
my $create_table = qq{create table $table ( idx integer, lng CLOB )};
$dbh->do($create_table);
if ($dbh->err && $dbh->err==955) {
    $dbh->do(qq{ drop table $table });
    warn "Unexpectedly had to drop old test table '$table'\n" unless $dbh->err;
    $dbh->do($create_table);
}
my $LOB = join "", map { sprintf " %04d", $_ } 1..10;
print "LOB='$LOB'\n";
$dbh->do("insert into $table values (?, ?)", undef, 1, $LOB);
sub get_lob_locator {
    my $lob_locator = $dbh->selectrow_array(qq{
	SELECT lng FROM $table FOR UPDATE
    }, { ora_auto_lob=>0 });
    return $lob_locator;
}
ok my $lob_locator = get_lob_locator();
ok $$lob_locator;


# --- get the length, trim it, get the length again ---

ok OCILobGetLength($dbh, $dbh, $lob_locator, my $lob_len=0), 0;
ok $lob_len, length($LOB);

ok OCILobTrim($dbh, $dbh, $lob_locator, length($LOB)-5), 0;

ok OCILobGetLength($dbh, $dbh, $lob_locator, $lob_len=0), 0;
ok $lob_len, length($LOB)-5;

substr($LOB, -5) = ''; # adjust master copy to match


# --- now read a chunk in the middle of the LOB ---

my $lob_buf='';
my $amtp = 5;
ok OCILobRead($dbh, $dbh, $lob_locator,
		$amtp, 6,
		oci_buf_len($lob_buf, 200, \$amtp),
		0,0, 0,0 ), 0;
ok $lob_buf;
print "OCILobRead='$lob_buf', amtp=$amtp\n";
ok $lob_buf, ' 0002';

# --- now read whole lob in chunks ---

OCILobEnableBuffering($dbh, $dbh, $lob_locator); # optional

my $lob_read_buf='';
my $chunk  = 5;
for ( my $offset=1; $chunk == 5 ; $offset += $chunk ) {
    ok OCILobRead($dbh, $dbh, $lob_locator,
		$chunk, $offset,
		oci_buf_len($lob_buf, 200, \$chunk),
		0,0, 0,0 ), 0;
    print "OCILobRead $offset+$chunk = '$lob_buf'\n";
    $lob_read_buf .= $lob_buf;
}
ok $lob_read_buf, $LOB;

# --- now edit a lob ---

#DBI->trace(9);
$chunk = 5;
for ( my $offset=1; $chunk == 5 ; $offset += $chunk ) {
    ok OCILobRead($dbh, $dbh, $lob_locator,
		$chunk, $offset,
		oci_buf_len($lob_buf, 200, \$chunk),
		0,0, 0,0 ), 0;
    $lob_buf =~ s/0/o/g;
    ok $status=OCILobWrite($dbh, $dbh, $lob_locator,
		$chunk, $offset,
		oci_buf_len($lob_buf),
		OCI_ONE_PIECE, 0,0, 0, 1 ), 0 if $chunk;
    warn get_oci_error($dbh, $status, 'OCILobWrite') if $status != OCI_SUCCESS;
}

# XXX for some reason the above doesn't work. OCILobWrite gets called with
# the specified values and returns OCI_SUCCESS. Odd.
if (1) {
ok OCITransCommit($dbh, $dbh, OCI_DEFAULT), 0;
$lob_locator = get_lob_locator();
}
else {
ok 1;
}

# --- re-read the complete lob ---

ok OCILobRead($dbh, $dbh, $lob_locator,
	    $chunk=200, 1,
	    oci_buf_len($lob_buf, 200, \$chunk),
	    0,0, 0,0 ), 0;
print "$lob_buf\n";
DBI->trace(0);

BEGIN { plan tests => 44, onfail => sub { warn Dumper(\@_) } }

END { $dbh->do("drop table $table") if $dbh && $dbh->ping && $table; }

__END__
