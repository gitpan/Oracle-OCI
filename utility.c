
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <oci.h>

#include <Oracle.h>	/* DBD::Oracle */

DBISTATE_DECLARE;

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
get_oci_error(OCIError *errhp, SV *errstr_in, sword status, char *what, int debug)
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
get_oci_handle(SV *h, int handle_type, int flags) {
    STRLEN lna;
    D_imp_xxh(h);
    void *(*hook)_((imp_xxh_t *imp_xxh, int handle_type, int flags));
    if (DBIc_TYPE(imp_xxh) == DBIt_ST)
	hook = (void*)((imp_sth_t*)imp_xxh)->get_oci_handle;
    else if (DBIc_TYPE(imp_xxh) == DBIt_DB)
	hook = (void*)((imp_dbh_t*)imp_xxh)->get_oci_handle;
    else croak("Can't get oci handle type %d from %s. Unsupported DBI handle type.",
	    handle_type, SvPV(h,lna));
    return hook(imp_xxh, handle_type, flags);
}


void *
ora_getptr_generic(SV *arg, char *var, char *type, char *func) {
    STRLEN lna;
    if (!DBIS) {
	DBISTATE_INIT;
    }
    if (DBIS->debug)
	warn("    %s: converting %s %s to %s", func, var, SvPV(arg,lna), type);
    if (SvROK(arg) && SvTYPE(SvRV(arg))==SVt_PVHV && SvMAGICAL(SvRV(arg))) {
	if (strEQ(type,"OCIErrorPtr"))	return get_oci_handle(arg, OCI_HTYPE_ERROR, 0);
	if (strEQ(type,"OCISvcCtxPtr"))	return get_oci_handle(arg, OCI_HTYPE_SVCCTX, 0);
	if (strEQ(type,"OCIEnvPtr"))	return get_oci_handle(arg, OCI_HTYPE_ENV, 0);
	if (strEQ(type,"OCIServerPtr"))	return get_oci_handle(arg, OCI_HTYPE_SERVER, 0);
	if (strEQ(type,"OCISessionPtr"))return get_oci_handle(arg, OCI_HTYPE_SESSION, 0);
	if (strEQ(type,"OCIStmtPtr"))	return get_oci_handle(arg, OCI_HTYPE_STMT, 0);
	croak("Can't get %s handle from %s for %s(%s)", type, SvPV(arg,lna), func, var);
    }
    if (sv_derived_from(arg, type)) {
	IV tmp = SvIV((SV*)SvRV(arg));
	void *foo = INT2PTR(void*,tmp);
	return foo;
    }
    else
	croak("%s is not of type %s (actually %s)", var, type, SvPV(arg,lna));
}
