# Copyright 1999-2007 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/app-portage/eclass-manpages/files/eclass-to-manpage.awk,v 1.2 2007/07/24 07:59:21 vapier Exp $

# This awk converts the comment documentation found in eclasses
# into man pages for easier/nicer reading.
#
# If you wish to have multiple paragraphs in a description, then
# create empty comment lines.  Paragraph parsing ends when the comment
# block does.
#
# The format of the eclass description:
# @ECLASS: foo.eclass
# @MAINTAINER:
# <required; list of contacts, one per line>
# @BLURB: <required; short description>
# @DESCRIPTION:
# <optional; long description>
# @EXAMPLE:
# <optional; example usage>

# The format of functions:
# @FUNCTION: foo
# @USAGE: <required arguments to foo> [optional arguments to foo]
# @MAINTAINER:
# <optional; list of contacts, one per line>
# @DESCRIPTION:
# <required; blurb about this function>

BEGIN {
	state = "header"
}

function warn(text) {
	print FILENAME ": " text > "/dev/stderr"
}
function fail(text) {
	warn(text)
	exit(1)
}

function eat_line() {
	ret = $0
	sub(/^# @[A-Z]*:[[:space:]]*/,"",ret)
	getline
	return ret
}
function eat_paragraph() {
	ret = ""
	getline
	while ($0 ~ /^#($| [^@])/) {
		sub(/^#[[:space:]]*/,"",$0)
		ret = ret "\n" $0
		getline
	}
	sub(/^\n/,"",ret)
	return ret
}

function man_text(p) {
	return gensub(/-/, "\\-", "g", p)
}

{
if (state == "header") {
if ($0 ~ /^# @ECLASS:/) {
	eclass = $3
	eclass_maintainer = ""
	blurb = ""
	desc = ""
	example = ""

	# first the man page header
	print ".TH \"" toupper(eclass) "\" 5 \"" strftime("%b %Y") "\" \"Portage\" \"portage\""

	# now eat the global data
	getline
	if ($2 == "@MAINTAINER:")
		eclass_maintainer = eat_paragraph()
	if ($2 == "@BLURB:")
		blurb = eat_line()
	if ($2 == "@DESCRIPTION:")
		desc = eat_paragraph()
	if ($2 == "@EXAMPLE:")
		example = eat_paragraph()

	# finally display it
	print ".SH \"NAME\""
	print eclass " \\- " man_text(blurb)
	print ".SH \"DESCRIPTION\""
	print man_text(desc)
	if (example != "") {
		print ".SH \"EXAMPLE\""
		print man_text(example)
	}

	# sanity checks
	if (blurb == "")
		fail("no @BLURB found")
	if (desc == "")
		fail("no @DESCRIPTION found")
	if (eclass_maintainer == "")
		warn("no @MAINTAINER found")

	print ".SH \"FUNCTIONS\""

	state = "functions"
}
} else if (state == "functions") {
if ($0 ~ /^# @FUNCTION:/) {
	func_name = $3
	usage = ""
	maintainer = ""
	desc = ""

	# grab the docs
	getline
	if ($2 == "@USAGE:")
		usage = eat_line()
	if ($2 == "@MAINTAINER:")
		maintainer = eat_paragraph()
	if ($2 == "@DESCRIPTION:")
		desc = eat_paragraph()

	# now print out the stuff
	print ".TP"
	print "\\fB" func_name "\\fR " man_text(usage)
	print man_text(desc)

	if (blurb == "")
		fail("no @BLURB found")
	if (desc == "")
		fail("no @DESCRIPTION found")
}
}
}

END {
if (eclass == "")
	fail("eclass not documented yet (no @ECLASS found)");

print ".SH \"REPORTING BUGS\""
print "Please report bugs via http://bugs.gentoo.org/"
print ".SH \"SEE ALSO\""
print ".BR ebuild (5)"
print ".SH \"FILES\""
print ".BR /usr/portage/eclass/" eclass
#print ".SH \"AUTHORS\""
# hmm, how to handle ?  someone will probably whine if we dont ...
if (eclass_maintainer != "") {
	print ".SH \"MAINTAINERS\""
	print man_text(eclass_maintainer)
}
}
