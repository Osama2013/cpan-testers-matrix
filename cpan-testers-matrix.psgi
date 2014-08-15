#!perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::RealBin/lib";

use Plack::Builder;
use Plack::App::Directory;
use Plack::App::File;
use Plack::App::WrapCGI;

use File::Basename 'basename';
use File::Spec::Functions 'catfile', 'splitpath';
use File::Glob 'bsd_glob';

use CPAN::Testers::Matrix::Suggest ();
use CPAN::Testers::Matrix::Opensearch ();

my $root = $FindBin::RealBin;

my $favicon = Plack::App::File->new(
    file => catfile($root, 'images', 'cpantesters_favicon.ico'),
)->to_app;

my @mounts;
for my $htdoc (bsd_glob(catfile($root, 'htdocs', '*'))) {
    my $location = '/' . basename($htdoc);
    next if $location eq '/opensearch.xml'; # dynamically handled, see below
    if (-d $htdoc) {
	push @mounts,  [ $location => Plack::App::Directory->new({root => $htdoc})->to_app ];
    } elsif (-f $htdoc) {
	push @mounts, [ $location => Plack::App::File->new(file => $htdoc)->to_app ];
    } else {
	warn "Ignoring $htdoc...\n";
    }
}

builder {
    enable "Plack::Middleware::AccessLog::Timed",
	format => "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\" %D \"%{Host}i\"";

    mount '/favicon.ico' => $favicon;
    mount '/cpantesters_favicon.ico' => $favicon;

    mount '/images' => Plack::App::File->new(file => catfile($root, 'images'))->to_app;

    for my $mount (@mounts) {
	mount $mount->[0] => $mount->[1];
    }

    mount '/cpantestersmatrix_suggest.pl' => CPAN::Testers::Matrix::Suggest::psgi();
    mount '/opensearch.xml' => CPAN::Testers::Matrix::Opensearch::psgi();

    mount '/' => Plack::App::WrapCGI->new(
        script  => catfile($root, 'cgi-bin', $ENV{TRAVIS} ? 'cpantestersmatrix-travis.pl' : 'cpantestersmatrix.pl'),
        execute => 1,
    )->to_app;
};
