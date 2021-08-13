#!perl -w
use 5.012; # //=
use strict;
use warnings;
use HTTP::Crawl::Store;
use Minion;
use Minion::Backend::SQLite;
use Mojo::UserAgent;
use YAML::Tiny 'LoadFile';
use Getopt::Long;
use Pod::Usage;
use POSIX 'strftime';
use Time::Local 'timegm';

# (Re)submits all URLs from a watchlist
# The watchlist should move into SQLite instead of being YAML
# but while I work on the schema, it being YAML is good enough

GetOptions(
    'config|c=s' =>  \my $config_file,
    'force|f' =>  \my $force_update,
) or pod2usage(2);

$config_file //= 'urllist.yml';

my $urls = LoadFile($config_file);

my $minion = Minion->new( SQLite => 'sqlite:db/crawler.sqlite' );
my $store = HTTP::Crawl::Store->new(
    dsn => 'dbi:SQLite:dbname=db/crawler.sqlite',
);
$store->connect();

my $ts = time();
for my $task (@$urls) {
    my $t = $task;
    my $last_fetched = $store->retrieve_url( GET => $t->{url} );

    my $fetch = 1;
    if( $last_fetched ) {

        my $next_fetch = $ts - $t->{update};
        my $next_fetch_ts = strftime '%Y-%m-%d %H:%M:%SZ', gmtime( $next_fetch );

        $fetch = $force_update || $last_fetched->{retrieved} lt $next_fetch_ts;

        if( $fetch ) {
            say "Updating $t->{url} ( $next_fetch_ts )";
        } else {
            say "$t->{url} is new enough";
        }

    } else {
        say "New URL $t->{url}";
    }

    if( $fetch ) {
        $minion->enqueue(fetch_url => [ GET => $t->{url}, fetch_resources => 1 ] => { lock => $t->{url} });
    };
};
