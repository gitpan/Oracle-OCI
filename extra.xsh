
MODULE = Oracle::OCI            PACKAGE = Oracle::OCI

BOOT:
	Perl_require_pv("DBD::Oracle");
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
OCIAttrGet(trgthndlp, trghndltyp, attributep_sv, sizep_sv, attrtype, errhp)
        void *  trgthndlp
        ub4     trghndltyp
        SV *    attributep_sv
        SV *    sizep_sv
        ub4     attrtype
        OCIError *      errhp
	CODE:
        ub4 sizep=90;
        char buf[99];
        dvoid *attributep=buf;
	int debug = DBIS->debug;
        buf[0]='\0';
        RETVAL = OCIAttrGet(trgthndlp, trghndltyp, &attributep, &sizep, attrtype, errhp);
	if (debug)
	    warn("    OCIAttrGet attributep=%p (buf=%p) size=%d %s",
			attributep,buf,sizep,oci_status_name(RETVAL));
        if ((IV)attributep < 65000)	/* XXX TOTAL HACK XXX */
             sv_setiv(attributep_sv, (IV)attributep);
        else sv_setpvn(attributep_sv, (char*)attributep, sizep);
        if (!SvREADONLY(sizep_sv))
            sv_setiv(sizep_sv, sizep);
	if (debug)
	    warn("    OCIAttrGet attributep=%s %p %d",
			SvPV(attributep_sv,sizep),attributep,sizep);
        ST(0) = sv_newmortal();
        if (RETVAL != OCI_SUCCESS /* || tracing enabled */) {
            warn("    %s returned %s", "OCIAttrGet", oci_status_name(RETVAL));
        }
        sv_setiv(ST(0), (IV)RETVAL);
