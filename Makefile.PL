# -*- perl -*-
#
# $Id: Makefile.PL,v 1.4 2001/07/08 02:08:38 timbo Exp $
#
#  Copyright (c) 2001  Tim Bunce  England
#
# See COPYRIGHT section in README for usage and distribution rights.

use 5.006;		# might work perl>=5.005_03 but untested
use ExtUtils::MakeMaker qw(WriteMakefile $Verbose);
use Getopt::Long;
use Config;

use C::Scan 0.71;	# needed by h2xs
use DBD::Oracle 1.07;

use lib 'lib';


my $os = $^O;
my $osvers = $Config{osvers};
$osvers =~ s/^\s*(\d+\.\d+).*/$1/;  # drop sub-sub-version: 2.5.1 -> 2.5
my $ext_pl = $^O eq 'VMS' ? '.pl' : '';

$::opt_v = 0;
$::opt_g = 0;

GetOptions(qw(v! g!))
	or die "Invalid arguments\n";

$::opt_g &&= '-g';  # convert to actual string

 
%opts = (
    NAME	=> 'Oracle::OCI',
    VERSION	=> '0.04',
    NEEDS_LINKING => 0,
    OBJECT	=> [],
    PREREQ_PM	=> { 'C::Scan' => 0.71 },
    NORECURS	=> 1,
    DIR		=> [],
    clean => { FILES=> "Oracle/" },
    dist  => {
	DIST_DEFAULT=> 'clean distcheck disttest ci tardist',
	PREOP => '$(MAKE) -f Makefile distdir',
	COMPRESS => 'gzip -v9', SUFFIX => 'gz',
    },
    ABSTRACT => 'Raw Oracle 8 OCI interface',
    AUTHOR => 'Tim Bunce (oracle-oci@perl.org)',
);

$Verbose = $::opt_v;
WriteMakefile( %opts );

warn <<EOT;

    Remember to actually *read* the README file!
    Use  'make' to build the software (dmake or nmake on Windows).
    Then 'make test' to execute self tests.
    Then 'make install' to install the DBI and then delete this working
    directory before unpacking and building any DBD::* drivers.

EOT

exit 0;


# =====================================================================


# end.
