#!/bin/ksh
set -x

# ###########################################################################
#
# Configuration section - edit this section - and you *do* need to edit it!
#

#
# ---	Link-time configuration:
#	The contents of this string should be extracted from
#	the generated Makefile of a *working* DBD::Oracle that
#	has been *built recently on the same platform*:
#
dynamic_lib='OTHERLDFLAGS=>q[ -L/home/oracle/product/8.1.5/lib/ -L/home/oracle/product/8.1.5/rdbms/lib -lclntsh /home/oracle/product/8.1.5/lib/nautab.o /home/oracle/product/8.1.5/lib/naeet.o /home/oracle/product/8.1.5/lib/naect.o /home/oracle/product/8.1.5/lib/naedhs.o  `cat /home/oracle/product/8.1.5/lib/ldflags`     -ln8 -lnl8 -lnro8 `cat /home/oracle/product/8.1.5/lib/ldflags`     -ln8 -lnl8 -lclient8 -lvsn8 -lcommon8 -lskgxp8 -lgeneric8 -lmm -lnls8  -lcore8 -lnls8 -lcore8  -lnls8 `cat /home/oracle/product/8.1.5/lib/ldflags`     -ln8 -lnl8 -lnro8 `cat /home/oracle/product/8.1.5/lib/ldflags`     -ln8 -lnl8 -lclient8 -lvsn8 -lcommon8 -lskgxp8 -lgeneric8   -ltrace8 -lnls8  -lcore8 -lnls8 -lcore8  -lnls8 -lclient8 -lvsn8 -lcommon8 -lskgxp8 -lgeneric8 -lnls8  -lcore8 -lnls8 -lcore8  -lnls8   `cat /home/oracle/product/8.1.5/lib/sysliblist` `if [ -f /usr/lib/libsched.so ] ; then echo -lsched ; else true; fi` -R/opt/SUNWcluster/lib:/home/oracle/product/8.1.5/lib  -YP,:/opt/mysql/mysql/lib:/usr/dt/lib:/opt/SUNWcluster/lib:/usr/ccs/lib:/usr/lib  -Qy -lc -laio -lposix4 -lkstat -lm  -lthread]'

#
# ---	perl regex of OCI* functions for h2xs to skip/ignore:
#	Most are skipped to save time in the edit-build-test-edit loop
#	A few are skipped to avoid addressing less important implementation issues
#
skip_funcs='|Bind|Cache|Callback|Complex|Context|File|Date|Extract|Format|Iter|Interval|Lob|Memory|Message|MultiByte|Ref|Raw|Security|String|Table|Thread|DirPath|Number|Object|Pickler|Subscription|Type|WideChar'

#
# what perl to use (only here because I often have other perl's in my PATH)
# only tested with perl 5.6.0
#
export PATH=/opt/perl5/bin:$PATH


# ###########################################################################
#
# Bootstrap and build the extension
# (shouldn't need changing, except to make it better and rewrite in perl :)
#

# have we got what it takes?
perl	-M5.006 \
	-MC::Scan=0.74	\
	-e 1	\
  || exit


if true
then
/bin/rm -rf Oracle/OCI/*

./h2xs -d -O -n Oracle::OCI \
	-F "-I$ORACLE_HOME/rdbms/demo -I$ORACLE_HOME/network/public" \
	-M "^OCI(?!TypeArrayByName\b|StmtGetBindInfo\b|TypeArrayByRef\b|EnvCallback\b$skip_funcs)" \
	-k -x \
	$ORACLE_HOME/rdbms/demo/oci.h \
		> h2xs.log 2>&1
fi

#exit 1;

#
# --- jump into newly created extension directory and start hacking
#
cd Oracle/OCI

mv typemap h2xs.typemap
ln -s ../../utility.c
ln -s ../../utility.h
ln -s ../../extra.typemap typemap # to have precedence over h2xs.typemap
ln -s ../../extra.xsh
ln -s ../../XSUB.h
mkdir t && ln -s ../../../connect.t t/connect.t


echo
echo "Editing OCI.xs..."
# simplify all 'void ...' types down to a plain 'void *'
# simplify all 'foo ** bar' types to 'foo * &bar': -e 's/^\t (\w+ \s* \*[\* ]*) \* \s* (\w+)$/\t$1 &$2/x;'	\
# simplify all 'foo ... (*func)(...) bar' types down to a plain 'void *'
# change all 'void *  &usrmempp' to 'void ** usrmempp'
#	(else oracle complains even if we've not asked for any memory to be allocated!)
# change all sword returns into sword_status so typemap can check status
# collect all argument types
perl -p -i.bak -w -MData::Dumper \
  -e 's/^MODULE(.*)/MODULE$1\n\nINCLUDE: extra.xsh\n\n/;'	\
  -e 's/^\t void \s+ \*? \s* \S .* \s+ (\w+)$/\tvoid *\t$1/x;'	\
  -e 's/^\t \w+ \s .* \(.*?\) .*? \(.*?\) \s+ (\w+)$/\tvoid *\t$1/x;'	\
  -e 's/^\tvoid.*&usrmempp/\tvoid *\tusrmempp/x;'	\
  -e 's/^sword$/sword_status/;'	\
  -e '$types{do{($a=$1)=~tr/\t //d;$a} }++ if m/^\t(\w+[\s\*]*)\s+[\&\s]*\w+$/;'	\
  -e 'END{ open T,">types.dat" or die $!; print T Dumper(\%types); }'	\
  OCI.xs
# gdiff -u OCI.xs.bak OCI.xs | grep '^[-+]'


# chunks of utility.h could be written dynamically from types.dat
#sort types.dat

echo
echo "Editing Makefile.PL..."
perl -p -i.bak -e 's!^\);!	CONFIGURE => \\&wmf_config,\n);!' Makefile.PL
echo "
sub wmf_config {
    return {
	OBJECT	=> q{\$(BASEEXT)\$(OBJ_EXT) utility.o},
	dynamic_lib => { $dynamic_lib },
	TYPEMAPS => ['h2xs.typemap'], # ./typemap implicitly last
    };
}
sub MY::postamble {
'
utility.o: utility.c
';
}
" >> Makefile.PL


wc -l *

echo "Building..."
perl Makefile.PL && make && make test


exit

__DATA__
