#!/usr/bin/perl

#
# Written a long time ago, in a galaxy... and all that.
#

#
# Below are notes from an email I found in my boneyard.
#
# ... I wired in realpath() and some options, including the -m
# which tries to find the /etc/man*{cf,config,conf} file for more paths.
# As the header comments say, the more a system is used the less documented
# they are, so it's fairest to run this right after an install if
# doing compares.  Code bloated by almost 200 lines by wiring in a few
# libraries (realpath, getopts) for standalone running.

#
#  The system man page finder
#
#  Usage: $0 -h -v -m -s
#
#	-h	print help and exit
#	-v	verbose (for testing)
#	-m	don't use the /etc/man*{cf,conf,config} file for more info
#	-s	explicitly print out SUID/SGID files that are undocumented
#
# This finds what which system commands have man pages (as well as calculating
# a few percentages.  Looks through some system dirs - currently /bin,
# /usr/bin, /sbin, & /usr/sbin, as well as some window command dirs -
# /usr/openwin/bin & /usr/X11R6/bin - for potential binary files 
# (currently just looks for an executable bit).  It then looks through 
# the $MANPATH var (if it exists) as well as through /usr/man, 
# /usr/local/man, /usr/share/man, /usr/X11R6/man, & /usr/openwin/man 
# for man pages that might correspond.
#
#  Bugs - something well (overly? ;-)) documented like perl might not 
# have a man page; on my redhat system, for instance, there is a binary 
# called "perl5", but the man page is perl.1 (as well as a zillion others
# in sub man pages).  Also doesn't check for info pages; I can't find a
# man page (ahem) to see how it works.
#
#   Note that the more a system is used the less documented it will be,
# and the -m flag might reflect this unfairly, as many net commands are 
# installed without man pages.
#
#

$usage = "Usage: $0 -h -v -m -s

    -h      print help and exit
    -v      verbose (for testing)
    -m      don't use the /etc/man*{cf,conf,config} file for more info
    -s      explicitly print out SUID/SGID files that are undocumented

";

use Getopt::Std;

%options=();

getopts("hvms", \%options);

if ($options{h}) {
    print $usage;
    exit(1);
}

$verbose = 1 if ($options{v});
$SID     = 1 if ($options{s});

@predefined_man_dirs = ("/usr/man", "/usr/local/man", "/usr/share/man", "/usr/X11R6/man", "/usr/openwin/man");

@predefined_cmd_dirs = ("/bin", "/usr/bin", "/sbin", "/usr/sbin", "/usr/ucb", "/usr/libexec");

@predefined_win_dirs = ("/usr/X11R6/bin", "/usr/bin/X11R6", "/usr/openwin/bin", "/usr/X11/bin", "/usr/bin/X11");

#
# go through all the man dirs and catalogue the individual pages
#
sub do_man_paths {
local(@man_page_dirs) = @_;

# run through the man dirs
for $m_dir (@man_page_dirs) {

	# print "looking at mdir $m_dir...\n";
	$realdir = &realpath($m_dir);
	next if $man_dirs_seen{$realdir};

	$man_dirs_seen{$realdir} = $realdir;
	# print "going into mdir $m_dir...\n";

	next unless -d $m_dir;

	# print "opening mdir $m_dir...\n";
	die "Can't open $m_dir\n" unless opendir(MDIR, $m_dir);

	# run through the stuff in the man dir
	while (($m_dir_ent = readdir(MDIR))) {
		$sub_dir = "$m_dir/$m_dir_ent";
		if (-d $sub_dir) {
			# disaster ;-)
			next if ($m_dir_ent eq "." || $m_dir_ent eq "..");

			# print "trying subdir $sub_dir\n";
			die "Can't open $sub_dir\n"
				unless opendir(MDIR_SUB, $sub_dir);

			# look at all man subdirs, where the man pages are
			while (($m_sub_dir_ent = readdir(MDIR_SUB))) {
				# disaster ;-)
				next if ($m_sub_dir_ent eq "." ||
					 $m_sub_dir_ent eq "..");

				# strip off .1, .2, etc.
				# print "trying $sub_dir/$m_sub_dir_ent\n";
				if (-f "$sub_dir/$m_sub_dir_ent") {
					# if they store them compressed...
					$m_sub_dir_ent =~ s/.gz$//;
					$m_sub_dir_ent =~ s/.Z$//;
					($man = $m_sub_dir_ent) =~ s/\.[^.]*$//;
					$all_man_pages{$man} = $man;
					# print "man page for $man\n";
					}
				}
			closedir(MDIR_SUB);
			}
		}
	closedir(MDIR);
	}

}

