#!/usr/bin/awk -f
# Copyright 2007-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# This awk converts the comment documentation found in eclasses
# into man pages for easier/nicer reading.
#
# If you wish to have multiple paragraphs in a description, then
# create empty comment lines.  Paragraph parsing ends when the comment
# block does.

# The format of the eclass description:
# @ECLASS: foo.eclass
# @MAINTAINER:
# <required; list of contacts, one per line>
# @AUTHOR:
# <optional; list of authors, one per line>
# @BUGREPORTS:
# <optional; description of how to report bugs;
#  default: tell people to use bugs.gentoo.org>
# @VCSURL: <optional; url to vcs for this eclass; default: https://gitweb.gentoo.org/repo/gentoo.git/log/eclass/@ECLASS@>
# @SUPPORTED_EAPIS: <optional; space-separated list of EAPIs>
# @BLURB: <required; short description>
# @DEPRECATED: <optional; replacement ("none" for no replacement)>
# @DESCRIPTION:
# <optional; long description>
# @EXAMPLE:
# <optional; example usage>

# The format of functions:
# @FUNCTION: foo
# @USAGE: <required arguments to foo> [optional arguments to foo]
# @RETURN: <whatever foo returns>
# @MAINTAINER:
# <optional; list of contacts, one per line>
# [@INTERNAL]
# [@INCLUDES_EPREFIX] (the function outputs path that includes ${EPREFIX})
# @DEPRECATED: <optional; replacement ("none" for no replacement)>
# @DESCRIPTION:
# <required if no @RETURN; blurb about this function>

# The format of function-specific variables:
# @VARIABLE: foo
# [@USER_VARIABLE] (set in make.conf, not ebuilds)
# [@INTERNAL] (internal eclass use variable)
# [@DEFAULT_UNSET]
# [@REQUIRED]
# [@INCLUDES_EPREFIX] (the variable is a path that includes ${EPREFIX})
# @DEPRECATED: <optional; replacement ("none" for no replacement)>
# @DESCRIPTION:
# <required; blurb about this variable>
# foo="<default value>"

# The format of eclass variables:
# @ECLASS-VARIABLE: foo
# [@PRE_INHERIT] (the variable must be set before inheriting the eclass)
# [@USER_VARIABLE] (set in make.conf, not ebuilds)
# [@OUTPUT_VARIABLE] (set by eclass, to be read in ebuilds)
# [@INTERNAL] (internal eclass use variable)
# [@DEFAULT_UNSET]
# [@REQUIRED]
# [@INCLUDES_EPREFIX] (the variable is a path that includes ${EPREFIX})
# @DEPRECATED: <optional; replacement ("none" for no replacement)>
# @DESCRIPTION:
# <required; blurb about this variable>
# foo="<default value>"

# Disable manpage generation:
# @DEAD

# Common features:
# @CODE
# In multiline paragraphs, you can create chunks of unformatted
# code by using this marker at the start and end.
# @CODE
#
# @SUBSECTION <title>
# Insert a subsection heading.  Only allowed in the main @DESCRIPTION.
#
# @ROFF <some roff macros>
# If you want a little more manual control over the formatting, you can
# insert roff macros directly into the output by using the @ROFF escape.
# Note:  The @ROFF token is deprecated and exists only for backwards
# compatibility.  Do not use it in new documentation.

