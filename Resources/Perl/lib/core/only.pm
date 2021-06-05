package lib::core::only;

use strict;
use warnings FATAL => 'all';
use Config;

sub import {
  @INC = @Config{qw(privlibexp archlibexp)};
  return
}

=head1 NAME

lib::core::only - Remove all non-core paths from @INC to avoid site/vendor dirs

=head1 SYNOPSIS

  use lib::core::only; # now @INC contains only the two core directories

To get only the core directories plus the ones for the local::lib in scope:

  $ perl -mlocal::lib -Mlib::core::only -Mlocal::lib=~/perl5 myscript.pl

To attempt to do a self-contained build (but note this will not reliably
propagate into subprocesses, see the CAVEATS below):

  $ PERL5OPT='-mlocal::lib -Mlib::core::only -Mlocal::lib=~/perl5' cpan

Please note that it is necessary to use C<local::lib> twice for this to work.
First so that C<lib::core::only> doesn't prevent C<local::lib> from loading
(it's not currently in core) and then again after C<lib::core::only> so that
the local paths are not removed.

=head1 DESCRIPTION

lib::core::only is simply a shortcut to say "please reduce my @INC to only
the core lib and archlib (architecture-specific lib) directories of this perl".

You might want to do this to ensure a local::lib contains only the code you
need, or to test an L<App::FatPacker|App::FatPacker> tree, or to avoid known
bad vendor packages.

You might want to use this to try and install a self-contained tree of perl
modules. Be warned that that probably won't work (see L</CAVEATS>).

This module was extracted from L<local::lib|local::lib>'s --self-contained
feature, and contains the only part that ever worked. I apologise to anybody
who thought anything else did.

=head1 CAVEATS

This does B<not> propagate properly across perl invocations like local::lib's
stuff does. It can't. It's only a module import, so it B<only affects the
specific perl VM instance in which you load and import() it>.

If you want to cascade it across invocations, you can set the PERL5OPT
environment variable to '-Mlib::core::only' and it'll sort of work. But be
aware that taint mode ignores this, so some modules' build and test code
probably will as well.

You also need to be aware that perl's command line options are not processed
in order - -I options take effect before -M options, so

  perl -Mlib::core::only -Ilib

is unlike to do what you want - it's exactly equivalent to:

  perl -Mlib::core::only

If you want to combine a core-only @INC with additional paths, you need to
add the additional paths using -M options and the L<lib|lib> module:

  perl -Mlib::core::only -Mlib=lib

  # or if you're trying to test compiled code:

  perl -Mlib::core::only -Mblib

For more information on the impossibility of sanely propagating this across
module builds without help from the build program, see
L<http://www.shadowcat.co.uk/blog/matt-s-trout/tainted-love> - and for ways
to achieve the old --self-contained feature's results, look at
L<App::FatPacker|App::FatPacker>'s tree function, and at
L<App::cpanminus|cpanm>'s --local-lib-contained feature.

=head1 AUTHOR

Matt S. Trout <mst@shadowcat.co.uk>

=head1 LICENSE

This library is free software under the same terms as perl itself.

=head1 COPYRIGHT

(c) 2010 the lib::core::only L</AUTHOR> as specified above.

=cut

1;
