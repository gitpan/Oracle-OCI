/* included via XSUB.h :) */

#include <oci.h>

#define sword_status sword

SV *get_oci_error(OCIError *errhp, sword status, char *what, int debug);
void *get_oci_handle(SV *h, int handle_type, int flags);

void *ora_getptr_generic(SV *arg, char *var, char *type, char *func);

I32 oci_buf_getmaxlen(IV svptr_iv, SV* len_sv);
I32 oci_buf_setcurlen(IV svptr_iv, SV* len_sv);


#include "getptrdef.h"