#
#  OK, now look at the commands... any appropriate man pages?
#
sub look_for_commands {
local(@bin_dirs) = @_;

for $dir (@bin_dirs) {

	chomp($dir);

	next if ($dir =~ /\n/);

	print "looking at bdir $dir... " if $debug;

	$realdir = &realpath($dir);
	chomp($realdir);

	next if ($realdir =~ /\n/);

	# print "\t=> $realdir...\n";
	# print "but really looking at $realdir...\n" if $debug;

	next if $realdir eq "";
	next if defined($cmd_dirs_seen{$realdir});

	$cmd_dirs_seen{$realdir} = $realdir;

	next unless -d $realdir;

	# print "\tlooking at realdir $dir\n";
	# print "\tbut really looking at $realdir...\n";

	die "Can't open $realdir\n" unless opendir(DIR, $realdir);
	print "processing dir $realdir...\n" if $verbose;
	while (($dir_ent = readdir(DIR))) {

		# keep track of special files
		$suid = $sgid = 0;

		next if ($dir_ent eq "." || $dir_ent eq "..");
		$target = "$dir/$dir_ent";

                # -u   File has setuid bit set.
                # -g   File has setgid bit set.

		# has to be executable and not a link
		next unless -f $target && -x $target && ! -l $target;


		# print "exe\t$target\n";

		$sgid = $suid = 0;

		# If they're SUID/SGID keep track of them
		if (-u $target) {
			print "SUID file: $target\n" if $debug;
			# print "\tSUID($tot_privd):";
			$suid = 1;
			}
		if (-g $target) {
			print "SGID file: $target\n" if $debug;
			# print "\tSGID($target=>$tot_privd):";
			$sgid = 1;
			}

		if ($suid || $guid) {
			$SxID = 1;
			if (!defined($tot_privd_files{$target})) {
				$tot_privd_files{$target}++;
				$tot_privd++;
				}
			# print "SxID:($tot_privd) = $target\n";
			}

		# print "next: $target => $dir_ent\n";
		if (!defined($all_man_pages{$dir_ent})) {

			$suid = 1 if -u $target;
			$sgid = 1 if -g $target;

			#
			# weasel time.  They should still doc, but I'll 
			# cut them some slack... grrr....
			#
			# ok... if the file has 2 dots between numbers
			# (e.g. perl5.5.5) AND there is a file that either:
			#
			# has the same name after first numbers (perl5)
			#	or
			# has the same name minus all numbers (perl)
			#
			# Don't count it.  They have to be in the same dir tho.
			#
			# foo1.22.3
			if ($target =~ /\d+\.\d+\.\d+/) {
				$test_ent = $dir_ent;
				$test_ent =~ s/\d+\.\d+\.\d+//;

				# print "double dotted alert - $target => $test_ent\n";

				# already have been here...
				if (defined($all_cmds{$test_ent})) {
					# print "found a match... $all_cmds{$dir_ent}\n";
					next;
					}
				else {
					# print "busted.\n";
					}
				}

			$all_cmds{$dir_ent} = $target;

			print "Can't find man page for $dir/$dir_ent\n" if $verbose && !$SID;

			# print "$dir_ent\n";
			$num_undoc_exes++;

			if ($suid || $sgid) {
			    print "SUID/!DOC = $target\n" if $verbose;
			    print "SGID/!DOC = $target\n" if $verbose;

				if (!defined($tot_privd_undoc_files{$target})) {
					$tot_privd_undoc_files{$target}++;
					$tot_privd_undoc++;
					}
				}
			}
		else {
			$num_doc_exes++;
			}
		}
	closedir(DIR);
	}
}

