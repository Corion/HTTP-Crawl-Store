#!perl -w
use strict;
use warnings;
use HTTP::Crawl::Store;
use HTTP::Crawl::LinkExtractor;
use Minion;
use Minion::Backend::SQLite;

use Mojolicious::Lite '-signatures';
use Mojo::Util 'url_escape';
use Encode 'decode';

# has 'store', in some "app" class...
my $store = HTTP::Crawl::Store->new(
    dsn => 'dbi:SQLite:dbname=db/crawler.sqlite',
);

plugin 'Minion' => { SQLite => 'sqlite:db/crawler.sqlite' };
plugin 'Minion::Admin';

$store->connect();

# List all URLs
get '/' => sub ($c) {

    my $urls = $store->available_urls(
        where => "header_content_type like 'text/html%'",
    );
    $c->stash( urls => $urls );
    $c->render(template => 'index')
};

my $p = HTTP::Crawl::LinkExtractor->new();
get '/archive' => sub ($c) {
    my $url = $c->req->param('url');

    my $res = $store->retrieve_url( GET => $url );
    $c->res->headers->content_type($res->{header_content_type});

    # Rewrite URLs to be local, especially image URLs

    if( $res->{header_content_type} =~ m!^text/html\b! ) {
        my $d = $p->parse( $res->{content});
        for my $l ($d->resources) {
            warn "Resource: " . Mojo::URL->new( $l->attr('src'))->to_abs(Mojo::URL->new($url));
        };

        $c->stash( content => $res->{content} );
        $c->render(template => 'archived')
    } else {
        $c->render(data => $res->{content});
    }


    #$c->content_encoding( $res->{header_content_encoding} );
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
<li><a href="<%= $link %>"><%=$url->{url} %></a> - <%= $url->{retrieved} %></li>
% }
</ul>
</body>
</html>

@@ archived.html.ep
<!-- Some navigation here ?!-->
<%== $content %>
