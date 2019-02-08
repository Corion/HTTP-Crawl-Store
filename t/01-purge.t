#!perl
use strict;
use Test::More tests => 4;
use Data::Dumper;

use HTTP::Crawl::Store;
use URI;
use POSIX 'strftime';

my $s = HTTP::Crawl::Store->new(
    dsn => 'dbi:SQLite:dbname=:memory:',
);

$s->create();
$s->connect();

my $u = URI->new('https://example.com/example1');
use Scalar::Util 'reftype';

my $retrieved = time;
for my $content (qw(abc def def ghi def jkl)) {
    my $ts = strftime '%Y-%m-%d %H:%M:%S', localtime($retrieved++);
    
    $s->store(
        {
            headers => ['X-Test'=>'special','Content-Type'=>'text/html'],
            retrieved => $ts,
            url => "$u",
            method => 'GET',
            status => 200,
            message => 'OK',
            (map { $_ => $u->$_ } (qw(host port path query scheme))),
            body => $content,
        },
    );
};

$s->flush();

my $dbh = $s->dbh;
my $crawl = $dbh->selectall_arrayref(<<'SQL', {Slice => {}});
    select
        url
      , host
      , response_digest
    from response r
SQL
if(! is @$crawl, 6, "We stored six responses") {
    diag Dumper $crawl
};

$crawl = $dbh->selectall_arrayref(<<'SQL', {Slice => {}});
    select
           digest
      from http_body
SQL
if(! is @$crawl, 4, "We stored four different response bodies") {
    diag Dumper $crawl
};

my $d = $dbh->selectall_arrayref(<<'SQL',{});
        with freshest_content as (
          select
                 response_digest
               , max(retrieved) as last_retrieved
            from response
           group by response_digest
        )
        , old_responses as (
          select
                 f.response_digest
               , dense_rank() over (partition by url order by last_retrieved desc) as pos
               , last_retrieved
            from freshest_content f join response r on (f.response_digest=r.response_digest)
        )
        , response_rank as (
          select
                 response_digest
               , min(pos) as pos
               , last_retrieved
            from old_responses
        group by response_digest
        )
        select host,url, r.response_digest, last_retrieved, pos
        from response r join response_rank rr on (r.response_digest=rr.response_digest)
        where 
              host like '%'
          and r.response_digest in (select response_digest from response_rank where pos > 3)
SQL
#diag Dumper $d;

$s->purge_distinct_responses(
    keep_newest => 3,
);

$crawl = $dbh->selectall_arrayref(<<'SQL', {Slice => {}});
    select
           distinct response_digest
    from response
SQL
if(! is 0+@$crawl, 3, "We kept three different response bodies") {
    diag Dumper $crawl;
};

$s->purge_bodies();

$crawl = $dbh->selectall_arrayref(<<'SQL', {Slice => {}});
    select
    digest
    from http_body
SQL
is @$crawl, 3, "We have three bodies left after cleaning up the bodies";

done_testing();