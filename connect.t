
use strict;
use Test;
use Data::Dumper;
use Oracle::OCI;

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
warn Oracle::OCI::oci_error_get($errhp, my $foo='', $status) unless $status == OCI_SUCCESS;

ok OCIAttrSet($$svchp, OCI_HTYPE_SVCCTX, $$authp, 0, OCI_ATTR_SESSION, $errhp), 0;

BEGIN { plan tests => 20, onfail => sub { warn Dumper(\@_) } }

__END__
