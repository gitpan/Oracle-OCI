

MODULE = Oracle::OCI            PACKAGE = Oracle::OCI

BOOT:
	Perl_require_pv("DBD::Oracle");

SV *
get_oci_error(errhp, errstr=Nullsv, status, what="", debug=-1)
	OCIError *errhp
	SV *errstr
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
        buf[0]='\0';
        RETVAL = OCIAttrGet(trgthndlp, trghndltyp, &attributep, &sizep, attrtype, errhp);
warn("    attributep=%p (buf=%p) size=%d %s",attributep,buf,sizep,oci_status_name(RETVAL));
        if ((IV)attributep < 65000)	/* XXX TOTAL HACK XXX */
             sv_setiv(attributep_sv, (IV)attributep);
        else sv_setpvn(attributep_sv, (char*)attributep, sizep);
        if (!SvREADONLY(sizep_sv))
            sv_setiv(sizep_sv, sizep);
warn("    attributep=%s %p %d",SvPV(attributep_sv,sizep),attributep,sizep);
        ST(0) = sv_newmortal();
        if (RETVAL != OCI_SUCCESS /* || tracing enabled */) {
            warn("    %s returned %s", "OCIAttrGet", oci_status_name(RETVAL));
        }
        sv_setiv(ST(0), (IV)RETVAL);
