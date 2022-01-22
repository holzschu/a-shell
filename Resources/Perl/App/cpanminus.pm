package App::cpanminus;
our $VERSION = "1.7044";

=encoding utf8

=head1 NAME

App::cpanminus - get, unpack, build and install modules from CPAN

=head1 SYNOPSIS

    cpanm Module

Run C<cpanm -h> or C<perldoc cpanm> for more options.

=head1 DESCRIPTION

cpanminus is a script to get, unpack, build and install modules from
CPAN and does nothing else.

It's dependency free (can bootstrap itself), requires zero
configuration, and stands alone. When running, it requires only 10MB
of RAM.

=head1 INSTALLATION

There are several ways to install cpanminus to your system.

=head2 Package management system

There are Debian packages, RPMs, FreeBSD ports, and packages for other
operation systems available. If you want to use the package management system,
search for cpanminus and use the appropriate command to install. This makes it
easy to install C<cpanm> to your system without thinking about where to
install, and later upgrade.

=head2 Installing to system perl

You can also use the latest cpanminus to install cpanminus itself:

    curl -L https://cpanmin.us | perl - --sudo App::cpanminus

This will install C<cpanm> to your bin directory like
C</usr/local/bin> and you'll need the C<--sudo> option to write to
the directory, unless you configured C<INSTALL_BASE> with L<local::lib>.

=head2 Installing to local perl (perlbrew, plenv etc.)

If you have perl in your home directory, which is the case if you use
tools like L<perlbrew> or plenv, you don't need the C<--sudo> option, since
you're most likely to have a write permission to the perl's library
path. You can just do:

    curl -L https://cpanmin.us | perl - App::cpanminus

to install the C<cpanm> executable to the perl's bin path, like
C<~/perl5/perlbrew/bin/cpanm>.

=head2 Downloading the standalone executable

You can also copy the standalone executable to whatever location you'd like.

    cd ~/bin
    curl -L https://cpanmin.us/ -o cpanm
    chmod +x cpanm

This just works, but be sure to grab the new version manually when you
upgrade because C<--self-upgrade> might not work with this installation setup.

=head2 Troubleshoot: HTTPS warnings

When you run C<curl> commands above, you may encounter SSL handshake
errors or certification warnings. This is due to your HTTP client
(curl) being old, or SSL certificates installed on your system needs
to be updated.

You're recommended to update the software or system if you can. If
that is impossible or difficult, use the C<-k> option with curl or an
alternative URL, C<https://git.io/cpanm>

=head1 DEPENDENCIES

perl 5.8.1 or later.

=over 4

=item *

'tar' executable (bsdtar or GNU tar version 1.22 are recommended) or Archive::Tar to unpack files.

=item *

C compiler, if you want to build XS modules.

=item *

make

=item *

Module::Build (core in 5.10)

=back

=head1 QUESTIONS

=head2 How does cpanm get/parse/update the CPAN index?

It queries the CPAN Meta DB site at L<http://cpanmetadb.plackperl.org/>.
The site is updated at least every hour to reflect the latest changes
from fast syncing mirrors. The script then also falls back to query the
module at L<http://metacpan.org/> using its search API.

Upon calling these API hosts, cpanm (1.6004 or later) will send the
local perl versions to the server in User-Agent string by default. You
can turn it off with C<--no-report-perl-version> option. Read more
about the option with L<cpanm>, and read more about the privacy policy
about this data collection at L<http://cpanmetadb.plackperl.org/#privacy>

Fetched files are unpacked in C<~/.cpanm> and automatically cleaned up
periodically.  You can configure the location of this with the
C<PERL_CPANM_HOME> environment variable.

=head2 Where does this install modules to? Do I need root access?

It installs to wherever ExtUtils::MakeMaker and Module::Build are
configured to (via C<PERL_MM_OPT> and C<PERL_MB_OPT>).

By default, it installs to the site_perl directory that belongs to
your perl. You can see the locations for that by running C<perl -V>
and it will be likely something under C</opt/local/perl/...> if you're
using system perl, or under your home directory if you have built perl
yourself using perlbrew or plenv.

If you've already configured local::lib on your shell, cpanm respects
that settings and modules will be installed to your local perl5
directory.

At a boot time, cpanminus checks whether you have already configured
local::lib, or have a permission to install modules to the site_perl
directory.  If neither, i.e. you're using system perl and do not run
cpanm as a root, it automatically sets up local::lib compatible
installation path in a C<perl5> directory under your home
directory.

