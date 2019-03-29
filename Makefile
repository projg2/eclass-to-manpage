AWK = gawk
SCRIPT = eclass-to-manpage.awk

ECLASSDIR = .
ECLASSES = $(wildcard ${ECLASSDIR}/*.eclass)

OUTDIR = .
MANPAGES = $(patsubst ${ECLASSDIR}/%.eclass,${OUTDIR}/%.5,${ECLASSES})

${OUTDIR}/%.5: ${ECLASSDIR}/%.eclass
	rm -f $@ $@.tmp
	${AWK} -f ${SCRIPT} $< > $@.tmp || [ $$? -eq 77 ]
	chmod a-w $@.tmp
	mv $@.tmp $@

all: ${MANPAGES}

clean:
	rm -f ${MANPAGES}

.PHONY: all clean
