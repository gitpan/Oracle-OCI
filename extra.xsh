

MODULE = Oracle::OCI            PACKAGE = Oracle::OCI

SV *
oci_error_get(errhp, errstr=Nullsv, status, what="", debug=-1)
	OCIError *errhp
	SV *errstr
	int status
	char *what
	int debug
