#!/usr/bin/perl

use strict;
$|++;
# in plugins/EntryImExporter/tools
use lib '../../../extlib';
use lib '../../../lib';
use lib '../../../addons/Commercial.pack/lib';
use lib '../lib';
# in plugins/EntryImExporter
use lib '../../extlib';
use lib '../../lib';
use lib '../../addons/Commercial.pack/lib';
use lib 'lib';

our $VERSION = '1.00_02';

use MT;
use EntryImExporter::CMS;
use Getopt::Long;

my $CSV_FILENAME = '/tmp/entry_data.csv';

### Get options
my $OBJECT_CLASS = 'entry';
my $HELP = 0;
my $ENCODING = 'sjis';
my $optcount = GetOptions(
    'class=s' => \$OBJECT_CLASS,
    'help' => \$HELP,
    'encoding=s' => \$ENCODING,
);

### Usage
if( $HELP || $OBJECT_CLASS !~ /entry|page/ ||  @ARGV < 3 ){
    print STDERR <<__HELP__;
EntryImExpoter plugin tools. entry_import.pl

Usage: perl entry_import.pl [--help] [[--class] class] [[--encoding] sjis|utf8] path username password

--help      This page.
--class     entry or page ( set object class ) default class: entry
--encoding  encoding of CSV file. must be 'sjis' or 'utf8'. ( default: sjis ) 
path        import file path.( default: /tmp/entry_data.csv )
__HELP__
    exit;
}

if( $ENCODING ne 'sjis' and $ENCODING ne 'utf8' ) {
  die 'Encoding must be sjis or utf8.';
}

if( $ARGV[0] =~ m!([a-zA-Z0-9\_\-\@\.\/\\\(\)]+)! ){
   $CSV_FILENAME = $1;
}

my ($user, $passwd) = ($ARGV[1], $ARGV[2]);
my $author = MT::Author->load({
    name => $user,
});

unless ( $author ) {
    print STDERR MT->translate("Invalid login attempt from user '[_1]'", $user) . "\n";
    exit;
}

unless ( $author->is_valid_password($passwd, 0) ) {
    print STDERR MT->translate("Both passwords must match.") . "\n";
    exit;
}

my $perm = $author->permissions(0);
unless ( $author->is_superuser || ($perm && $perm->can_do('administer')) ) {
    print STDERR MT->translate("User must be a superuser.") . "\n";
    exit;
}

### Open CSV Filename
open my $fh, "<$CSV_FILENAME"
    or die 'Could not open the file - '. $CSV_FILENAME;

### New MT instance
my $mt = MT->instance
    or die 'Could not initialize MT instance';

### Invoke !!
my %param;
my $update_flg = 1;
EntryImExporter::CMS::_import_csv_file (
        $mt,
        $fh,
        \%param,
        $update_flg,
        $OBJECT_CLASS,
        $CSV_FILENAME,
	$ENCODING);

1;
