
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <oci.h>

#include <Oracle.h>	/* DBD::Oracle */

DBISTATE_DECLARE;

void
oci_util_init(dbistate)
    dbistate_t *dbistate;
{
    DBIS = dbistate;
}


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


I32
oci_buf_getmaxlen(IV svptr_iv, SV* len_sv)
{
    STRLEN lna;
    SV *buf_sv = (SV*)svptr_iv;
    if (DBIS->debug)
	warn("    oci_buf_getmaxlen of '%s'=%d", SvPV(buf_sv,lna), SvLEN(buf_sv));
    sv_setiv(len_sv, SvLEN(buf_sv));
    return -1;
}

I32
oci_buf_setcurlen(IV svptr_iv, SV* len_sv)
{
    SV *buf_sv = (SV*)svptr_iv;
    IV len = SvIV(len_sv);
    if (DBIS->debug)
	warn("    oci_buf_setcurlen to %d (max %d)", len, SvLEN(buf_sv));
    SvGROW(buf_sv, len+1/*null*/);	/* just in case */
    SvCUR_set(buf_sv, len);
    *SvEND(buf_sv) = '\0';
    return -1;
}


SV *
get_oci_error(OCIError *errhp, sword status, char *what, int debug)
{
    text errbuf[1024];
    ub4 recno = 0;
    sb4 errcode = 0;
    sb4 eg_errcode = 0;
    sword eg_status;

    SV *errstr = newSViv(0); /* dual-valued, like $! */
    sv_setpv(errstr,"");

    if (!errhp) {
	sv_catpv(errstr, oci_status_name(status));
	if (what && *what) {
	    sv_catpv(errstr, " ");
	    sv_catpv(errstr, what);
	}
        SvIVX(errstr) = status;
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
    SvIVX(errstr) = errcode;
    SvIOK_on(errstr);
    return errstr;
}


void *
get_oci_handle(SV *h, int handle_type, int flags) {
    STRLEN lna;
    typedef void *(*hook_type)_((imp_xxh_t *imp_xxh, int handle_type, int flags));
    hook_type hook;
    /* D_imp_xxh(h); */
    imp_xxh_t *imp_xxh;
    if (DBIS->debug)
	warn("    get_oci_handle(%s,%d,%d)", SvPV(h,lna), handle_type, flags);
    imp_xxh = (imp_xxh_t*)(DBIh_COM(h));
    if (DBIc_TYPE(imp_xxh) == DBIt_ST)
	hook = (hook_type)((imp_sth_t*)imp_xxh)->get_oci_handle;
    else if (DBIc_TYPE(imp_xxh) == DBIt_DB)
	hook = (hook_type)((imp_dbh_t*)imp_xxh)->get_oci_handle;
    else croak("Can't get oci handle type %d from %s. Unsupported DBI handle type",
	    handle_type, SvPV(h,lna));
    return hook(imp_xxh, handle_type, flags);
}


void *
ora_getptr_generic(SV *arg, char *var, char *type, char *func) {
    STRLEN lna;
    IV tmp;
    int want_voidptr;
    int debug = DBIS->debug;

    if (debug)
	warn("    %s %s: converting %s to %s", func, var, SvPV(arg,lna), type);

    if (SvROK(arg) && SvTYPE(SvRV(arg))==SVt_PVHV && SvMAGICAL(SvRV(arg))) {
	if (strEQ(type,"OCIErrorPtr"))	return get_oci_handle(arg, OCI_HTYPE_ERROR, 0);
	if (strEQ(type,"OCISvcCtxPtr"))	return get_oci_handle(arg, OCI_HTYPE_SVCCTX, 0);
	if (strEQ(type,"OCIEnvPtr"))	return get_oci_handle(arg, OCI_HTYPE_ENV, 0);
	if (strEQ(type,"OCIServerPtr"))	return get_oci_handle(arg, OCI_HTYPE_SERVER, 0);
	if (strEQ(type,"OCISessionPtr"))return get_oci_handle(arg, OCI_HTYPE_SESSION, 0);
	if (strEQ(type,"OCIStmtPtr"))	return get_oci_handle(arg, OCI_HTYPE_STMT, 0);
	croak("Can't get %s handle from %s for %s(%s)", type, SvPV(arg,lna), func, var);
    }

    if (SvOK(arg) && sv_derived_from(arg, type)) {
 	IV tmp = SvIV((SV*)SvRV(arg));
 	void *foo = INT2PTR(void*,tmp);
 	return foo;
    }

    if (!SvOK(arg) || (SvNIOK(arg) && !SvIV(arg))) { /* undef and 0 (but not '') => null */
	if (debug)
	    warn("    %s %s: passing as null pointer", func, var);
	return 0;	/* false == null pointer */
    }

    want_voidptr = ( *type=='v' && strEQ(type,"voidPtr") );
    if (want_voidptr) {
	if (SvPOK(arg) && !SvROK(arg) && !SvOBJECT(arg)) {
	    /* XXX HACK special case to simply passing a buffer, ie OCILobRead */
	    if (SvPOK(arg) && !SvNIOK(arg) /*|| strEQ(var,"bufp") || strEQ(var,"attributep")*/) {
		if (debug)
		    warn("    %s %s: passing as pointer to buffer", func, var);
		return SvPV(arg,lna);
	    }
	    /* else just treat as pointer without type checking */
	    if (debug)
		warn("    %s %s: passing as who knows what!", func, var);
	    tmp = (SvROK(arg)) ? SvIV((SV*)SvRV(arg)) : SvIV(arg);
	    return INT2PTR(void*, tmp);
	}

	if (SvIOK(arg) && !SvROK(arg) && SvOBJECT(arg)) {
	    void *ptr = INT2PTR(void*, SvIV(arg));
	    if (debug)
		warn("    %s %s: passing integer as bare pointer 0x%p/%ld", func, var, ptr, ptr);
	    return ptr;
	}

	if (SvROK(arg) && SvOBJECT(SvRV(arg))) {
	    IV tmp = SvIV((SV*)SvRV(arg));
	    void *ptr = INT2PTR(void*,tmp);
	    if (debug)
		warn("    %s %s: passing as bare pointer 0x%p/%ld", func, var, ptr, ptr);
	    return ptr;
	}
    }
    if (0 && (!SvOK(arg) || (SvNIOK(arg) && SvIV(arg)==0))) {
	return 0;
    }
    croak("%s is not of type %s (is actually %s)", var, type, SvPV(arg,lna));
}
