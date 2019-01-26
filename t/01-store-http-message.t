#!perl
use strict;
use Test::More tests => 6;

use HTTP::Crawl::Store;
use URI;
use HTTP::Request;
use HTTP::Response;

my $s = HTTP::Crawl::Store->new(
    dsn => 'dbi:SQLite:dbname=:memory:',
);

$s->create();
$s->connect();

my $u = URI->new('https://example.com/example-http-request');
use Scalar::Util 'reftype';

my $req = HTTP::Request->new(GET => "$u", ['User-Agent' => 'mockagent/1.0']);
my $res = HTTP::Response->new(
    200, 'OK',
    ['X-Test' => 'special', 'Content-Type' => 'text/html'],
    'Hello World',
);
$res->request($req);
$s->store($res);

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
is $crawl->[0]->{path}, '/example-http-request', "We store/retrieve the path";

done_testing();