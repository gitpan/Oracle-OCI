
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
	    STRLEN l = SvOK(sv) ? SvCUR(sv) : 0;
	    XPUSHs(sv_2mortal(newSViv(l)));	/* return the current string length */
	}
	else {
	    STRLEN lna;
	    struct ufuncs uf;
	    SV *len_mg = sv_2mortal(newSViv(len));
	    if (!SvOK(sv))
		sv_setpv(sv,"");
	    SvPV_force(sv, lna);
	    SvGROW(sv, len);	/* will typically allocate more than len bytes	*/
	    uf.uf_val   = &oci_buf_getmaxlen; /* get the allocated length of the sv	*/
	    uf.uf_set   = &oci_buf_setcurlen; /* SET the current length of the sv	*/
	    uf.uf_index = (IV)sv; /* store pointer to the SV to get/set the length of	*/
	    sv_magic(len_mg, 0, 'U', (char*)&uf, sizeof(uf));
	    if (ref_len_sv) {
		if (!SvROK(ref_len_sv))
		    croak("oci_buf_len(,,ref_len_sv) not a ref to scalar");
		uf.uf_val = 0;	/* don't want 'getmaxlen' behaviour here	*/
		sv_magic(SvRV(ref_len_sv), 0, 'U', (char*)&uf, sizeof(uf));
	    }
	    XPUSHs(len_mg);
	}


sword_status
OCIAttrGet(trgthndlp, trghndltyp, attributep_sv, sizep_sv, attrtype, errhp, result_type)
        void *  trgthndlp
        ub4     trghndltyp
        SV *    attributep_sv
        SV *    sizep_sv
        ub4     attrtype
        OCIError *      errhp
	SV *	result_type
	CODE:
	{
	ub4 b4_val = 0;
	char *ptr = Nullch;
	STRLEN lna=0;
        ub4 sizep = SvIV(sizep_sv);
	int debug = DBIS->debug;
	char * bless = Nullch;
        int ptr_len = (SvNIOK(result_type)) ? SvIV(result_type) : 0;
	if (ptr_len==0 && !looks_like_number(result_type) ) {
	    /* result_type is the name of a class to bless pointer into */
	    /* so we set ptr_len 4 and arrange to return a blessed ref.	*/
	    ptr_len = 4;
	    bless = SvPV(result_type,lna);
	}
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
		case  4: sv_setuv(attributep_sv, (UV)*((ub4*)&b4_val)); break;
		case -4: sv_setiv(attributep_sv, (IV)*((sb4*)&b4_val)); break;
		}
		if (bless) {
		    SV *rv = newRV(sv_mortalcopy(attributep_sv));
		    HV * bless_stash = gv_stashpv(bless, 0);
		    if (!bless_stash) {
			if (strlen(bless) < 6 || strnNE(bless,"OCI",3)
				|| strnNE(&bless[strlen(bless)-3],"Ptr",3))
			    warn("OCIAttrGet '%s' doesn't look like an OCI*Ptr type name",bless);
			bless_stash = gv_stashpv(bless, GV_ADD);
		    }
		    sv_bless(rv, bless_stash);
		    sv_setsv(attributep_sv, rv);
		}
	    }
	    else SvOK_off(attributep_sv);
	    break;
	case 0:
	    RETVAL = OCIAttrGet(trgthndlp, trghndltyp, &ptr, &sizep, attrtype, errhp);
	    if (RETVAL==OCI_SUCCESS || RETVAL==OCI_SUCCESS_WITH_INFO) {
		/* OCIAttrGet may set ptr to null, sv_setpvn() treats that as undef */
		sv_setpvn(attributep_sv, ptr, sizep);
		if (!SvREADONLY(sizep_sv)) {
		    sv_setiv(sizep_sv, sizep);
		    SvSETMAGIC(sizep_sv); /* redundant */
		}
	    }
	    else SvOK_off(attributep_sv);
	    break;
	default:
	    croak("Invalid pointer width '%s' for OCIAttrGet", SvPV(result_type,lna));
	}
        if (RETVAL != OCI_SUCCESS || debug) {
	    char *q = SvOK(attributep_sv) ? "'" : "";
            warn("    %s returned %s %s%s%s", "OCIAttrGet", oci_status_name(RETVAL),
					q, *q ? SvPV(attributep_sv,lna) : "undef", q);
        }
        ST(0) = sv_newmortal();
        sv_setiv(ST(0), (IV)RETVAL);
	}
