package HTTP::Crawl::Command::create;
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
