
use strict;
use Test;
use Data::Dumper;

use DBI;

use Oracle::OCI qw(:all);

$ENV{ORACLE_SID} ||= 'ORCL'; # not sure is TWO_TASK will work, try it :)
my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';


# subs to create correctly structured magical thingies
# (will be hidden/automatic/better later)
sub new_ptr {
    my $class = shift;
    my $modifiable = do { my $foo = shift || 0 };
    return bless \$modifiable => $class;
}
sub dvoid_p_str {
    my $string_ref = \$_[0] || \"";
    my $ptr_to_string = unpack("L", pack("p", $$string_ref));
    return ($ptr_to_string, length($$string_ref)) if wantarray;
    return $ptr_to_string;
}

# here we go...

ok OCIInitialize(OCI_OBJECT, 0, 0, 0, 0), 0;

my $status;

my $envhp = new_ptr('OCIEnvPtr');
ok(ref $envhp);
ok(!$$envhp);	# is zero to start with
ok OCIEnvInit($envhp, OCI_DEFAULT, 0, 0), 0;
ok($envhp);	# is still true
ok(ref $envhp);	# is still a ref
ok($$envhp);	# is no-longer zero!
#warn Dumper($envhp, $$envhp);

ok OCIHandleAlloc($$envhp, my $errhp=0, OCI_HTYPE_ERROR, 0, 0), 0;
$errhp = new_ptr('OCIErrorPtr', $errhp); # wrap integer into a handle
ok($errhp);
ok(ref $errhp);
ok($$errhp);

ok OCIHandleAlloc($$envhp, my $svrhp=0, OCI_HTYPE_SERVER, 0, 0), 0;
$svrhp = new_ptr('OCIServerPtr', $svrhp);

ok OCIHandleAlloc($$envhp, my $svchp=0, OCI_HTYPE_SVCCTX, 0, 0), 0;
$svchp = new_ptr('OCISvcCtxPtr', $svchp);

ok OCIServerAttach($svrhp, $errhp, 0, 0, OCI_DEFAULT), 0;

#warn Dumper($svchp, $svrhp, $errhp);
ok OCIAttrSet($$svchp, OCI_HTYPE_SVCCTX, $$svrhp, 0, OCI_ATTR_SERVER, $errhp), 0;

ok OCIHandleAlloc($$envhp, my $authp=0, OCI_HTYPE_SESSION, 0, 0), 0;
$authp = new_ptr('OCISessionPtr', $authp);

my ($user, $pass) = split /\//, $dbuser;
ok OCIAttrSet($$authp, OCI_HTYPE_SESSION, dvoid_p_str($user), OCI_ATTR_USERNAME, $errhp), 0;
ok OCIAttrSet($$authp, OCI_HTYPE_SESSION, dvoid_p_str($pass), OCI_ATTR_PASSWORD, $errhp), 0;

warn "OCISessionBegin...";
ok $status=OCISessionBegin($svchp, $errhp, $authp, OCI_CRED_RDBMS, OCI_DEFAULT), 0;

warn "OCISessionBegin=$status\n";
warn get_oci_error($errhp, my $foo='', $status) unless $status == OCI_SUCCESS;

ok OCIAttrSet($$svchp, OCI_HTYPE_SVCCTX, $$authp, 0, OCI_ATTR_SESSION, $errhp), 0;

# test connection by getting an attribute
ok $status=OCIAttrGet($$envhp, OCI_HTYPE_ENV, my $cache_max_size, 0, OCI_ATTR_CACHE_MAX_SIZE, $errhp), 0;
warn "OCI_ATTR_CACHE_MAX_SIZE='$cache_max_size' from Oracle::OCI\n";

# --- connected using DBI ---

my $dbh = DBI->connect('dbi:Oracle:', $user, $pass);
ok $dbh;

# test ability to use DBI/DBD::Oracle handle
# Note in this case we use both explicit and implicit conversion
ok $status=OCIAttrGet(get_oci_handle($dbh, OCI_HTYPE_ENV), $cache_max_size, 0, OCI_ATTR_CACHE_MAX_SIZE, $dbh), 0;
warn "OCI_ATTR_CACHE_MAX_SIZE='$cache_max_size' from DBD::Oracle\n";

my $table = 'oracle_oci_test__drop_me';
my $create_table = qq{create table $table ( idx integer, lng CLOB )};
$dbh->do($create_table);
if ($dbh->err && $dbh->err==955) {
    $dbh->do(qq{ drop table $table });
    warn "Unexpectedly had to drop old test table '$table'\n" unless $dbh->err;
    $dbh->do($create_table);
}
$dbh->do("insert into $table values (?, ?)", undef, 1, "BLOB");
my $lob_locator = $dbh->selectrow_array(qq{
	select lng from $table for update
    }, { ora_auto_lob=>0 });

ok OCILobGetLength($dbh, $dbh, $lob_locator, my $lob_len=0), 0;
warn "OCILobGetLength=$lob_len";

ok OCILobTrim($dbh, $dbh, $lob_locator, 2), 0;

ok OCILobGetLength($dbh, $dbh, $lob_locator, my $lob_len=0), 0;
warn "OCILobGetLength=$lob_len";



# --- connected now ---

if (0) {
my $external_name = "-" x 30;
ok OCIAttrGet($$svrhp, OCI_HTYPE_SERVER, $external_name, 0, OCI_ATTR_INTERNAL_NAME, $errhp), 0;
warn "OCI_ATTR_EXTERNAL_NAME='$external_name'\n";
}

BEGIN { plan tests => 26, onfail => sub { warn Dumper(\@_) } }

END { $dbh->do("drop table $table") if $dbh && $dbh->ping; }

__END__
