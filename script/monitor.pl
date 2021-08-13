#!perl -w
use HTTP::Crawl::Store;
use HTTP::Crawl::LinkExtractor;
use Minion;
use Minion::Backend::SQLite;
use Mojo::UserAgent;

use Mojolicious::Lite;
use feature 'signatures';
no warnings 'experimental::signatures';

plugin 'Minion' => { SQLite => 'sqlite:db/crawler.sqlite' };
plugin 'Minion::Admin';

# Add another namespace to load commands from
push @{app->commands->namespaces}, 'HTTP::Crawl::Command';

# Connect to backend
#my $minion = Minion->new(SQLite => 'sqlite:db/crawler.sqlite');

# has 'store', in some "app" class...

my $store = HTTP::Crawl::Store->new(
    dsn => 'dbi:SQLite:dbname=db/crawler.sqlite',
);
sub Mojolicious::Lite::store {
    return $store
}

$store->connect();

my $filter = HTTP::Crawl::URLFilter->new(
    blacklist => [
        qr/\.svg$/,
        qr/\.googleanalytics\.$/,
        qr/\bgzhls\.at\b.*(?!\.jpg)....$/,
        qr!\bgeizhals.de/analytics/!,

        # Amazon
        qr!\bwww.amazon.de/gp/sponsored-products/logging/log-action\.html\b!,
    ],
);

# Add tasks
my @responses;

sub url_wanted( $url ) {
    my $action = $filter->get_action( { url => $url });
    if( $action ne 'continue' ) {
        warn "$$ Skipping '$url': $action";
    };
    return $action
}

sub fetch_resource($job, $method, $url, %options) {
    my $ua_method = lc $method;
    $ua_method .= '_p';

    my %seen = (
        $url => 1,
    );

    my $action = url_wanted( $url );
    if( $action ne 'continue' ) {
        return;
    };
    my $u = Mojo::URL->new( $url );

    my $headers = $options{headers} || {};

    my $ua = Mojo::UserAgent->new();
    my $response_p = $ua->$ua_method($url, $headers );
    $response_p->then(sub {
        my ($tx) = @_;
        my $uri = URI->new($url);
        my $res = $tx->result;
        # This should be HTTP::Crawl::Store->store_mojo_response() ...
        my $ct = $res->headers->to_hash->{'Content-Type'};
        my $decoded_content = $res->body;
        if( $ct =~ m!^text/html;\s*charset=(\S+)$! ) {
            my $charset = $1 || 'ISO-8859-1';
            $decoded_content = decode( $charset, $decoded_content );
        };

        my $data = {
            status  => $res->code,
            method  => $method,
            host    => $uri->host,
            port    => $uri->port,
            scheme  => $uri->scheme,
            url     => $uri->as_string,
            path    => $uri->path,
            url     => $url,
            message => $res->message,
            headers => [%{ $res->headers->to_hash }],
            content => $decoded_content,
        };
        if( $res->headers->to_hash->{"Content-Type"} =~ m!^text/html!) {
            # We should also store the title as metadata(?)
            (my $title) = ($data->{content} =~ m!<title>(.*?)</title>!i);
            say "Storing '$title', $data->{status}";
        } else {
            say "Storing '$url', $data->{status}";
        };
        $store->store(
            $data,
        );

        # And now, also fetch the resources?!
        if( $options{ fetch_resources }) {
            my $p = HTTP::Crawl::LinkExtractor->new();
            my $d = $p->parse( $res->body );
            for my $r ($d->resources) {
                my $linked = Mojo::URL->new( $r->attr('src'))->to_abs(Mojo::URL->new($uri));
                my $action = url_wanted( $linked );
                next if $seen{ $linked }++;
                if( $action ne 'continue' ) {
                    warn "Skipping resource '$linked' ($action)";
                } else {
                    warn "Enqueuing resource '$linked'";
                    # Later, also add appropriate headers, like cookies, referer etc.
                    app->minion->enqueue(fetch_url => [ GET => $linked, fetch_resources => 0 ] => { lock => $linked });
                };
            };
        };

        $store->flush();
    })->catch(sub {
        warn "[[$@]]";
        warn shift;
    })->wait;
    push @responses, $response_p;
};

app->minion->add_task(fetch_url => \&fetch_resource);

get '/url' => sub {
    my( $c ) = @_;
    $c->render( template => 'url');
};
post '/url' => sub {
    my($c) = @_;
    my $url = $c->param('url');
    if( $url ) {
        app->minion->enqueue(fetch_url => [ GET => $url ]);
    };
    $c->redirect_to('/url');
};

# Start the Mojolicious command system
app->start;

__DATA__
@@ url.html.ep
<html>
<body>
<form action="/url" method="POST" enctype="application/x-www-form-urlencoded">
<input name="url" type="text/url" value="" />
<button name="Submit">Submit</button>
</form>

</body>
</html>
