/* included via XSUB.h :) */

#include <oci.h>

#define sword_status sword

SV *oci_error_get(OCIError *errhp, SV *errstr_in, sword status, char *what, int debug);

void *ora_getptr_generic(SV *arg, char *var, char *type, char *func);

#define ora_getptr_Lda_DefPtr ora_getptr_generic
#define ora_getptr_OCIAQDeqOptionsPtr ora_getptr_generic
#define ora_getptr_OCIAQEnqOptionsPtr ora_getptr_generic
#define ora_getptr_OCIAQMsgPropertiesPtr ora_getptr_generic
#define ora_getptr_OCIBindPtr ora_getptr_generic
#define ora_getptr_OCICallbackDefine ora_getptr_generic
#define ora_getptr_OCICallbackInBind ora_getptr_generic
#define ora_getptr_OCICallbackOutBind ora_getptr_generic
#define ora_getptr_OCICollPtr ora_getptr_generic
#define ora_getptr_OCIDefinePtr ora_getptr_generic
#define ora_getptr_OCIDescribePtr ora_getptr_generic
#define ora_getptr_OCIDurationPtr ora_getptr_generic
#define ora_getptr_OCIEnvPtr ora_getptr_generic
#define ora_getptr_OCIErrorPtr ora_getptr_generic
#define ora_getptr_OCIObjectEvent ora_getptr_generic
#define ora_getptr_OCIObjectProperty ora_getptr_generic
#define ora_getptr_OCIRawPtr ora_getptr_generic
#define ora_getptr_OCIRefPtr ora_getptr_generic
#define ora_getptr_OCIRefreshOpt ora_getptr_generic
#define ora_getptr_OCIResultPtr ora_getptr_generic
#define ora_getptr_OCIServerPtr ora_getptr_generic
#define ora_getptr_OCISessionPtr ora_getptr_generic
#define ora_getptr_OCISnapshotPtr ora_getptr_generic
#define ora_getptr_OCIStmtPtr ora_getptr_generic
#define ora_getptr_OCISvcCtxPtr ora_getptr_generic
#define ora_getptr_OCITypePtr ora_getptr_generic
#define ora_getptr_OCIUserCallback ora_getptr_generic
#define ora_getptr_OCIUserCallbackPtr ora_getptr_generic
#define ora_getptr_booleanPtr ora_getptr_generic
#define ora_getptr_sb4Ptr ora_getptr_generic
#define ora_getptr_size_tPtr ora_getptr_generic
#define ora_getptr_ub2Ptr ora_getptr_generic
#define ora_getptr_ub4Ptr ora_getptr_generic
#define ora_getptr_OCILobLocatorPtr ora_getptr_generic
