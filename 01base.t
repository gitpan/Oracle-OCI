#!perl -w

use strict;
use Test;
use Data::Dumper;

use DBI;

use Oracle::OCI qw(:all);

$|=1;
$^W=1;
$ENV{ORACLE_SID} ||= 'ORCL'; # not sure is TWO_TASK will work, try it :)
my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';


# subs to create correctly structured magical thingies
# (will be hidden/automatic/better later)
sub new_ptr {
    my $class = shift;
    my $modifiable = do { my $foo = shift || 0 };
    return bless \$modifiable => $class;
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
# warn Dumper($envhp, $$envhp);

# use Devel::Peek;
# Dump($envhp); # if following OCIHandleAlloc doesn't complain then this is a good handle

ok OCIHandleAlloc($$envhp, my $errhp=0, OCI_HTYPE_ERROR, 0, 0), 0;
bless $errhp => 'OCIErrorPtr';
ok($errhp);
ok(ref $errhp);
ok($$errhp);

ok OCIHandleAlloc($$envhp, my $svrhp=0, OCI_HTYPE_SERVER, 0, 0), 0;
bless $svrhp => 'OCIServerPtr';

ok OCIHandleAlloc($$envhp, my $svchp=0, OCI_HTYPE_SVCCTX, 0, 0), 0;
bless $svchp => 'OCISvcCtxPtr';

ok OCIServerAttach($svrhp, $errhp, 0, 0, OCI_DEFAULT), 0;

print "get_oci_error\n";
ok get_oci_error(undef, OCI_ERROR), "ERROR";
ok get_oci_error(undef, OCI_ERROR, 'foo'), "ERROR foo";
ok get_oci_error(undef, OCI_ERROR)+0, OCI_ERROR;
{
local $SIG{__WARN__} = sub { };	# silence expected failure warning
ok $status=OCIAttrSet($$svchp, OCI_HTYPE_SVCCTX, $$svrhp, 0, 99999999999, $errhp), OCI_ERROR;
}
my $errstr = get_oci_error($errhp, $status, 'foo');
ok $errstr, "ORA-24315: illegal attribute type (ERROR: foo)";	# as string
ok $errstr+0, 24315;						# as number

print "OCIAttrSet OCI_HTYPE_SVCCTX OCI_ATTR_SERVER\n";
ok OCIAttrSet($$svchp, OCI_HTYPE_SVCCTX, $$svrhp, 0, OCI_ATTR_SERVER, $errhp), 0;

print "oci_buf_len - input\n";
my $foo = "abcd";
my @foo_buf_len = oci_buf_len($foo);
ok @foo_buf_len, 2;
ok $foo_buf_len[0], $foo;
ok $foo_buf_len[1], length($foo);

print "oci_buf_len - output (magic)\n";
oci_buf_len_test( oci_buf_len($foo, 200) );
sub oci_buf_len_test { # have to test this way as len magic doesn't copy
ok @_ == 2;
ok $_[0], $foo;	# perl's idea of the length is unchanged
ok $_[1], 200;
ok $_[1] = 2;  	# assignment to len magically affects string
ok $_[0], substr($foo,0,2);
}

ok OCIHandleAlloc($$envhp, my $authp=0, OCI_HTYPE_SESSION, 0, 0), 0;
bless $authp => 'OCISessionPtr';

my ($user, $pass) = split /\//, $dbuser;
my @user_buf_len = oci_buf_len($user);
my @pass_buf_len = oci_buf_len($pass);
print "OCIAttrSet OCI_ATTR_USERNAME '$user' OCI_ATTR_PASSWORD '$pass' @user_buf_len @pass_buf_len\n";
ok OCIAttrSet($$authp, OCI_HTYPE_SESSION, @user_buf_len, OCI_ATTR_USERNAME, $errhp), 0;
ok OCIAttrSet($$authp, OCI_HTYPE_SESSION, @pass_buf_len, OCI_ATTR_PASSWORD, $errhp), 0;

ok $status=OCISessionBegin($svchp, $errhp, $authp, OCI_CRED_RDBMS, OCI_DEFAULT), 0;
warn get_oci_error($errhp, $status) unless $status == OCI_SUCCESS;

ok OCIAttrSet($$svchp, OCI_HTYPE_SVCCTX, $$authp, 0, OCI_ATTR_SESSION, $errhp), 0;

# --- test getting some attributes

#	integer attribute
ok $status=OCIAttrGet($$envhp, OCI_HTYPE_ENV, my $cache_max_size, 0, OCI_ATTR_CACHE_MAX_SIZE, $errhp, 4), 0;
print "	OCI_ATTR_CACHE_MAX_SIZE='$cache_max_size' from Oracle::OCI connection\n";
ok $cache_max_size > 1;

#	pointer attribute
ok $status=OCIAttrGet($$svrhp, OCI_HTYPE_SERVER, my $svrhp_envhp, 0, OCI_ATTR_ENV, $errhp, 'OCIEnvPtr'), 0;
print "	OCI_ATTR_ENV='$svrhp_envhp'\n";
ok ref($svrhp_envhp), 'OCIEnvPtr';
ok $$envhp, $$svrhp_envhp;

DBI->trace(0);


BEGIN { plan tests => 39, onfail => sub { warn Dumper(\@_) } }


__END__
