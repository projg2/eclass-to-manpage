AWK = gawk
INSTALL = install
SCRIPT = eclass-to-manpage.awk

ECLASSDIR = .
ECLASSES = $(wildcard ${ECLASSDIR}/*.eclass)

OUTDIR = .
MANPAGES = $(sort $(patsubst ${ECLASSDIR}/%,${OUTDIR}/%.5,${ECLASSES}))
ERRFILES = $(sort $(patsubst ${ECLASSDIR}/%,${OUTDIR}/%.5.err,${ECLASSES}))

DESTDIR =
PREFIX = /usr/local
MANDIR = $(PREFIX)/share/man
MAN5DIR = $(MANDIR)/man5

${OUTDIR}/%.5: ${ECLASSDIR}/%
	rm -f $@ $@.tmp
	${AWK} -f ${SCRIPT} $< > $@.tmp 2> $@.err || [ $$? -eq 77 ]
	chmod a-w $@.tmp
	mv $@.tmp $@

all: ${MANPAGES}
	[ -z "${ERRFILES}" ] || cat ${ERRFILES}

install: all
	install -d -m 0755 ${DESTDIR}${MAN5DIR}
	for f in ${MANPAGES}; do \
		! [ -s "$${f}" ] || ${INSTALL} -m 0644 $${f} ${DESTDIR}${MAN5DIR}/; \
	done

clean:
	rm -f ${MANPAGES} ${ERRFILES}

.PHONY: all install clean
