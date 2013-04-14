#!/usr/bin/env perl

# Copyright (C) 2013 Tuomo Hartikainen <hartitu@gmail.com>
# Licensed under 2-clause BSD license, see LICENSE for more information.

use warnings;
use strict;

sub get_copies ($) {
	my ($str) = @_;
	if ($str =~ /^whereis .* \((\d+) cop.+\).*/) {
		if ($1) {
			return $1;
		}
	}
	return -1;
}

sub handle_dir ($) {
	my ($dir) = @_;
	opendir(DIR, $dir) or die "Cannot open directory $!";
	my @files = readdir(DIR);
	closedir(DIR);

	foreach my $file (@files) {
		if ($file =~ /^\..*$/ ) {
			next;
		}
		my $fullpath = "$dir/$file";
		handle_path($fullpath);
	}
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

sub handle_path ($) {
	my ($path) = @_;
	if (-d $path) {
		handle_dir($path);
	} elsif (-f $path) {
		handle_file($path);
	} elsif (-l $path) {
		handle_symlink($path);
	} else {
		print STDERR "unknown filetype for file $path\n";
	}
}

sub print_usage () {
	print "Usage:\n";
	print "annex-check [FOLDER | FILE | .git]\n";
}

my $root;

if ($#ARGV >=0) {
	$root = $ARGV[0];
} else {
	print STDERR "Error: Invalid or missing path.\n";
	print_usage();
	exit 1;
}

if (-d $root) {
	handle_dir($root);
} else {
	print STDERR "Error: Root is not a regular direectory!\n";
	exit 2;
}

