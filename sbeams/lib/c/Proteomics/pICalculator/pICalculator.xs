#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "calc_pI.h"

static int
not_here(char *s)
{
    croak("%s not implemented on this architecture", s);
    return -1;
}

static double
constant(char *name, int len, int arg)
{
    errno = EINVAL;
    return 0;
}

MODULE = pICalculator		PACKAGE = pICalculator		


double
constant(sv,arg)
    PREINIT:
	STRLEN		len;
    INPUT:
	SV *		sv
	char *		s = SvPV(sv, len);
	int		arg
    CODE:
	RETVAL = constant(s,len,arg);
    OUTPUT:
	RETVAL

double
COMPUTE_PI(seq,seq_length,charge_increment)
    INPUT:
	char *seq
	int seq_length
	int charge_increment
    OUTPUT:
	RETVAL
