#!/usr/bin/env perl

# Copyright (C) 2013 Tuomo Hartikainen <hartitu@gmail.com>
# Licensed under 2-clause BSD license, see LICENSE for more information.

use warnings;
use strict;
use Getopt::Long qw(:config no_ignore_case bundling);

my $VERSION = "0.1";

my %actions = (
	help	=> 0,
	version	=> 0
);

my %settings = (
	recursive	=> 0,
	verbose		=> 0
);

my %files = (
	dirs		=> [],
	files		=> [],
	symlinks	=> []
);

GetOptions (
	'h'		=> \$actions{help},
	'help'		=> \$actions{help},
	'r'		=> \$settings{recursive},
	'recursive'	=> \$settings{recursive},
	'v'		=> \$settings{verbose},
	'verbose'	=> \$settings{verbose},
	'V'		=> \$actions{version},
	'version'	=> \$actions{version},
	'usage'		=> \$actions{help}
);


sub action_given {
	my (%actions) = @_;
	foreach my $key (keys %actions) {
		if ($actions{$key}) {
			return 1;
		}
	}
	return 0;
}

sub get_copy_remotes (@) {
	my (@arr) = @_;
	my @ret;

	shift @arr;
	while (my $str = shift @arr) {
		last if ($str =~ m/^ok$/);
		if ($str =~ m/.* -- (.+)$/) {
			push @ret, $1;
		}
	}
	return @ret;
}

sub get_copies ($) {
	my ($str) = @_;
	if ($str =~ /^whereis .* \((\d+) cop.+\).*/) {
		if ($1) {
			return $1;
		}
	}
	return -1;
}

sub handle_dir {
	my $dir = shift;
	my (%files) = %{shift()};

	my @content = read_dir($dir);
	foreach (@content) {
		if (-d) {
			push @{$files{"dirs"}}, "$_";
		} elsif (-l) {
			push @{$files{"symlinks"}}, "$_";
		} elsif (-f) {
			push @{$files{"files"}}, "$_";
		}
	}
}

# Get directory contents, without "." and ".."
sub read_dir ($) {
	my ($dir) = @_;
	opendir(DIR, $dir) or die "Cannot open directory $!";
	my @files = readdir(DIR);
	closedir(DIR);

	my @res_files;
	foreach my $file (@files) {
		if ($file =~ /^\..*$/ ) {
			next;
		}
		push @res_files, "$dir/$file";
	}

	return @res_files;
}

sub get_annex_output ($) {
	my $file = shift;
	my @output = `git-annex whereis $file`;

	return @output;
}

sub handle_file ($) {
	my ($file) = @_;
	print STDERR "Warning: File $file is not added to git-annex"
		    ."index or is checked out\n";
}

sub handle_symlink ($) {
	my ($file) = @_;
	my @output = `git-annex whereis $file`;

	if (@output < 1) {
		print STDERR "file \"$file\" is not in git-annex index!\n";
		return;
	}
	my $copies = get_copies($output[0]);

	if ($copies==1) {
		# Only one copy, check if it is here
		print "File $file has only one copy!\n";

	} elsif ($copies==-1) {
		warn "Could not determine how many copies there if of"
		    ."file \"$file\" (most likely none)";
	} else {
		# File has multiple copies, all is well
	}
}

# Checks if the path is a valid git-annex path
sub is_annex_path {
	my $path = shift;
	`git-annex whereis $path > /dev/null 2>&1`;
	return not $?;
}

sub is_this_remote {
	my $remote = shift;
	if ($remote =~ /^here \(.*\)$/) {
		return 1;
	} else {
		return 0;
	}
}

sub print_usage () {
	print "Usage:\n";
	print "annex-check [DIR | FILE]\n";
}


# Check if custom action issued
if (action_given(%actions)) {
	if ($actions{help}) {
		print_usage();
	} elsif ($actions{version}) {
		print "annex-check version $VERSION\n";
		print "(c) 2013 Tuomo Hartikainen <hartitu\@gmail.com>\n";
		print "Licensed under 2-clause BSD license\n";
	}
	exit 0;
}

my $path;

# Check that path is supplied
if ($#ARGV >=0) {
	$path = $ARGV[0];
	if (not is_annex_path($path)) {
		print STDERR "Target '$path' is not a valid git-annex target.\n";
		exit 4
	}
} else {
	print STDERR "Error: Invalid or missing path.\n";
	print_usage();
	exit 1;
}

# Do the initial setup of the hash
if (-d $path) {
	handle_dir($path, \%files);
} elsif (-l $path) {
	push @{${files}{"symlinks"}}, $path;
} elsif (-f $path) {
	print STDERR "Error: target is not annexed or is checked out. Quitting...\n";
	exit 2;
} else {
	print STDERR "Error: target is of unknown or unsupported type. Quitting...";
	exit 3;
}

# If in recursive mode, process the directories
if ($settings{"recursive"}) {
	while (my $dir = shift @{$files{"dirs"}}) {
		handle_dir($dir, \%files);
	}
}

foreach my $link (@{${files}{symlinks}}) {
	my @output = get_annex_output($link);
	my @remotes = get_copy_remotes(@output);

	if (scalar(@remotes) == 1 && is_this_remote($remotes[0])) {
		print "File \"$link\" is fragile!\n";
	}
}

