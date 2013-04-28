#!/usr/bin/env perl

# Copyright (C) 2013 Tuomo Hartikainen <hartitu@gmail.com>
# Licensed under 2-clause BSD license, see LICENSE for more information.

use warnings;
use strict;

my $VERSION = "0.1";
my %settings = (
	recursive => 1
);

my %files = (
	dirs => [],
	files => [],
	symlinks => []
);


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

# Checks if the directory is a valid git-annex dir
sub is_annex_dir {
	my $dir = shift;
	if ($dir) {
		chdir($dir);
	}

	`git-annex whereis blaa > /dev/null 2>&1`;
	return not $?;
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
	print STDERR "Error: Root is not a regular directory!\n";
	exit 2;
}

