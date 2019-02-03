#!perl -w
use HTTP::Crawl::Store;
use Minion;
use Minion::Backend::SQLite;

# Connect to backend
my $minion = Minion->new(SQLite => 'sqlite:test.db');
my $store = HTTP::Crawl::Store->new();

# Add tasks
my @responses;
$minion->add_task(fetch_url => sub {
    my ($job, $method, $url, %options) = @_;
    my $ua_method = lc $method;
    $ua_method .= '_p';

    my $headers = $options{headers} || {};

    my $ua = Mojo::UserAgent->new();
    my $response_p = $ua->$method($url, $headers )->then(sub {
        my ($mojo) = @_;
        my $uri = URI->new($url);
        my $res = $mojo->res;
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
    });
    push @responses, $response_p;
});

for my $url (@ARGV) {
    $minion->enqueue(fetch_url => [GET => $url]);
};

my $worker = $minion->worker;
$worker->status->{jobs} = 1;
$worker->run;