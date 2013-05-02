#!/usr/bin/env perl
use strict;
use warnings;

use Archive::Tar;
use Getopt::Long;
use Archive::Extract;
use File::MimeInfo;
use File::Path qw(make_path remove_tree);
use File::Find::Rule;
use File::Copy;
use Cwd;

my $tar = Archive::Tar->new;
my $templateFileName;		# tar file, contain template structure of assignment
my $templateDir;			# dir contain template structure of assignment
my $baseFilesDir;			# dir contain base files
my $assDir;					# directory of downloaded archived assignments
my @tempFileList;
my %langs;
my $debug = 1;
my @errorAss;

GetOptions( "t:s" => \$templateFileName,
			"T:s" => \$templateDir,
			"d:s" => \$assDir,
			"B:s" => \$baseFilesDir);


if ($templateFileName)
{
	print "using tempalte file: $templateFileName\n";
	$tar->read($templateFileName);
	@tempFileList = $tar->list_files();


	foreach (@tempFileList)
	{
		my @spt = split(/\//, $_);
		if ($spt[1] and $spt[2])
		{
			push(@{$langs{$spt[1]}}, $spt[2]);
		}
	}
}

elsif ($templateDir)
{
	print "using template dir: $templateDir\n";
	my $rule = File::Find::Rule->new();
	$rule->directory();
	$rule->maxdepth(1);
	$rule->mindepth(1);
	my @dirs = $rule->in($templateDir);
	foreach my $dir (@dirs)
	{
		print "dir: $dir\n" if $debug;
		my @dirsp = split(/\//, $dir);
		my $fule = File::Find::Rule->new();
		$fule->file();
		$fule->maxdepth(1);
		$fule->mindepth(1);
		my @files = $fule->in($dir);
		foreach my $ff (@files)
		{
			print "\tfile: $ff\n" if $debug;
			my @ffsp = split(/\//, $ff);
			push(@{$langs{$dirsp[-1]}}, $ffsp[-1]);
		}
	}
}
else
{
	die "you should specify a template dir or template file ...\n";
}

# get list of basefiles
my $bule = File::Find::Rule->new();
$bule->file();
my @bfList = $bule->in($baseFilesDir);

print "=========== END of Template ==============\n" if $debug;

foreach my $key (sort keys %langs)
{
	print "$key\n" if $debug;
	print "files: " if $debug;
	foreach my $f (@{$langs{$key}})
	{
		print "$f " if $debug;
	}
	print "\n" if $debug;
}



my $repoDir = $assDir . "/repo/";
my $tmpDir = $assDir . "/tmp/";
remove_tree($repoDir);			# clear repo and tmp, if they are exists
remove_tree($tmpDir);

my @assFiles = <$assDir/*>;		# get list of files in assDir

print "create dir: $repoDir\n" if $debug;
print "create dir: $tmpDir\n" if $debug;
mkdir("$repoDir");
mkdir("$tmpDir");

foreach my $f (@assFiles)
{
	my $ok = 0;
	my @fnspt = split(/\//, $f);		# split file path
	my $fn = $fnspt[-1];				# get the last part, file name
	$fn =~ s/ /_/g;
	my $extPath = $tmpDir . $fn;
	my $repoPath = $repoDir . $fn;
	print "extPath: $extPath\n";
	mkdir($extPath);
	mkdir($repoPath);

	my $ft = File::MimeInfo->new();
	my $fileType = $ft->mimetype($f);
	print "file type is: $fileType\n" if $debug;
	if ($fileType =~ /rar$/)
	{
		print "Rar archive ...\n" if $debug;
		my @rarcmd = ("unrar", "e", "-y", "$f", "$extPath");
		$ok = system(@rarcmd);
	}
	elsif ($fileType =~ /x-7z-compressed$/)
	{
		print "7z archive ...\n" if $debug;
		my @_7zcmd = ("7z", "x", "-y", "-o$extPath", "$f");
		$ok = system(@_7zcmd);
	}
	else
	{
		my $ar = Archive::Extract->new(archive => $f);
		$ok = $ar->extract(to => $extPath);
	}
	if ($ok != 0)
	{
		print "some error on extracting: $f\n";
		push(@errorAss, $fn);
	}
	# construct template for each assignment
	foreach my $lang (keys %langs)
	{
		my $langPath = $repoPath . "/$lang/";
		mkdir($langPath);
		my $rule =  File::Find::Rule->new;
		$rule->file();
		my @pattern;
		foreach my $pt (@{$langs{$lang}})
		{
			print "pt: $pt\n" if $debug;
			my @ptsplit = split(/\./, $pt);
			push(@pattern, "*." . $ptsplit[-1]);
		}
		$rule->name(@pattern);
		my @files = $rule->in($extPath);
		foreach my $ff (@files)
		{
			# TODO
			# check mime for apple back up
			my $appleMime = File::MimeInfo->new();
			my $aft = $appleMime->mimetype($ff);
			print "AFT: $aft\n" if $debug;
			copy($ff, $langPath);
		}
	}
	remove_tree($extPath) unless $debug;
}

# now repo is ready run moss command
foreach my $lang (keys %langs)
{
	my @mosscmd = ("perl", "moss.pl");
	foreach my $bf (@bfList)
	{
		push(@mosscmd, "-b");
		push(@mosscmd, $bf);
	}
	push(@mosscmd, "-l");
	push(@mosscmd, "$lang");
	push(@mosscmd, "-d");
	foreach my $ext (@{$langs{$lang}})
	{
		my @extsp = split(/\./, $ext);			# not reused :(
		push(@mosscmd, "$repoDir*/$lang/*." . $extsp[-1]);
	}
	print join(' ', @mosscmd) if $debug;
	my $res = `@mosscmd`;
	my @ressp = split(/\n/, $res);
	print "\nmoss response for $lang: $ressp[-1]\n";
#	open(MOSS, @mosscmd) or die "Couldn't execute moss command: @mosscmd\n";		# why this command does not work?
	@mosscmd = ();
}