#
# parse 'n' drag stuff out of /etc/man*{conf,cf} (thanks to erik fair
# for this!)  Currently I recognize three keywords, in the form:
#
#	MANPATH_MAP		/foo/bindir	/bar/mandir
#	MANDATORY_MANPATH	/bar/mandir
#	MANPATH			/bar/mandir
#
# This function adds the appropriate dirs to the paths searched and
# searched for for vars
#
sub suck_etc_conf {

# any man conf files out there?
$res = ($conf = (</etc/man*{config,conf,cf}>));

#
# if there are more than one, give up and use my hardcoded stuff
#
if ($res > 1) {
	warn "Can't figure out which man conf file to use, bailing to default paths/files!\n";
	return;
	}

if (-f $conf) {
	print "CONF: $conf\n" if $debug;
	if (!open(CONF, $conf)) {
		warn "Can't open $conf\n" unless open(CONF, $conf);
		return;
		}
	else {
		while (<CONF>) {
			s/\s*$//;
			chop;
			#
			# look for the good stuff, skipping dups
			#
			if (/^\s*MANPATH_MAP/) {
				($x, $cmd_dir, $man_dir) = split();

				# skip symlinks... or, rather, add the real one
				$man_dir = realpath($man_dir);
				$cmd_dir = realpath($cmd_dir);

				push(@manpath, $man_dir) if !defined($man{$man_dir});

				#
				# I want to do window systems seperately...
				#
				if (!$cmd{$cmd_dir} && (!/X11/ && !/openwin/)){
					# print "pushing $cmd_dir onto stack\n";
					push(@cmdpath, $cmd_dir) if !defined($cmd{$cmd_dir});
					}
				elsif (!$man{$cmd_dir} && (/X11/ || /openwin/)){
					push(@winpath, $cmd_dir) if !defined($man{$cmd_dir});
					}

				$cmd{$cmd_dir} = $cmd_dir;
				$man{$man_dir} = $man_dir;
				}
			if (/^\s*MANDATORY_MANPATH/) {
				($x, $man_dir) = split();
				push(@manpath, $man_dir) if !$man{$man_dir};
				$man{$man_dir} = $man_dir;
				}
			if (/^\s*OPTIONAL_MANPATH/) {
				($x, $man_dir) = split();
				push(@manpath, $man_dir) if !$man{$man_dir};
				$man{$man_dir} = $man_dir;
				}
			}
		}
	}

# for $conf (</etc/man*{config,conf,cf}>) {

}

#
#  the next few functions taken from File::PathConvert, at:
#
# http://www.oasis.leo.org/perl/exts/filehandling/File-PathConvert.dsc.html
#
#  I ripped out the realpath stuff, made it a normal subroutine instead
# of all that module crap, fixed some spelling, added a one-line cwd
# function (for older perls) and otherwise changed it very slightly.  Thanks
# to Shigio for the code!  Original copyright:
#
# 	Copyright (c) 1996 Shigio Yamaguchi. All rights reserved.
# 	This program is free software; you can redistribute it and/or
#	modify it under the same terms as Perl itself.
#
#				23-Oct-1996 Shigio Yamaguchi
#
#
#  (last mods by zen@fish.com, may 15, 2000)
#

@ISA = qw(Exporter);
@EXPORT_OK = qw(realpath abs2rel rel2abs);

#
# instant configuration
#
$maxsymlinks = 32;		# allowed symlink number in a path
# $debug = 0;			# 1: verbose on, 0: verbose off
$SL = '/';			# separator

#
# realpath: returns the canonicalized absolute path name
#
# Interface:
#	i)	$path	path
#	r)		resolved name on success else undef
#	go)	$resolved
#			resolved name on success else the path name which
#			caused the problem.
	$resolved = '';
