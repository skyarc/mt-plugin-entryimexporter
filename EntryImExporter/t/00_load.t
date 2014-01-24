#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

use lib "../lib";
use lib "/var/www/html/mtcms/526/lib";
use lib "/var/www/html/mtcms/526/extlib";

require MT;
require MT::Bootstrap;
my $mt = MT->instance;

my @module_list = `find ../lib -type f -name "*.pm"`;

my @packages = 
     map { m{^\.\./lib/(.*)\.pm$}; $1 } 
     @module_list;

$_ =~ s{/}{::}g for @packages;
my $testcount = scalar @packages;

plan (tests => $testcount);
for my $p ( @packages ) {
   use_ok( $p );
}
