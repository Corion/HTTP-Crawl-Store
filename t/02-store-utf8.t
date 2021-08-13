#!perl
use strict;
use warnings;
use Test::More;

use HTTP::Crawl::Store;
use HTTP::Request;
use HTTP::Headers;
use HTTP::Response;
use Encode 'encode';
use charnames ':full';

plan tests => 2;

my $content = "\N{EURO SIGN}";
my $url = 'https://example.com/test1';

my $s = HTTP::Crawl::Store->new(
        dsn => 'dbi:SQLite:dbname=:memory:',
);
$s->create();
$s->connect();

my $req = HTTP::Request->new(
    GET => $url,
    HTTP::Headers->new(),
);

my $res = HTTP::Response->new(
    200,
    'OK',
    HTTP::Headers->new('content-type' => 'text/plain; encoding=UTF-8'),
    encode('UTF-8',$content),
);
$res->request( $req );
$s->store_http_response( $res );
$s->flush;

my $r = $s->retrieve_url('GET', $url);

is $r->{content}, $content, 'We properly decode our stored content';

$url = 'https://example.com/test2';
$req = HTTP::Request->new(
    GET => $url,
    HTTP::Headers->new(),
);

$res = HTTP::Response->new(
    200,
    'OK',
    HTTP::Headers->new('content-type' => 'image/whatever'),
    encode('UTF-8',$content),
);
$res->request( $req );
$s->store_http_response( $res );
$s->flush;

$r = $s->retrieve_url('GET', $url);

is $r->{content}, encode('UTF-8', $content), 'Binary data stays binary data, even if it looks like UTF-8';
