ECLASSDIR = .
ECLASSES := $(sort $(wildcard ${ECLASSDIR}/*.eclass))

ifeq ($(ECLASSES),)
$(error ERROR: No eclass files found. Is ECLASSDIR "${ECLASSDIR}" valid?)
endif

OUTDIR = .
MANPAGES := $(patsubst ${ECLASSDIR}/%,${OUTDIR}/%.5,${ECLASSES})

DESTDIR =
PREFIX = /usr/local
MANDIR = $(PREFIX)/share/man
MAN5DIR = $(MANDIR)/man5

DISTNAME = eclass-manpages-$(shell date "+%Y%m%d")
DISTARCH = ${DISTNAME}.tar.xz
DISTFILES = COPYING Makefile

PMAINT = pmaint -q eclass -f man
INSTALL = install
TAR = tar --format=ustar --numeric-owner --owner 0 --group 0 --sort=name
TAR_X = tar -x -J
COMP = xz

all: ${MANPAGES}

${MANPAGES} &: ${ECLASSES}
	${PMAINT} -o "${OUTDIR}/{eclass}.eclass.5" $^

install: all
	${INSTALL} -d -m 0755 ${DESTDIR}${MAN5DIR}
	for f in ${MANPAGES}; do \
		! [ -s "$${f}" ] || ${INSTALL} -m 0644 $${f} ${DESTDIR}${MAN5DIR}/; \
	done

clean:
	rm -f ${MANPAGES}

dist:
	rm -r -f ${DISTNAME} ${DISTARCH}
	${INSTALL} -d -m 0755 ${DISTNAME}
	${INSTALL} -t ${DISTNAME} -m 0644 ${DISTFILES} ${ECLASSES}
	${TAR} -c ${DISTNAME} | ${COMP} -c > ${DISTARCH}
	rm -r -f ${DISTNAME}

distcheck: dist
	${TAR_X} -f ${DISTARCH}
	+${MAKE} -C ${DISTNAME}
	rm -r -f ${DISTNAME}

.PHONY: all install clean dist distcheck