To avoid this, run C<cpanm> either as a root user, with C<--sudo>
option, or with C<--local-lib> option.

=head2 cpanminus can't install the module XYZ. Is it a bug?

It is more likely a problem with the distribution itself. cpanminus
doesn't support or may have issues with distributions such as follows:

=over 4

=item *

Tests that require input from STDIN.

=item *

Build.PL or Makefile.PL that prompts for input even when
C<PERL_MM_USE_DEFAULT> is enabled.

=item *

Modules that have invalid numeric values as VERSION (such as C<1.1a>)

=back

These failures can be reported back to the author of the module so
that they can fix it accordingly, rather than to cpanminus.

=head2 Does cpanm support the feature XYZ of L<CPAN> and L<CPANPLUS>?

Most likely not. Here are the things that cpanm doesn't do by
itself.

If you need these features, use L<CPAN>, L<CPANPLUS> or the standalone
tools that are mentioned.

=over 4

=item *

CPAN testers reporting. See L<App::cpanminus::reporter>

=item *

Building RPM packages from CPAN modules

=item *

Listing the outdated modules that needs upgrading. See L<App::cpanoutdated>

=item *

Showing the changes of the modules you're about to upgrade. See L<cpan-listchanges>

=item *

Patching CPAN modules with distroprefs.

=back

See L<cpanm> or C<cpanm -h> to see what cpanminus I<can> do :)

=head1 COPYRIGHT

Copyright 2010- Tatsuhiko Miyagawa

The standalone executable contains the following modules embedded.

=over 4

=item L<CPAN::DistnameInfo> Copyright 2003 Graham Barr

=item L<local::lib> Copyright 2007-2009 Matt S Trout

=item L<HTTP::Tiny> Copyright 2011 Christian Hansen

=item L<Module::Metadata> Copyright 2001-2006 Ken Williams. 2010 Matt S Trout

=item L<version> Copyright 2004-2010 John Peacock

=item L<JSON::PP> Copyright 2007-2011 by Makamaka Hannyaharamitu

=item L<CPAN::Meta>, L<CPAN::Meta::Requirements> Copyright (c) 2010 by David Golden and Ricardo Signes

=item L<CPAN::Meta::YAML> Copyright 2010 Adam Kennedy

=item L<CPAN::Meta::Check> Copyright (c) 2012 by Leon Timmermans

=item L<File::pushd> Copyright 2012 David Golden

=item L<parent> Copyright (c) 2007-10 Max Maischein

=item L<Parse::PMFile> Copyright 1995 - 2013 by Andreas Koenig, Copyright 2013 by Kenichi Ishigaki

=item L<String::ShellQuote> by Roderick Schertler


=back

=head1 LICENSE

This software is licensed under the same terms as Perl.

=head1 CREDITS

=head2 CONTRIBUTORS

Patches and code improvements were contributed by:

Goro Fuji, Kazuhiro Osawa, Tokuhiro Matsuno, Kenichi Ishigaki, Ian
Wells, Pedro Melo, Masayoshi Sekimura, Matt S Trout (mst), squeeky,
horus and Ingy dot Net.

=head2 ACKNOWLEDGEMENTS

Bug reports, suggestions and feedbacks were sent by, or general
acknowledgement goes to:

Jesse Vincent, David Golden, Andreas Koenig, Jos Boumans, Chris
Williams, Adam Kennedy, Audrey Tang, J. Shirley, Chris Prather, Jesse
Luehrs, Marcus Ramberg, Shawn M Moore, chocolateboy, Chirs Nehren,
Jonathan Rockway, Leon Brocard, Simon Elliott, Ricardo Signes, AEvar
Arnfjord Bjarmason, Eric Wilhelm, Florian Ragwitz and xaicron.

=head1 COMMUNITY

=over 4

=item L<http://github.com/miyagawa/cpanminus> - source code repository, issue tracker

=item L<irc://irc.perl.org/#cpanm> - discussions about cpanm and its related tools

=back

=head1 NO WARRANTY

This software is provided "as-is," without any express or implied
warranty. In no event shall the author be held liable for any damages
arising from the use of the software.

=head1 SEE ALSO

L<CPAN> L<CPANPLUS> L<pip>

=cut

1;
