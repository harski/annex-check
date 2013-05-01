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
	files		=> []
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

sub get_annex_output ($) {
	my $file = shift;
	my @output = `git-annex whereis $file 2>&1`;

	return @output;
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

sub handle_dir {
	my $dir = shift;
	my (%files) = %{shift()};

	my @content = read_dir($dir);
	foreach (@content) {
		if (-d) {
			push @{$files{"dirs"}}, "$_";
		} elsif (-l || -f) {
			push @{$files{"files"}}, "$_";
		}
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
} elsif (-l $path || -f $path) {
	push @{${files}{"files"}}, $path;
} elsif (not -e $path) {
	print STDERR "Target '$path' does not exist! Quitting...\n";
	exit 2
} else {
	print STDERR "Error: target is of unknown or unsupported type. Quitting...\n";
	exit 3;
}

# If in recursive mode, process the directories
if ($settings{"recursive"}) {
	while (my $dir = shift @{$files{"dirs"}}) {
		handle_dir($dir, \%files);
	}
}

# Loop through the files
foreach my $link (@{${files}{files}}) {
	my @output = get_annex_output($link);
	if (scalar(@output) > 0) {
		my @remotes = get_copy_remotes(@output);

		if (scalar(@remotes) == 1 && is_this_remote($remotes[0])) {
			print "File \"$link\" is fragile!\n";
		}
	} else {
		print STDERR "File '$link' is not annexed.\n";
	}
}

