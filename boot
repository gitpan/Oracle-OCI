#!/opt/perl5/bin/perl -w

require 5.6.0;
use strict;

use Carp;
use File::Path;
use File::Copy;
use File::Basename;
use Getopt::Long;
use Data::Dumper;
use ExtUtils::Manifest qw(manicopy);

use DBI;
use DBD::Oracle	1.10;
use C::Scan 	0.74;

$| = 1;


########################################################################
# configuration section.  
# all user configurable items are in %config.
# modifications outside of this area are not recommended.
########################################################################
# Many thanks to Steven Lembark for starting this perl version

my %opt;
GetOptions(\%opt,
	'all!',
) or die "Invalid option\n";

=head1 OCI::Oracle boot program

=head2 User Configuration Section

%config contains user-configurable items.  New keys are ignored,
deleting keys or values will cause the program to fail.

=over 4

=item oci_ignore

List of OCI subroutine name prefixes, without the leading 'OCI', of
subroutines to ignore (that is, to not include in Oracle::OCI).

Most are skipped to save time in the edit-build-test-edit loop.
A few are skipped to avoid addressing less important implementation issues.

=cut 

use vars qw($dbd_oracle_mm_opts);
require auto::DBD::Oracle::mk;	# defined $dbd_oracle_mm_opts and $dbd_oracle_mm_self

my %config = (

    # note that removing entries from here to enable them,
    # may also require adding new '#define' lines into getptrdef.h

    oci_ignore => [ sort keys %{ {
	AQ		=> "?",
	Bind		=> "?",
	Cache		=> "?",
	Callback	=> "?",
	Complex		=> "?",
	Context		=> "?",
	Date		=> "?",
	DirPath		=> "?",
	Extract		=> "?",
	File		=> "?",
	Format		=> "?",
	Interval	=> "?",
	Iter		=> "?",
	Memory		=> "?",
	Message		=> "?",
	MultiByte	=> "?",
	Object		=> "?",
	Pickler		=> "?",
	Raw		=> "?",
	Ref		=> "?",
	Security	=> "?",
	String		=> "?",
	Subscription	=> "?",
	Table		=> "?",
	Thread		=> "?",
	Type		=> "?",
	WideChar	=> "?",
	_NLS_		=> "OCI_NLS_* constants",
	_FNCODE_	=> "OCI_FNCODE_* constants",
    } } ],

    oci_skip => [ sort keys %{ {
	# excluded for special reasons
	AttrGet		=> "custom version in extra.xsh",
	TypeArrayByName	=> "?",
	StmtGetBindInfo	=> "?",
	StmtBindByPos	=> "not in some libs, superceeded by OCIBindByPos",
	StmtBindByName	=> "not in some libs, superceeded by OCIBindByName",
	TypeArrayByRef	=> "?",
	EnvCallback	=> "?",
	SharedLibInit	=> "uses 'dvoid *argv[]' type that we've not supported yet",
	'_ORACLE'	=> "empty define - used to prevent multiple #includes",
	'_FLAGS'	=> "empty define - used to prevent multiple #includes",
    } } ],

    # ---	Link-time configuration:
    #	The contents of this string should be extracted from
    #	the generated Makefile of a *working* DBD::Oracle that
    #	has been *built recently on the same platform*:

    LIBS => $::dbd_oracle_mm_opts->{LIBS},

    dynamic_lib => $::dbd_oracle_mm_opts->{dynamic_lib}
	|| die "DBD::Oracle::mk module doesn't define dynamic_lib",
);


############################################################################
# no user servicable parts below this line
# high voltage, whatever.
############################################################################
############################################################################
# sanity checks 
############################################################################

# convince ourselves that the oracle environment makes at
# least some sense.

my $orahome = $ENV{ORACLE_HOME}
	or croak "Error:  hit by a missing ORACLE_HOME";
-d $orahome  or croak "Error:  no such directory: $orahome";
-r _ && -x _ or croak "Error:  bad mods on $orahome";

