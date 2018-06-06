The system man page finder
----

This was an attempt to write an auditor tool for \*NIX like systems.

I like man pages... well, in theory, most of the time they suck.
But having one is generally better than not having one... esp those
commands in `/bin` or SUID files or whatever.

I wrote this a billion years ago, plus or minus, which is why it's
in Perl, which had seen better days back then (that and the fact
that /usr/openwin/bin was in the path should hint to the age...)

I generally think there's a correlation: the more a system is used
the less documented they are, so it's fairest to run this right
after an install if doing compares.  Code bloated by wiring in a
few libraries for standalone running.


    Usage: i-heart-man.pl -h -v -m -s

      -h      print help and exit
      -v      verbose (for testing)
      -m      don't use the /etc/man*{cf,conf,config} file for more info
      -s      explicitly print out SUID/SGID files that are undocumented


This finds what which system commands have man pages (as well as
calculating a few percentages.  Looks through some system dirs -
currently /bin, /usr/bin, /sbin, & /usr/sbin, as well as some window
command dirs - /usr/openwin/bin & /usr/X11R6/bin - for potential
binary files (currently just looks for an executable bit).  It then
looks through the $MANPATH var (if it exists) as well as through
/usr/man, /usr/local/man, /usr/share/man, /usr/X11R6/man, &
/usr/openwin/man for man pages that might correspond.

Bugs - something well (overly? ;-)) documented like perl might not
have a man page; on my redhat system, for instance, there is a
binary called "perl5", but the man page is perl.1 (as well as a
zillion others in sub man pages).  Also doesn't check for info
pages; I can't find a man page (ahem) to see how it works (well,
it appears to have one now... but who uses it, anyway?)

Note that the more a system is used the less documented it will be,
and the -m flag might reflect this unfairly, as many net commands
are installed without man pages.


Most systems seem to be in the 80-90% range... but I see SUID files
and all sorts of things undocumnted all the time. Having "only" 100
undocumented commands in /bin, /usr/bin, and the like... doesn't
give me the warm and fuzzies.

But that's me.


Some results
----

It breaks the results out into three main areas - system (/bin,
/usr/bin, etc.), window commands (not as popular as they once
were, but...), and SUID & SUID commands.

From my heavily modified mac running 10.13.4 -

    $ i-heart-man.pl
    Total System Commands	Undocumented		% documented
    1786			521			70.8
    Total Window Commands	Undocumented		% documented
    124			113			 8.9
    Total Priv'd Commands	Undocumented		% documented
    16						100.0

A stock AWS ubuntu 16.04LTS system w/o X-Windows -

    Total System Commands	Undocumented		% documented
    1108			101			90.9

    (no Windowing specific commands found)

    Total Priv'd Commands	Undocumented		% documented
    18			1			94.4

Etcetera.

