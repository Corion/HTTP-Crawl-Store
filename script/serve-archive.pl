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

    if( $res->{header_content_type} =~ m!^text/html\b! ) {
        my $d = $p->parse( $res->{content});

        # Rewrite URLs to be local, especially image URLs
        for my $l ($d->resources) {
            my $absolute = Mojo::URL->new( $l->attr('src'))->to_abs(Mojo::URL->new($url));
            my $localized = app->url_for('archive')->query( url => $absolute );

            #warn "Resource: $absolute -> $localized";
            $l->attr('src', $localized);
        };

        #$c->stash( content => $res->{content} );
        $c->stash( content => $d->document->to_string );
        # We have our data in UTF-8
        $c->res->headers->content_type('text/html; charset=utf-8');
        $c->render(template => 'archived')
    } else {
        if( $res->{content} ) {
            #warn "Rendering $res->{header_content_type}";
            $c->res->headers->content_type($res->{header_content_type});
            $c->render(data => $res->{content});
        } else {
            $c->render(text => 'not found', status => 404);
        };
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
