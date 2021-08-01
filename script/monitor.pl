#!perl -w
use HTTP::Crawl::Store;
use Minion;
use Minion::Backend::SQLite;
use Mojo::UserAgent;

use Mojolicious::Lite;
plugin 'Minion' => { SQLite => 'sqlite:db/crawler.sqlite' };
plugin 'Minion::Admin';

# Connect to backend
#my $minion = Minion->new(SQLite => 'sqlite:db/crawler.sqlite');

# has 'store', in some "app" class...
my $store = HTTP::Crawl::Store->new(
    dsn => 'dbi:SQLite:dbname=db/crawler.sqlite',
);

{
    package MyApp::Command::create;
    use Mojo::Base 'Mojolicious::Command';

    use Mojo::Util 'getopt';

    has 'description' => 'Create the HTTP crawl schema';
    has 'usage' => <<"USAGE";
    $0 create
USAGE

    sub run {
        my ($self, @args) = @_;

        my $app = $self->app;
        my $store = $app->store;
        $store->create();
        exit
    }

    1;
}

$store->connect();

# Add tasks
my @responses;
app->minion->add_task(fetch_url => sub {
    my ($job, $method, $url, %options) = @_;
    my $ua_method = lc $method;
    $ua_method .= '_p';

    my $headers = $options{headers} || {};

    my $ua = Mojo::UserAgent->new();
    my $response_p = $ua->$ua_method($url, $headers );
    $response_p->then(sub {
        my ($tx) = @_;
        my $uri = URI->new($url);
        my $res = $tx->result;
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
            content => $res->body,
        };
        $store->store(
            $data,
        );
        $store->flush();
    })->catch(sub {
        warn "[[$@]]";
        warn shift;
    })->wait;
    push @responses, $response_p;
});

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
