
MODULE = Oracle::OCI            PACKAGE = Oracle::OCI

BOOT:
	Perl_require_pv(aTHX_ "DBD::Oracle");
	DBISTATE_INIT;
	oci_util_init(DBIS);

SV *
get_oci_error(errhp, status, what="", debug=-1)
	OCIError *errhp
	int status
	char *what
	int debug


void
get_oci_handle(h, handle_type)
	SV *h
	int handle_type
	PPCODE:
	void *handle = get_oci_handle(h, handle_type, 0);
	PUSHs(sv_2mortal(newSViv((IV)handle)));
	if (GIMME != G_SCALAR) {
	    PUSHs(sv_2mortal(newSViv((IV)handle_type)));
	}


void
oci_buf_len(sv, len=-1, ref_len_sv=Nullsv)
	SV *sv
	IV len
	SV *ref_len_sv
	PPCODE:
	if (GIMME == G_SCALAR)	/* sanity check */
	    croak("oci_buf_len not called in list context");
	PUSHs(sv);
	if (len == -1) {
	    /* is simple input param, no magic required */
	    XPUSHs(sv_2mortal(newSViv(SvCUR(sv))));	/* return the current string length */
	}
	else {
	    STRLEN lna;
	    struct ufuncs uf;
	    SV *len_mg = sv_2mortal(newSViv(len));
	    SvPV_force(sv, lna);
	    SvGROW(sv, len);
	    uf.uf_val   = &oci_buf_getmaxlen; /* get the allocated length of the sv */
	    uf.uf_set   = &oci_buf_setcurlen; /* SET the current length of the sv */
	    uf.uf_index = (IV)sv; /* store pointer to the SV to get/set the length of */
	    sv_magic(len_mg, 0, 'U', (char*)&uf, sizeof(uf));
	    if (ref_len_sv) {
		if (!SvROK(ref_len_sv))
		    croak("oci_buf_len(,,ref_len_sv) not a ref to scalar");
		uf.uf_val = 0; /* don't want 'getmaxlen' bahaviour here */
		sv_magic(SvRV(ref_len_sv), 0, 'U', (char*)&uf, sizeof(uf));
	    }
	    XPUSHs(len_mg);
	}


sword_status
OCIAttrGet(trgthndlp, trghndltyp, attributep_sv, sizep_sv, attrtype, errhp, ptr_len)
        void *  trgthndlp
        ub4     trghndltyp
        SV *    attributep_sv
        SV *    sizep_sv
        ub4     attrtype
        OCIError *      errhp
	int	ptr_len
	CODE:
	{
	ub4 b4_val = 0;
	char *ptr;
	STRLEN lna=0;
        ub4 sizep= SvIV(sizep_sv);
	int debug = DBIS->debug;
	switch (ptr_len) {
	case  1: case  2: case  4:
	case -1: case -2: case -4:
	    RETVAL = OCIAttrGet(trgthndlp, trghndltyp, (void*)&b4_val, 0, attrtype, errhp);
	    if (RETVAL==OCI_SUCCESS || RETVAL==OCI_SUCCESS_WITH_INFO) {
		switch (ptr_len) {
		case  1: sv_setiv(attributep_sv, (IV)*((ub1*)&b4_val)); break;
		case -1: sv_setiv(attributep_sv, (IV)*((sb1*)&b4_val)); break;
		case  2: sv_setiv(attributep_sv, (IV)*((ub2*)&b4_val)); break;
		case -2: sv_setiv(attributep_sv, (IV)*((sb2*)&b4_val)); break;
		case  4: sv_setiv(attributep_sv, (IV)*((ub4*)&b4_val)); break; /* XXX UV */
		case -4: sv_setiv(attributep_sv, (IV)*((sb4*)&b4_val)); break;
		}
	    }
	    break;
	case 0:
	    RETVAL = OCIAttrGet(trgthndlp, trghndltyp, &ptr, &sizep, attrtype, errhp);
	    if (RETVAL==OCI_SUCCESS || RETVAL==OCI_SUCCESS_WITH_INFO) {
		sv_setpvn(attributep_sv, ptr, sizep);
		if (!SvREADONLY(sizep_sv)) {
		    sv_setiv(sizep_sv, sizep);
		    SvSETMAGIC(sizep_sv); /* redundant */
		}
	    }
	    break;
	default:
	    croak("bad ptr_len %d",ptr_len);
	}
        if (RETVAL != OCI_SUCCESS || debug) {
	    warn("    OCIAttrGet = '%s'", SvPV(attributep_sv,lna));
            warn("    %s returned %s", "OCIAttrGet", oci_status_name(RETVAL));
        }
        ST(0) = sv_newmortal();
        sv_setiv(ST(0), (IV)RETVAL);
	}
