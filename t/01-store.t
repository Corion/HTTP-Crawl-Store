#!perl
use strict;
use Test::More tests => 5;

use HTTP::Crawl::Store;
use URI;

my $s = HTTP::Crawl::Store->new(
    dsn => 'dbi:SQLite:dbname=:memory:',
);

$s->create();
$s->connect();

my $u = URI->new('https://example.com');
use Scalar::Util 'reftype';

$s->store(
    {
        headers => ['X-Test'=>'special','Content-Type'=>'text/html'],
        url => "$u",
        method => 'GET',
        status => 200,
        message => 'OK',
        (map { $_ => $u->$_ } (qw(host port path query scheme))),
        content => '',
    },
);

$s->flush();

my $dbh = $s->dbh;

my $crawl = $dbh->selectall_arrayref(<<'SQL', {Slice => {}});
    select
    *
    from response  r
SQL

is 0+@$crawl, 1, "We can retrieve the crawl";
my $r_digest = $crawl->[0]->{response_digest};

$crawl = $dbh->selectall_arrayref(<<'SQL', {Slice => {}});
    select
    *
    from http_body
SQL

is 0+@$crawl, 1, "We can retrieve the body";
my $h_digest = $crawl->[0]->{digest};

$crawl = $dbh->selectall_arrayref(<<'SQL', {Slice => {}});
    select
    *
    from response r
    join http_body b on r.response_digest = b.digest
SQL

is 0+@$crawl, 1, "We can retrieve the request with the body";

is $r_digest, $h_digest, "The digests match";
is $crawl->[0]->{header_content_type}, 'text/html', "We store/retrieve the content type";

done_testing();