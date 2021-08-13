package HTTP::Crawl::URLFilter;
use Moo 2;
use Filter::signatures;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

=head1 NAME

HTTP::Crawl::URLFilter - filter/rewrite URLs

=head1 SYNOPSIS

    use HTTP::Crawl::URLFilter;

    my $mech = WWW::Mechanize::Chrome->new();
    my $f = HTTP::Crawl::URLFilter->new(
        blacklist => [
            qr!\bgoogleadservices\b!,
        ],
        whitelist => [
            qr!\bcorion\.net\b!,
        ],

        # fail all unknown URLs
        default => 'fail',
        # allow all unknown URLs
        # default => 'continue',

        on_default => sub {
            warn "Ignored URL $_[0] (action was '$_[1]')",
        },
    );

    for my $url (@urls) {
        my $action = $f->get_action( { url => $url });
        say "$url: $action";
    }

=head1 DESCRIPTION

This module allows an easy approach to whitelisting/blacklisting URLs
so that Chrome does not make requests to the blacklisted URLs.

=head1 ATTRIBUTES

=head2 C<< whitelist >>

Arrayref containing regular expressions of URLs to always allow fetching.

=cut

has 'whitelist' => (
    is => 'lazy',
    default => sub { [] },
);

=head2 C<< blacklist >>

Arrayref containing regular expressions of URLs to always deny fetching unless
they are matched by something in the C<whitelist>.

=cut

has 'blacklist' => (
    is => 'lazy',
    default => sub { [] },
);

=head2 C<< default >>

  default => 'continue'

The action to take if an URL appears neither in the C<whitelist> nor
in the C<blacklist>. The default is C<continueRequest>. If you want to block
all unknown URLs, use C<failRequest>

=cut

has 'default' => (
    is => 'rw',
    default => 'continue',
);

=head2 C<< on_default >>

  on_default => sub {
      my( $url, $action ) = @_;
      warn "Unknown URL <$url>";
  };

This callback is invoked for every URL that is neither in the whitelist nor
in the blacklist. This is useful to see what URLs are still missing a category.

=cut


has 'on_default' => (
    is => 'rw',
);

=head1 METHODS

=head2 C<< ->new >>

  my $bl = WWW::Mechanize::Chrome::URLBlacklist->new(
      blacklist => [
          qr!\bgoogleadservices\b!,
          qr!\ioam\.de\b!,
          qr!\burchin\.js$!,
          qr!.*\.(?:woff|ttf)$!,
          qr!.*\.css(\?\w+)?$!,
          qr!.*\.png$!,
          qr!.*\bfavicon.ico$!,
      ],
  );

Creates a new instance of a blacklist, but does B<not> activate it yet.
See C<< ->enable >> for that.

=cut

sub get_action( $self, $request ) {
    my $action;

    if( grep { $request->{url} =~ /$_/ } @{ $self->whitelist } ) {
        $action = 'continue';

    } elsif( grep { $request->{url} =~ /$_/ } @{ $self->blacklist }) {
        $action = 'fail';

    } else {

        if( $self->default eq 'continue' ) {
            $action = 'continue';
        } else {
            $action = 'fail';
        };
        if( my $cb = $self->on_default ) {
            local $@;
            my $ok = eval {
                $cb->($request->{url}, $action);
                1;
            };
            warn $@ if !$ok;
        };
    };
    return $action;
};

1;

__END__

=head1 REPOSITORY

The public repository of this module is
L<https://github.com/Corion/www-mechanize-chrome>.

=head1 SUPPORT

The public support forum of this module is L<https://perlmonks.org/>.

=head1 TALKS

I've given a German talk at GPW 2017, see L<http://act.yapc.eu/gpw2017/talk/7027>
and L<https://corion.net/talks> for the slides.

At The Perl Conference 2017 in Amsterdam, I also presented a talk, see
L<http://act.perlconference.org/tpc-2017-amsterdam/talk/7022>.
The slides for the English presentation at TPCiA 2017 are at
L<https://corion.net/talks/WWW-Mechanize-Chrome/www-mechanize-chrome.en.html>.

=head1 BUG TRACKER

Please report bugs in this module via the Github bug queue at
L<https://github.com/Corion/WWW-Mechanize-Chrome/issues>

=head1 AUTHOR

Max Maischein C<corion@cpan.org>

=head1 COPYRIGHT (c)

Copyright 2010-2021 by Max Maischein C<corion@cpan.org>.

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut
