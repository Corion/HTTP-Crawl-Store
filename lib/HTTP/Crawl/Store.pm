package HTTP::Crawl::Store;
use strict;
use warnings;

use Moo 2;
use JSON::XS 'encode_json';

use Filter::signatures;
use feature 'signatures';
no warnings 'experimental::signatures';

use DBIx::RunSQL;
use File::ShareDir 'dist_dir';
use Path::Class;
use Digest;
use Digest::SHA;
use POSIX 'strftime';

our $VERSION = '0.01';

=head1 NAME

HTTP::Crawl::Store - store HTTP crawl results for later consumption

=head1 SYNOPSIS

    my $s = HTTP::Crawl::Store->new(
        dsn => 'dbi:SQLite:dbname=:memory:',
    );

    $s->create();
    $s->connect();

    my $response = $mech->get('https://example.com/');

    # We dispatch on ref($response)
    $s->store($response);

    $s->flush();

    my $response = $s->retrieve_url(GET => 'https://example.com/');

=cut

# Global variables are used to communicate with SQLite
our $responses;
our $bodies;

has 'dsn' => (
    is => 'ro',
);

has 'user' => (
    is => 'ro',
);

has 'password' => (
    is => 'ro',
);

has 'options' => (
    is => 'ro',
    default => sub { { RaiseError => 1, PrintError => 0 } },
);

has 'dbh' => (
    is => 'lazy',
    default => sub { DBI->connect( $_[0]->dsn, $_[0]->user, $_[0]->password, $_[0]->options )},
);

has 'sql_dir' => (
    is => 'ro',
    default => sub { (my $dist = __PACKAGE__) =~ s!::!-!g; dist_dir($dist) }
);

has bodies => (
    is => 'ro',
    default => sub { [] }
);

has responses => (
    is => 'ro',
    default => sub { [] }
);

has digest => (
    is => 'ro',
    default => sub {
        Digest->new("SHA-256"),
    },
);

sub sql_file( $self, $fn ) {
    file( $self->sql_dir, $fn )
}

sub create($self, %options) {
    my $dbh = $self->dbh;
    DBIx::RunSQL->run(
        dbh => $dbh,
        sql => $self->sql_file( 'create.sql' ),
        %options,
    );
}

sub connect( $self, $dbh = $self->dbh ) {
    local $responses = $self->responses;
    local $bodies = $self->bodies;
}

sub _store($self, $res) {
    my $responses = $self->responses;
    my $bodies = $self->bodies;
    for my $response (@$res) {
        my $digest = $self->digest->clone;
        $digest->add($response->{body})
            if exists $response->{body};
        $digest = $digest->digest;
        $response->{response_digest} = $digest;

        $response->{retrieved} ||= strftime '%Y-%m-%d %H:%M:%S', localtime;

        # Upmunge some of the headers
        for my $h (qw(content_type
                      etag date server content_disposition content_length
                      cache_control content_encoding content_language
                      content_location expires set_cookie transfer_encoding
                      x_powered_by
                   )) {
            (my $hname = $h) =~ s/_/-/g;
            ($response->{"header_$h"}) = map { my $hn = $response->{headers}->[$_*2]; (defined $hn and $hn =~ /^$hname$/i) ? $response->{headers}->[$_*2+1] : () } 0..(@{ $response->{headers} }/2);
        };
        $response->{headers_all} = encode_json($response->{headers});

        push @$responses, $response;
        # gunzip stuff/remote TE
        push @$bodies, { digest => $digest, content => $response->{content} };
    };
}

sub http_response_to_response( $self, $response ) {
    my $req = $response->request;
    if( !$response->decode ) {
        warn "Couldn't decode content";
    };
    my $uri = $req->uri;
    return {
        method  => $req->method,
        host    => $uri->host,
        port    => $uri->port,
        scheme  => $uri->scheme,
        url     => $uri->as_string,
        path    => $uri->path,
        status  => $response->code,
        message => $response->message,
        headers => [$response->headers->flatten],
        content => $response->content, # charset-encoded, utf-8 and mojibake get stored as blob
    }
}

sub store( $self, @responses ) {
    @responses = map {
        my $ref = ref $_;
        if ( $ref eq 'HTTP::Response' ) {
            $_ = $self->http_response_to_response( $_ );
        } else {
            # Hope that it behaves like a dumb hash
            $_
        }
    } @responses;
    $self->_store( \@responses );
}

sub store_mojo_tx( $self, @responses ) {
}

sub store_http_response( $self, @responses ) {
}

sub flush( $self ) {
    local $responses = $self->responses;
    local $bodies = $self->bodies;
    my $dbh = $self->dbh;

    $dbh->sqlite_create_module(perl => "DBD::SQLite::VirtualTable::PerlData");
    $dbh->do(<<'SQL');
    create virtual table temp.perl_response USING perl (
        retrieved                     timestamp not null
      , method                        varchar(6) not null
      , scheme                        varchar(6) not null
      , host                          varchar(128) not null
      , port                          decimal(5,0)
      , path                          varchar(1024) not null
      , url                           varchar(2048) not null
      , status                        decimal(3,0)
      , message                       varchar(80)
      , header_content_type           varchar(80)
      , header_etag                   varchar(80)
      , header_date                   varchar(80)
      , header_server                 varchar(80)
      , header_content_disposition    varchar(80)
      , header_content_length         varchar(80)
      , header_cache_control          varchar(80)
      , header_content_encoding       varchar(80)
      , header_content_language       varchar(80)
      , header_content_location       varchar(80)
      , header_expires                varchar(80)
      , header_set_cookie             varchar(80)
      , header_transfer_encoding      varchar(80)
      , header_x_powered_by           varchar(80)
      , header_all                    varchar(8192) -- json array of headers
      , response_digest               varchar(32)
      , hashrefs="HTTP::Crawl::Store::responses"
    )
SQL

    $dbh->do(<<'SQL');
    create virtual table temp.perl_http_body USING perl (
        digest varchar(32) not null unique
      , content blob
      , hashrefs="HTTP::Crawl::Store::bodies"
    );
SQL
    $self->dbh->do(<<'SQL');
        insert into response
        (retrieved
        ,method
        ,scheme
        ,host
        ,port
        ,path
        ,url
        ,status
        ,message
        ,header_content_type
        ,header_etag
        ,header_date
        ,header_server
        ,header_content_disposition
        ,header_content_length
        ,header_cache_control
        ,header_content_encoding
        ,header_content_language
        ,header_content_location
        ,header_expires
        ,header_set_cookie
        ,header_transfer_encoding
        ,header_x_powered_by
        ,header_all
        ,response_digest)
        select
         retrieved
        ,method
        ,scheme
        ,host
        ,port
        ,path
        ,url
        ,status
        ,message
        ,header_content_type
        ,header_etag
        ,header_date
        ,header_server
        ,header_content_disposition
        ,header_content_length
        ,header_cache_control
        ,header_content_encoding
        ,header_content_language
        ,header_content_location
        ,header_expires
        ,header_set_cookie
        ,header_transfer_encoding
        ,header_x_powered_by
        ,header_all
        ,response_digest
          from temp.perl_response
SQL
    $self->dbh->do(<<'SQL');
        insert into http_body
            (digest, content)
        select
            digest
          , content
        from temp.perl_http_body
SQL

}

sub retrieve_http_request($self,$request) {
    $self->retrieve_url( $request->method, $request->url );
}

sub retrieve_url($self,$method, $url, %options) {
    # Later, add options to retrieve other versions of the page
    $self->dbh->selectall_arrayref(<<'SQL', {Slice => {}}, $method, $url)->[0];
        select
        *
        from response r
        join http_body b on r.response_digest = b.digest
        where method = ?
          and url    = ?
        order by retrieved desc limit 1
SQL
}

=head2 C<< $store->purge_bodies >>

    $store->purge_bodies();

Removes all message bodies that are not referenced anymore.

If you periodically prune old responses, you can't immediately prune the
bodies too, as these might be referenced by other responses. This method
purges all bodies that are not referenced anymore.

=cut

sub purge_bodies($self) {
    $self->dbh->do(<<'SQL');
        delete from http_body b
                    left join response r
        where r.method is null
SQL
}

1;