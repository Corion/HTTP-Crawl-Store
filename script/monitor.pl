#!perl -w
use HTTP::Crawl::Store;
use Minion;
use Minion::Backend::SQLite;

use Mojolicious::Lite;
plugin 'Minion' => { SQLite => 'sqlite:test.db' };
plugin 'Minion::Admin';

# Start the Mojolicious command system
app->start;