my $demodir  = "$orahome/rdbms/demo";
-d $demodir  or croak "Error:  no directory '$demodir'";
-r _ && -x _ or croak "Error:  bad mods on '$demodir'";
my $oci_hdr = "$demodir/oci.h";
-e $oci_hdr or croak "Error:  hit by a missing oci.h";
-r _        or croak "Error:  unreadable $oci_hdr";

my @ora_dirs = ($demodir,
	"$orahome/rdbms/public",
	"$orahome/network/public",
	"$orahome/plsql/public",
);


############################################################################
# real work begins here.
############################################################################

rmtree('Oracle.prev')		if -d 'Oracle.prev';
move('Oracle'=>'Oracle.prev')	if -d 'Oracle';

#system("cd Oracle/OCI && make clean") if -f 'Oracle/OCI/Makefile';
# remove any added links
#unlink($_) for grep { -l $_ || (stat($_))[3]>1 } <Oracle/OCI/*>;


# build and execute h2xs command

$config{oci_ignore} = [] if $opt{all};

my @skip_list  = sort (@{$config{oci_ignore}}, @{$config{oci_skip}});
my $skip_regex = '^OCI(?!' . join('|',@skip_list) . ')|^SQL';

my @h2xsargz = (
    qw( ./h2xs -d -O -n Oracle::OCI ),
    "-F ".join(" ", map { "-I$_" } @ora_dirs),
    "-I".join(",", @ora_dirs),
    "-E get_oci_error,get_oci_handle,oci_buf_len,OCIAttrGet",
    "-M '$skip_regex'",
    "-k -x $oci_hdr",
);

my $h2xs = join ' ',  @h2xsargz;

print "Regex for h2xs ignores: $skip_regex\n";
print "Complete h2xs arguments: @h2xsargz\n";

# time to try h2xs.
# the user will see the value returned by h2xs as the last
# item printed.  alternative is to use ( my @result = qx( $h2xs ))
# and grep it for known fatalities -- problem is that i don't
# know what they are.

print "Running h2xs...\n";
system("$h2xs > h2xs.log") == 0
	or croak "h2xs failed";
croak "Error: h2xs failed to create ./Oracle/OCI"
	unless -d './Oracle/OCI';

# time to clean up the mess left behind by h2xs...

chdir './Oracle/OCI'
	or croak "Failed chdir ./Oracle/OCI: $!";

mkdir 't', 02775 or croak "Failed to make 't': $!"
	unless -d 't';
copy '/dev/null', 'test.pl';

# XXX change to use manicopy()
if( eval { symlink("",""); 1 } ) {
    -e $_ or symlink "../../$_", $_
	    for( qw(utility.c utility.h getptrdef.h extra.xsh XSUB.h ) );
     # to have precedence over h2xs.typemap
    move( 'typemap', 'h2xs.typemap' )			unless -e 'h2xs.typemap';
    symlink '../../extra.typemap', 'typemap'		unless -e 'typemap';
    symlink '../../../01base.t',  't/01base.t'		unless -e 't/01base.t';
    symlink '../../../05dbi.t',   't/05dbi.t'		unless -e 't/05dbi.t';
}
else {	# no symlinks, gotta copy the stuff
    -e $_ or copy "../../$_", $_
	    for( qw(utility.c utility.h getptrdef.h extra.xsh XSUB.h ) );
    move( 'typemap', 'h2xs.typemap' )			unless -e 'h2xs.typemap';
    copy '../../extra.typemap', 'typemap'		unless -e 'typemap';
    copy '../../../01base.t',  't/01base.t'		unless -e 't/01base.t';
    copy '../../../05dbi.t',   't/05dbi.t'		unless -e 't/05dbi.t';
}

