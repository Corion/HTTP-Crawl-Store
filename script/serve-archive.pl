#!perl -w
use HTTP::Crawl::Store;
use Minion;
use Minion::Backend::SQLite;

use Mojolicious::Lite '-signatures';
use Mojo::Util 'url_escape';
use Encode 'decode';

# has 'store', in some "app" class...
my $store = HTTP::Crawl::Store->new(
    dsn => 'dbi:SQLite:dbname=db/crawler.sqlite',
);

$store->connect();

# List all URLs
get '/' => sub ($c) {

    my $urls = $store->available_urls();
    $c->stash( urls => $urls );
    $c->render(template => 'index')
};

get '/archive' => sub ($c) {
    my $url = $c->req->param('url');

    my $res = $store->retrieve_url( GET => $url );

    # Rewrite URLs to be local, especially image URLs

    $c->stash( content => $res->{content} );

    $c->res->headers->content_type($res->{header_content_type});

    #$c->content_encoding( $res->{header_content_encoding} );
    $c->render(template => 'archived')
};


# Start the Mojolicious command system
app->start;

__DATA__
@@ index.html.ep
<html>
<body>
<ul>
% for my $url (@$urls) {
% my $link = url_for('archive')->query( url => $url->{url} )->to_string;
%= dumper($link);
<li><a href="<%= $link %>"><%=$url->{url} %></a> - <%= $url->{retrieved} %></li>
% }
</ul>
</body>
</html>

@@ archived.html.ep
<!-- Some navigation here ?!-->
<%== $content %>