function _stderr_msg(text, type,   file, cnt) {
	if (_stderr_header_done != 1) {
		cnt = split(FILENAME, file, /\//)
		print "\n" file[cnt] ":" > "/dev/stderr"
		_stderr_header_done = 1
	}

	print "   " type ":" NR ": " text > "/dev/stderr"
}
function warn(text) {
	_stderr_msg(text, "warning")
}
function fail(text) {
	_stderr_msg(text, "error")
	exit(1)
}
function xfail(text) {
	_stderr_msg(text, "error (ignoring)")
	exit(77)
}

function eat_line() {
	ret = $0
	sub(/^# @[^:]+:[[:space:]]*/,"",ret)
	getline
	return ret
}
function eat_paragraph() {
	code = 0
	ret = ""
	getline
	while ($0 ~ /^#/) {
		# Only allow certain tokens in the middle of paragraphs
		if ($2 ~ /^@/ && $2 !~ /^@(CODE|ROFF|SUBSECTION)$/)
			break

		sub(/^#[[:space:]]?/, "", $0)

		# Escape . and ' at start of line #420153
		if ($0 ~ /^[.']/)
			$0 = "\\&" $0

		# Translate @CODE into .nf/.fi pair
		if ($1 == "@CODE" && NF == 1) {
			if (code)
				$0 = ".fi"
			else
				$0 = ".nf"
			code = !code
		}

		# Insert a subsection heading
		if ($1 == "@SUBSECTION") {
			if (NF < 2) fail(eclass ": @SUBSECTION without title")
			$1 = ".SS"
		}

		# Allow people to specify *roff commands directly
		if ($1 == "@ROFF") {
			warn(eclass ": the @ROFF tag is deprecated")
			sub(/^@ROFF[[:space:]]*/, "", $0)
		}

		ret = ret "\n" $0

		# Handle the common case of trailing backslashes in
		# code blocks to cross multiple lines #335702
		if (code && $NF == "\\")
			ret = ret "\\"
		getline
	}
	sub(/^\n/,"",ret)
	return ret
}

function pre_text(p) {
	return gensub(/\n/, "\n.br\n", "g", p)
}

function man_text(p) {
	return gensub(/-/, "\\-", "g", p)
}

#
# Handle an @ECLASS block
#
function handle_eclass() {
	eclass = $3
	eclass_maintainer = ""
	eclass_author = ""
	supported_eapis = ""
	provides = ""
	blurb = ""
	deprecated = ""
	desc = ""
	example = ""

	# Sanity check the eclass name. #537392
	if (eclass !~ /[.]eclass$/)
		fail(eclass ": @ECLASS name is missing a '.eclass' suffix")

	# first the man page header
	print ".\\\" -*- coding: utf-8 -*-"
	print ".\\\" ### DO NOT EDIT THIS FILE"
	print ".\\\" ### This man page is autogenerated by eclass-to-manpage.awk"
	print ".\\\" ### based on comments found in " eclass
	print ".\\\""
	print ".\\\" See eclass-to-manpage.awk for documentation on how to get"
	print ".\\\" your eclass nicely documented as well."
	print ".\\\""
	print ".TH \"" toupper(eclass) "\" 5 \"" strftime("%b %Y") "\"" \
		" \"Gentoo Linux\" \"eclass-manpages\""

	# now eat the global data
	getline
	if ($2 == "@MAINTAINER:")
		eclass_maintainer = eat_paragraph()
	if ($2 == "@AUTHOR:")
		eclass_author = eat_paragraph()
	if ($2 == "@BUGREPORTS:")
		reporting_bugs = eat_paragraph()
	if ($2 == "@VCSURL:")
		vcs_url = eat_line()
	if ($2 == "@SUPPORTED_EAPIS:")
		supported_eapis = eat_line()
	if ($2 == "@PROVIDES:")
		provides = eat_line()
	if ($2 == "@BLURB:")
		blurb = eat_line()
	if ($2 == "@DEPRECATED:")
		deprecated = eat_line()
	if ($2 == "@DESCRIPTION:")
		desc = eat_paragraph()
	if ($2 == "@EXAMPLE:")
		example = eat_paragraph()
	# in case they typo-ed the keyword, bail now
	if ($2 ~ /^@/)
		fail(eclass ": unknown keyword " $2)

	# finally display it
	print ".SH \"NAME\""
	print eclass " \\- " man_text(blurb)
	if (deprecated != "") {
		print ".SH \"DEPRECATED\""
		print "Replacement: " man_text(deprecated)
	}
	if (desc != "") {
		print ".SH \"DESCRIPTION\""
		print man_text(desc)
	}
	if (supported_eapis != "") {
		print ".SH \"SUPPORTED EAPIS\""
		print man_text(supported_eapis)
	}
	if (provides != "") {
		print ".SH \"TRANSITIVELY PROVIDED ECLASSES\""
		print man_text(provides)
	}
	if (example != "") {
		print ".SH \"EXAMPLE\""
		print man_text(example)
	}

	# sanity checks
	if (blurb == "")
		fail(eclass ": no @BLURB found")
	if (eclass_maintainer == "")
		warn(eclass ": no @MAINTAINER found")
}

#
# Handle a @FUNCTION block
#
function show_function_header() {
	if (_function_header_done != 1) {
		print ".SH \"FUNCTIONS\""
		_function_header_done = 1
	}
}
function handle_function() {
	func_name = $3
	usage = ""
	funcret = ""
	maintainer = ""
	internal = 0
	deprecated = ""
	desc = ""

	# make sure people haven't specified this before (copy & paste error)
	if (all_funcs[func_name])
		fail(eclass ": duplicate definition found for function: " func_name)
	all_funcs[func_name] = func_name

	# grab the docs
	getline
	if ($2 == "@USAGE:")
		usage = eat_line()
	if ($2 == "@RETURN:")
		funcret = eat_line()
	if ($2 == "@MAINTAINER:")
		maintainer = eat_paragraph()
	if ($2 == "@INTERNAL") {
		internal = 1
		getline
	}
	if ($2 == "@INCLUDES_EPREFIX") {
		includes_eprefix = 1
		getline
	}
	if ($2 == "@DEPRECATED:")
		deprecated = eat_line()
	if ($2 == "@DESCRIPTION:")
		desc = eat_paragraph()

	if (internal == 1)
		return

	show_function_header()

	# now print out the stuff
	print ".TP"
	print "\\fB" func_name "\\fR " man_text(usage)
	if (desc != "")
		print man_text(desc)
	if (funcret != "") {
		if (desc != "")
			print ""
		print "Return value: " funcret
	}

	if (blurb == "")
		fail(func_name ": no @BLURB found")
	if (desc == "" && funcret == "")
		fail(func_name ": no @DESCRIPTION found")
}

#
# Handle @VARIABLE and @ECLASS-VARIABLE blocks
#
function _handle_variable() {
	var_name = $3
	deprecated = ""
	desc = ""
	val = ""
	default_unset = 0
	internal = 0
	required = 0

	# additional variable classes
	pre_inherit = 0
	user_variable = 0
	output_variable = 0

	# make sure people haven't specified this before (copy & paste error)
	if (all_vars[var_name])
		fail(eclass ": duplicate definition found for variable: " var_name)
	all_vars[var_name] = var_name

	# grab the optional attributes
	opts = 1
	while (opts) {
		getline
		if ($2 == "@DEFAULT_UNSET")
			default_unset = 1
		else if ($2 == "@INTERNAL")
			internal = 1
		else if ($2 == "@REQUIRED")
			required = 1
		else if ($2 == "@PRE_INHERIT")
			pre_inherit = 1
		else if ($2 == "@USER_VARIABLE")
			user_variable = 1
		else if ($2 == "@OUTPUT_VARIABLE")
			output_variable = 1
		else if ($2 == "@INCLUDES_EPREFIX")
			includes_eprefix = 1
		else
			opts = 0
	}
	if ($2 == "@DEPRECATED:")
		deprecated = eat_line()
	if ($2 == "@DESCRIPTION:")
		desc = eat_paragraph()

	# extract the default variable value
	# first try var="val"
	op = "="
	regex = "^.*" var_name "=(.*)$"
	val = gensub(regex, "\\1", 1, $0)
	if (val == $0) {
		# next try : ${var:=val}
		op = "?="
		regex = "^[[:space:]]*:[[:space:]]*[$]{" var_name ":?=(.*)}"
		val = gensub(regex, "\\1", 1, $0)
		if (val == $0) {
			if (default_unset + required + internal + output_variable == 0)
				warn(var_name ": unable to extract default variable content: " $0)
			val = ""
		} else if (val !~ /^["']/ && val ~ / /) {
			if (default_unset == 1)
				warn(var_name ": marked as unset, but has value: " val)
			val = "\"" val "\""
		}
	}
	if (length(val))
		val = " " op " \\fI" val "\\fR"
	if (required == 1)
		val = val " (REQUIRED)"
	# TODO: group variables using those classes
	if (pre_inherit == 1)
		val = val " (SET BEFORE INHERIT)"
	if (user_variable == 1)
		val = val " (USER VARIABLE)"
	if (output_variable == 1)
		val = val " (GENERATED BY ECLASS)"

	# check for invalid combos
	if (internal + pre_inherit + user_variable + output_variable > 1)
		fail(var_name ": multiple variable classes specified")

	if (internal == 1)
		return ""

	# now accumulate the stuff
	ret = \
		".TP" "\n" \
		"\\fB" var_name "\\fR" val "\n" \
		man_text(desc)

	if (desc == "")
		fail(var_name ": no @DESCRIPTION found")

	return ret
}
function handle_variable() {
	show_function_header()
	ret = _handle_variable()
	if (ret == "")
		return
	print ret
}
function handle_eclass_variable() {
	ret = _handle_variable()
	if (ret == "")
		return
	if (eclass_variables != "")
		eclass_variables = eclass_variables "\n"
	eclass_variables = eclass_variables ret
}

#
# Spit out the common footer of manpage
#
function handle_footer() {
	if (eclass_variables != "") {
		print ".SH \"ECLASS VARIABLES\""
		print man_text(eclass_variables)
	}
	if (eclass_author != "") {
		print ".SH \"AUTHORS\""
		print pre_text(man_text(eclass_author))
	}
	if (eclass_maintainer != "") {
		print ".SH \"MAINTAINERS\""
		print pre_text(man_text(eclass_maintainer))
	}
	print ".SH \"REPORTING BUGS\""
	print reporting_bugs
	print ".SH \"FILES\""
	print ".BR " eclass
	print ".SH \"SEE ALSO\""
	print ".BR ebuild (5)"
	print ".br"
	print gensub("@ECLASS@", eclass, 1, vcs_url)
}

#
# Init parser
#
BEGIN {
	state = "header"
	reporting_bugs = "Please report bugs via https://bugs.gentoo.org/"
	vcs_url = "https://gitweb.gentoo.org/repo/gentoo.git/log/eclass/@ECLASS@"
}

#
# Main parsing routine
#
{
	if (state == "header") {
		if ($0 ~ /^# @ECLASS:/) {
			handle_eclass()
			state = "funcvar"
		} else if ($0 == "# @DEAD") {
			eclass = "dead"
			exit(77)
		} else if ($0 == "# @eclass-begin") {
			# White list old eclasses that haven't been updated so we can block
			# new ones from being added to the tree.
			if (eclass == "")
				xfail("java documentation not supported")
			fail("java documentation not supported")
		} else if ($0 ~ /^# @/)
			warn("Unexpected tag in \"" state "\" state: " $0)
	} else if (state == "funcvar") {
		if ($0 ~ /^# @FUNCTION:/)
			handle_function()
		else if ($0 ~ /^# @VARIABLE:/)
			handle_variable()
		else if ($0 ~ /^# @ECLASS-VARIABLE:/)
			handle_eclass_variable()
		else if ($0 ~ /^# @/)
			warn("Unexpected tag in \"" state "\" state: " $0)
	}
}

#
# Tail end
#
END {
	if (eclass == "")
		xfail("eclass not documented yet (no @ECLASS found)")
	else if (eclass != "dead")
		handle_footer()
}