{ # localize the file handles, %typz

    print "Editing OCI.xs...\n";
    my %typz = ();

    move 'OCI.xs' => 'OCI.xs.bak';
    open my $old_xs, '< OCI.xs.bak' or croak "Error:  opening OCI.xs.bak: $!";
    open my $new_xs, '> OCI.xs'     or croak "Error:  creating OCI.xs: $!";

    local $/ = "";	# paragraph mode
    while ( <$old_xs> ) {
	chomp;

	# simplify all 'foo ** bar' types to 'foo * &bar'
	# not used: s/^\t (\w+ \s* \*[\* ]*) \* \s* (\w+)$/\t$1 &$2/x

	# change all sword returns into sword_status so typemap can check status
	s{^sword$}{sword_status}m;

	# simplify int pointer types to int refs (ub4 *foo => ub4 &foo)
	my @out_by_ref;
	push @out_by_ref, $2 while s{^\t ([us]b\d|int|short|long|size_t|sword|uword|boolean) \s* \* \s* (\w+)$}{\t$1 &$2}xm;

	s{^\#include.*oci.h.*}
		{#include <oci.h>\n#include <Oracle.h>\nDBISTATE_DECLARE;\n}xm;

	s{^MODULE(.*)}
		{MODULE$1\n\nINCLUDE: extra.xsh\n}xm;

	# simplify all 'void ...' types down to a plain 'void *'
	s{^\t void \s+ \*? \s* \S .* \s+ (\w+)$}
		{\tvoid *\t$1}xmg;

	# simplify all '... foo[]' types down to '... *foo'
	#s{ \s (\w+)\[\] $} {\t*$1}xmg;

	# simplify all 'foo ... (*func)(...) bar' types down to a plain 'void *'
	s{^\t \w+ \s .* \(.*?\) .*? \(.*?\) \s+ (\w+)$}
		{\tvoid *\t$1}xmg;

	# change all 'void *  &usrmempp' to 'void ** usrmempp'
	#	(else oracle complains even if we've not asked for any memory to be allocated!)
	s{^\tvoid.*&usrmempp}
		{\tvoid *\tusrmempp}xmg;

	# collect all argument types
	m/^\t(\w+[\s\*]*)\s+[\&\s]*\w+$/
		and $typz{ do{($a=$1)=~tr/\t //d;$a} }++ for split /\n/,$_;

	if (@out_by_ref) {
	    $_ .= "\n\tOUTPUT:" unless m/OUTPUT:/m;
	    $_ .= join("\n\t", '', @out_by_ref)."\n\n"
	}

	print $new_xs "$_\n\n";
    }
    close $new_xs or die "Error closing OCI.xs: $!";

    # dump out %typz sorted by key.
    open my $types, "> types.dat" or croak "Error:  opening types.dat: $!";
    print $types Dumper \%typz;
    close $types or die "Error closing types.dat: $!";
}

{
    print "Editing Makefile.PL...\n";

    move 'Makefile.PL' => 'Makefile.PL.bak';
    open my $old_mk, '< Makefile.PL.bak' or croak "Error:  opening Makefile.PL.bak: $!";
    open my $new_mk, '> Makefile.PL'     or croak "Error:  creating Makefile.PL: $!";
    while ( <$old_mk> ) {
	print $new_mk q{
		use DBI::DBD;
		my $dbi_dir      = dbd_dbi_dir();
		my $dbi_arch_dir = dbd_dbi_arch_dir();
		(my $ora_arch_dir = $dbi_arch_dir) =~ s!DBI$!DBD/Oracle!;
	}."\n" if $. == 1;
	s!^\);!      CONFIGURE => \\&wmf_config,\n);!;
	print $new_mk $_;
    }
    local $Data::Dumper::Terse = 1;
    my $dynamic_lib = Dumper($config{dynamic_lib});
    my $libs = Dumper($config{LIBS});
    my $ora_inc = join " ", map { "-I$_" } @ora_dirs;
    print $new_mk qq{
	sub wmf_config {
	    return {
		INC	=> "$ora_inc -I\$ora_arch_dir -I\$dbi_arch_dir",
		OBJECT	=> q{\$(BASEEXT)\$(OBJ_EXT) utility.o},
		TYPEMAPS => ['h2xs.typemap'], # ./typemap implicitly last
		OPTIMIZE => '-g',
		LIBS => $libs,
		dynamic_lib => $dynamic_lib,
	    };
	}
	sub MY::postamble {
	    return "\\n"
		. "utility.o: utility.c\\n\\n"
		. "OCI.c: extra.xsh\\n";
	}
    \n};
    close $new_mk or die "Error closing Makefile.PL: $!";
}

print "Building...\n";
system("perl Makefile.PL && make && make test");

exit 0;

__DATA__
