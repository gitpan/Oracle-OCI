
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <oci.h>


char *
oci_status_name(sword status)
{
    SV *sv;
    switch (status) {
    case OCI_SUCCESS:           return "SUCCESS";
    case OCI_SUCCESS_WITH_INFO: return "SUCCESS_WITH_INFO";
    case OCI_NEED_DATA:         return "NEED_DATA";
    case OCI_NO_DATA:           return "NO_DATA";
    case OCI_ERROR:             return "ERROR";
    case OCI_INVALID_HANDLE:    return "INVALID_HANDLE";
    case OCI_STILL_EXECUTING:   return "STILL_EXECUTING";
    case OCI_CONTINUE:          return "CONTINUE";
    }
    sv = sv_2mortal(newSVpv("",0));
    sv_grow(sv, 50);
    sprintf(SvPVX(sv),"(UNKNOWN OCI STATUS %d)", status);
    return SvPVX(sv);
}


SV *
oci_error_get(OCIError *errhp, SV *errstr_in, sword status, char *what, int debug)
{
    text errbuf[1024];
    ub4 recno = 0;
    sb4 errcode = 0;
    sb4 eg_errcode = 0;
    sword eg_status;

    SV *errstr = (errstr_in) ? errstr_in : sv_2mortal(newSVpv("",0));

    /* set int first to ensure upgraded			*/
    /* will reset to the correct value once we know it	*/
    sv_setiv(errstr, status);

    if (!errhp) {
	sv_catpv(errstr, oci_status_name(status));
	if (what) {
	    sv_catpv(errstr, " ");
	    sv_catpv(errstr, what);
	}
	SvIOK_on(errstr);
	return errstr;
    }

    while( ++recno
	&& (eg_status=OCIErrorGet(errhp, recno, (text*)NULL, &eg_errcode, errbuf,
	    (ub4)sizeof(errbuf), OCI_HTYPE_ERROR)) != OCI_NO_DATA
	&& eg_status != OCI_INVALID_HANDLE
	&& recno < 100
    ) {
	if (debug >= 4 || recno>1/*XXX temp*/)
	    warn("    OCIErrorGet after %s (er%ld:%s): %d, %ld: %s\n",
		what, (long)recno,
		    (eg_status==OCI_SUCCESS) ? "ok" : oci_status_name(eg_status),
		    status, (long)eg_errcode, errbuf);
	errcode = eg_errcode;
        SvIVX(errstr) = errcode;
	if (recno > 1)
	    sv_catpv(errstr, "; ");
	sv_catpv(errstr, (char*)errbuf);
	if (*(SvEND(errstr)-1) == '\n')
	    --SvCUR(errstr);
    }
    if (what || status != OCI_ERROR) {
	sv_catpv(errstr, (debug<0) ? " (" : " (DBD ");
	sv_catpv(errstr, oci_status_name(status));
	if (what && *what) {
	    sv_catpv(errstr, ": ");
	    sv_catpv(errstr, what);
	}
	sv_catpv(errstr, ")");
    }
warn("[[%s]]",SvPV(errstr,PL_na));
    SvIOK_on(errstr);
    return errstr;
}


void *
ora_getptr_generic(SV *arg, char *var, char *type, char *func) {
    warn("%s: converting %s to %s", func, var, type);
    if (sv_derived_from(arg, type)) {
	IV tmp = SvIV((SV*)SvRV(arg));
	void *foo = INT2PTR(void*,tmp);
	return foo;
    }
    else
	croak("%s is not of type %s", var, type);
}
