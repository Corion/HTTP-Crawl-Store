package HTTP::Crawl::LinkExtractor;
use Moo 2;
use feature 'signatures';
no warnings 'experimental::signatures';
use HTTP::Crawl::URLFilter;

has 'parser_class' => (
    is => 'ro',
    default => sub {
        # Later, maybe one of the HTML5 modules
        # or even HTML::HTML5::DOM
        return Mojo::DOM->new();
    },
);

sub parse( $self, $html ) {
    my $p = $self->parser_class->new( $html );
    return HTTP::Crawl::LinkExtractor::Document->new(
        #url      => $url,
        document => $p,
    );
}

1;

package HTTP::Crawl::LinkExtractor::Document;
use Moo 2;
use feature 'signatures';
no warnings 'experimental::signatures';

#has 'url' => (
#    is => 'ro',
#);

has 'document' => (
    is => 'ro',
);

sub links($self) {
    # Maybe make things unique? But certainly absolute?!
    @{ $self->document->find('a')->to_array }
}

sub resources($self) {
    # Maybe make things unique? But certainly absolute?!
    @{ $self->document->find('link[rel="stylesheet"], img[src]')->to_array }
}

1;
