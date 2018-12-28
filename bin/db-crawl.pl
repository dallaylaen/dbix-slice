#!/usr/bin/env perl

use strict;
use warnings;
use DBI;
use Getopt::Long;
use File::Basename qw(dirname);

use lib dirname(__FILE__)."/../lib";
use DBIx::Crawl;

my %opt;
get_options_help (
    "$0 - dump partial database content based on links",
    "Usage: $0 [options] [table:field=value,...] ...",
    "Options may include",
    [ "config=s" => \$opt{config}, "(required) - list of known tables & links" ],
    [ "db=s"     => \$opt{db}, "- database to work on"],
    "        database is given as 'mysql:host=...;port=...'",
    "        if filename is given instead, assume SQLite",
    [ "user=s"   => \$opt{user}, "- database user" ],
    [ "pass=s"   => \$opt{pass}, "- database password" ], # TODO read online
);

die "--config is required"
    unless defined $opt{config};


# parse args
my @todo;
foreach (@ARGV) {
    push @todo, arg_to_table($_);
};

# read config
my $fd = openfile( $opt{config} );
my $slice = DBIx::Crawl->new( unsafe => 1 );
$slice->read_config($fd);

if (!@todo) {
    # Still SQL-compatible output
    print " -- nothing to be done\n";
    print " -- config file $opt{config} is OK\n";
    exit 0;
};

die "--db is required"
    if !defined $opt{db} and @ARGV;

# connect to DB
# SQLite simplifies testing
$opt{db} = "SQLite:dbname=$opt{db}"
    if $opt{db} !~ /:/;
my $dbh = DBI->connect( "dbi:$opt{db}", $opt{user}, $opt{pass}, { RaiseError => 1 } );

# fetch!
$slice->fetch( $dbh, @todo );
print $slice->get_insert_script;

sub arg_to_table {
    # table:field="value",...
    my ($arg) = @_;

    $arg =~ /^(\w+):((\w+=\w+)(,\w+=\w+)*|all)$/
        or die "Bad argument $arg, must be 'table:field=value,...'";

    my $table = $1;
    my $spec  = $2;
    # TODO detect duplicates & die
    my %hash;
    %hash = map { split /=/, $_, 2 } split /,/, $spec
        unless $spec eq 'all';

    return [ $table, \%hash ];
};

sub openfile {
    my ($name, $mode) = @_;

    $mode ||= '<';

    if ($name eq '-') {
        return $mode =~ />/ ? \*STDOUT : \*STDIN;
    };

    open my $fd, $mode, $name
        or die "Cannot open file($mode) '$name': $!";

    return $fd;
};

# TODO fix, replace, or finnd equivalent for Getopt::Helpful
# which does exactly the following but is unmaintained:

my @help;
sub get_options_help {
    my @list = @_;

    my @opt;

    foreach (@list) {
        $_ = [ $_ ] unless ref $_ eq 'ARRAY';
        push @help, $_;

        if (ref $_->[1]) {
            # found option
            push @opt, $_->[0], $_->[1];
        };
    };

    GetOptions( help => \&display_usage, @opt )
        or die "Bad options. See $0 --help";
};

sub display_usage {
    my $status = shift;
    $status = 0 if defined $status and $status !~ /^\d+/;

    my @help_clear;

    foreach (@help) {
        if (ref $_->[1]) {
            my ($opt, $skip, @rest) = @$_;
            push @help_clear, join " ", option_to_help($opt), @rest;
        } else {
            push @help_clear, join " ", @$_;
        };
    };

    print join "\n", @help_clear, "  --help - this message", "";
    exit $status if defined $status;
};

sub option_to_help {
    return "  --".shift; # TODO
};