#
#	Note: this implementation is based 4.4BSD version realpath(3).
#
sub realpath {
    ($resolved) = @_;
    my($backdir) = `pwd`;
    my($dirname, $basename, $links, $reg);

    regularize($resolved);
LOOP:
    {
	#
	# Find the dirname and basename.
	# Change directory to the dirname component.
	#
	if ($resolved =~ /$SL/) {
	    $reg = '^(.*)' . $SL . '([^' . $SL . ']*)$';
	    ($dirname, $basename) = $resolved =~ /$reg/;
	    $dirname = $SL if (!$dirname);
	    $resolved = $dirname;
	    unless (chdir($dirname)) {
		warn("realpath: chdir($dirname) failed.") if $debug;
		chdir($backdir);
		return undef;
	    }
	} else {
	    $dirname = '';
	    $basename = $resolved;
	}
	#
	# If it is a symlink, read in the value and loop.
	# If it is a directory, then change to that directory.
	#
	if ($basename) {
	    if (-l $basename) {
		unless ($resolved = readlink($basename)) {
		    warn("realpath: readlink($basename) failed.") if $debug;
		    chdir($backdir);
		    return undef;
		}
		$basename = '';
		if (++$links > $maxsymlinks) {
		    warn("realpath: too many symbolic links.") if $debug;
		    chdir($backdir);
		    return undef;
		}
		redo LOOP;
	    } elsif (-d _) {
		unless (chdir($basename)) {
		    warn("realpath: chdir($basename) failed.") if $debug;
		    chdir($backdir);
		    return undef;
		}
		$basename = '';
	    }
	}
    }
    #
    # Get the current directory name and append the basename.
    #
    $resolved = `pwd`;
    if ($basename) {
	$resolved .= $SL if ($resolved ne $SL);
	$resolved .= $basename
    }
    chdir($backdir);
    return $resolved;
}

#
# regularize a path.
#
sub regularize {
    my($reg);

    $reg = '^' . $SL . '\.\.' . $SL;
    while ($_[0] =~ /$reg/) {           # ^/../ -> /
        $_[0] =~ s/$reg/$SL/;
    }
    $reg = $SL . '\.' . $SL;
    while ($_[0] =~ /$reg/) {
        $_[0] =~ s/$reg/$SL/;           # /./ -> /
    }
    $reg = $SL . '+';
    $_[0] =~ s/$reg/$SL/g;              # ///  -> /
    $reg = '(.+)' . $SL . '$';
    $_[0] =~ s/$reg/$1/;                # remove last /
    $reg = '(.+)' . $SL . '\.$';
    $_[0] =~ s/$reg/$1/g;               # remove last /.
    $_[0] = '/' if $_[0] eq '/.';
}


#
# back to my code...
#

# for (@manpath) { print "MAN: $_\n"; }
# for (@cmdpath) { print "CMD: $_\n"; }

# take stuff from the environ if possible...
if (defined($ENV{MANPATH})) { @manpath = split(/:/, $ENV{MANPATH}); }
push(@manpath, @predefined_man_dirs);

#
# now get it from system
#
&suck_etc_conf() if ! $opt_m;

#
# suck in the man pages
#
&do_man_paths(@manpath);

#
# now look at the commands; do they have man pages?
#
push(@cmdpath, @predefined_cmd_dirs);
&look_for_commands(@cmdpath);

if ($verbose) {
	print "\nSystem directories: ";
	for (keys %cmd_dirs_seen) { print $_ . " "; }
    print "\n";
	}

if ($num_doc_exes+$num_undoc_exes) {
	print "Total System Commands\tUndocumented\t\t% documented\n";
	printf("%d\t\t\t$num_undoc_exes\t\t\t%4.1f\n", $num_undoc_exes+$num_doc_exes, 100 * $num_doc_exes/($num_doc_exes+$num_undoc_exes));
	}
else { print "\n(no System commands found (something is wrong ;)))\n\n"; }

$num_undoc_exes = $num_doc_exes = 0;

### back in the day this worked better... now when windows are just
# linked to /usr/bin (on my linux this is questionable... so kill it
# undef(%cmd_dirs_seen);

# print "WINPATH: @winpath  PWD: @predefined_win_dirs \n";
push(@winpath, @predefined_win_dirs);

&look_for_commands(@winpath);

if ($verbose) {
	print "\n\nWindow system directories ";
	for (keys %cmd_dirs_seen) { print $_ . " "; }
    print "\n";
	}

if ($num_doc_exes+$num_undoc_exes) {
	print "Total Window Commands\tUndocumented\t\t% documented\n";
	printf("%d\t\t\t$num_undoc_exes\t\t\t%4.1f\n", $num_undoc_exes+$num_doc_exes, 100 * $num_doc_exes/($num_doc_exes+$num_undoc_exes));

	}
else { print "\n(no Windowing specific commands found)\n\n"; }

if ($SxID) {
	print "Total Priv'd Commands\tUndocumented\t\t% documented\n";
	printf("%d\t\t\t$tot_privd_undoc\t\t\t%4.1f\n", $tot_privd, 100 * (1 - $tot_privd_undoc/$tot_privd));
	}

