# $Id: TeXCatalogue.pm 61372 2021-12-21 22:46:16Z karl $
# TeXLive::TeXCatalogue - module for accessing the TeX Catalogue
# Copyright 2007-2021 Norbert Preining
# This file is licensed under the GNU General Public License version 2
# or any later version.
# 
# Loads of code adapted from the catalogue checking script of Robin Fairbairns.

use strict; use warnings;

use XML::Parser;
use XML::XPath;
use XML::XPath::XMLParser;
use Text::Unidecode;

package TeXLive::TeXCatalogue::Entry;

my $svnrev = '$Revision: 61372 $';
my $_modulerevision = ($svnrev =~ m/: ([0-9]+) /) ? $1 : "unknown";
sub module_revision { return $_modulerevision; }

=pod

=head1 NAME

C<TeXLive::TeXCatalogue> - TeX Live access to the TeX Catalogue from CTAN

=head1 SYNOPSIS

  use TeXLive::TeXCatalogue;
  my $texcat = TeXLive::TLTREE->new();

  $texcat->initialize();
  $texcat->beautify();
  $texcat->name();
  $texcat->license();
  $texcat->version();
  $texcat->caption();
  $texcat->description();
  $texcat->ctan();
  $texcat->texlive();
  $texcat->miktex();
  $texcat->docs();
  $texcat->entry();
  $texcat->alias();
  $texcat->also();
  $texcat->topics();
  $texcat->contact();
  $texcat->new(); 
  $texcat->initialize();
  $texcat->quest4texlive();
  $texcat->location();
  $texcat->entries();

=head1 DESCRIPTION

The L<TeXLive::TeXCatalogue> module provides access to the data stored
in the TeX Catalogue.

DOCUMENTATION MISSING, SORRY!!!

=cut

my $_parser = XML::Parser->new(
  ErrorContext => 2,
  ParseParamEnt => 1,
  NoLWP => 1
);

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    ioref => $params{'ioref'},
    entry => defined($params{'entry'}) ? $params{'entry'} : {},
    docs => defined($params{'docs'}) ? $params{'docs'} : {},
    name => $params{'name'},
    caption => $params{'caption'},
    description => $params{'description'},
    license => $params{'license'},
    ctan => $params{'ctan'},
    texlive => $params{'texlive'},
    miktex => $params{'miktex'},
    version => $params{'version'},
    also => defined($params{'also'}) ? $params{'also'} : [],
    topic => defined($params{'topic'}) ? $params{'topic'} : [],
    alias => defined($params{'alias'}) ? $params{'alias'} : [],
    contact => defined($params{'contact'}) ? $params{'contact'} : {},
  };
  bless $self, $class;
  if (defined($self->{'ioref'})) {
    $self->initialize();
  }
  return $self;
}

sub initialize {
  my $self = shift;
  # parse all the files
  my $parser
    = new XML::XPath->new(ioref => $self->{'ioref'}, parser => $_parser)
      || die "Failed to parse given ioref";
  $self->{'entry'}{'id'} = $parser->findvalue('/entry/@id')->value();
  $self->{'entry'}{'date'} = $parser->findvalue('/entry/@datestamp')->value();
  $self->{'entry'}{'modder'} = $parser->findvalue('/entry/@modifier')->value();
  $self->{'name'} = $parser->findvalue("/entry/name")->value();
  $self->{'caption'} = beautify($parser->findvalue("/entry/caption")->value());
  $self->{'description'} = beautify($parser->findvalue("/entry/description")->value());
  # there can be multiple entries of licenses, collected them all
  # into one string
  my $licset = $parser->find('/entry/license');
  my @liclist;
  foreach my $node ($licset->get_nodelist) {
    my $lictype = $parser->find('./@type',$node);
    push @liclist, "$lictype";
  }
  $self->{'license'} = join(' ', @liclist);
  # was before
  # $self->{'license'} = $parser->findvalue('/entry/license/@type')->value();
  $self->{'version'} = Text::Unidecode::unidecode(
                          $parser->findvalue('/entry/version/@number')->value());
  $self->{'ctan'} = $parser->findvalue('/entry/ctan/@path')->value();
  if ($parser->findvalue('/entry/texlive/@location') ne "") {
    $self->{'texlive'} = $parser->findvalue('/entry/texlive/@location')->value();
  }
  if ($parser->findvalue('/entry/miktex/@location') ne "") {
    $self->{'miktex'} = $parser->findvalue('/entry/miktex/@location')->value();
  }
  # parse all alias entries
  my $alset = $parser->find('/entry/alias');
  for my $node ($alset->get_nodelist) {
    my $id = $parser->find('./@id', $node);
    push @{$self->{'alias'}}, "$id";
  }
  # parse the documentation entries
  my $docset = $parser->find('/entry/documentation');
  foreach my $node ($docset->get_nodelist) {
    my $docfileparse = $parser->find('./@href',$node);
    # convert to string
    my $docfile = "$docfileparse";
    # see comments at end of beautify()
    my $details
      = Text::Unidecode::unidecode($parser->find('./@details',$node));
    my $language = $parser->find('./@language',$node);
    $self->{'docs'}{$docfile}{'available'} = 1;
    if ($details) { $self->{'docs'}{$docfile}{'details'} = "$details"; }
    if ($language) { $self->{'docs'}{$docfile}{'language'} = "$language"; }
  }
  # parse the also entries
  foreach my $node ($parser->find('/entry/also')->get_nodelist) {
    my $alsoid = $parser->find('./@refid',$node);
    push @{$self->{'also'}}, "$alsoid";
  }
  # parse the contact entries
  foreach my $node ($parser->find('/entry/contact')->get_nodelist) {
    my $contacttype = $parser->findvalue('./@type',$node);
    my $contacthref = $parser->findvalue('./@href',$node);
    if ($contacttype && $contacthref) {
      $self->{'contact'}{$contacttype} = $contacthref;
    }
  }
  # parse the keyval/topic entries
  foreach my $node ($parser->find('/entry/keyval')->get_nodelist) {
    my $k = $parser->findvalue('./@key',$node);
    my $v = $parser->findvalue('./@value',$node);
    # for now we only support evaluating the 'topic' key
    if ("$k" eq 'topic') {
      push @{$self->{'topic'}}, "$v";
    }
  }
}

sub beautify {
  my ($txt) = @_;
  # transliterate to ascii: it allows the final tlpdb to be pure ascii,
  # avoiding problems since we don't control the user's terminal encoding
  # Do first in case spaces are output by the transliteration.
  $txt = Text::Unidecode::unidecode($txt);
  #
  $txt =~ s/\n/ /g;  # make one line
  $txt =~ s/^\s+//g; # rm leading whitespace
  $txt =~ s/\s+$//g; # rm trailing whitespace
  $txt =~ s/\s\s+/ /g; # collapse multiple whitespace characters to one
  $txt =~ s/\t/ /g;    # tabs to spaces
  
  # one last bit of horribleness: there is one url in the descriptions
  # which is longer than our multilineformat format (in TLPOBJ). The
  # result is that it is forcibly broken. Apparently there is no way in
  # Perl to override that. This makes it impossible to get identical
  # longdesc results. Turns out that removing the "http://" prefix
  # shortens it enough to fit, so do that. The better solution would be
  # to use Text::Wrap or some other text-filling code, but going for
  # quick and dirty here.
  $txt =~ s,http://grants.nih.gov/,grants.nih.gov/,g;

  return $txt;
}

sub name {
  my $self = shift;
  if (@_) { $self->{'name'} = shift }
  return $self->{'name'};
}
sub license {
  my $self = shift;
  if (@_) { $self->{'license'} = shift }
  return $self->{'license'};
}
sub version {
  my $self = shift;
  if (@_) { $self->{'version'} = shift }
  return $self->{'version'};
}
sub caption {
  my $self = shift;
  if (@_) { $self->{'caption'} = shift }
  return $self->{'caption'};
}
sub description {
  my $self = shift;
  if (@_) { $self->{'description'} = shift }
  return $self->{'description'};
}
sub ctan {
  my $self = shift;
  if (@_) { $self->{'ctan'} = shift }
  return $self->{'ctan'};
}
sub texlive {
  my $self = shift;
  if (@_) { $self->{'texlive'} = shift }
  return $self->{'texlive'};
}
sub miktex {
  my $self = shift;
  if (@_) { $self->{'miktex'} = shift }
  return $self->{'miktex'};
}
sub docs {
  my $self = shift;
  my %newdocs = @_;
  if (@_) { $self->{'docs'} = \%newdocs }
  return $self->{'docs'};
}
sub entry {
  my $self = shift;
  my %newentry = @_;
  if (@_) { $self->{'entry'} = \%newentry }
  return $self->{'entry'};
}
sub alias {
  my $self = shift;
  my @newalias = @_;
  if (@_) { $self->{'alias'} = \@newalias }
  return $self->{'alias'};
}
sub also {
  my $self = shift;
  my @newalso = @_;
  if (@_) { $self->{'also'} = \@newalso }
  return $self->{'also'};
}
sub topics {
  my $self = shift;
  my @newtopics = @_;
  if (@_) { $self->{'topic'} = \@newtopics }
  return $self->{'topic'};
}
sub contact {
  my $self = shift;
  my %newcontact = @_;
  if (@_) { $self->{'contact'} = \%newcontact }
  return $self->{'contact'};
}


################################################################
#
# TeXLive::TeXCatalogue
#
################################################################
package TeXLive::TeXCatalogue;

sub new { 
  my $class = shift;
  my %params = @_;
  my $self = {
    location => $params{'location'},
    entries => defined($params{'entries'}) ? $params{'entries'} : {},
  };
  bless $self, $class;
  if (defined($self->{'location'})) {
    $self->initialize();
    $self->quest4texlive();
  }
  return $self;
}

sub initialize {
  my $self = shift;
  # chdir to the location of the DTD file, otherwise it cannot be found
  # furthermore we have to open the xml file from a file handle otherwise
  # the catalogue.dtd is searched in a/catalogue.dtd etc, see above
  my $cwd = `pwd -P`; # iOS: need -P so we can change back to it
  chomp($cwd);
  chdir($self->{'location'} . "/entries")
  || die "chdir($self->{location}/entries failed: $!";
  # parse all the files
  foreach (glob("?/*.xml")) {
    # for debugging, nice to skip everything but: next unless /pst-node/;
    open(my $io,"<$_") or die "open($_) failed: $!";
    our $tce;
    # the XML parser die's on malformed xml entries, so we catch
    # that and continue, simply skipping the entry
    eval { $tce = TeXLive::TeXCatalogue::Entry->new( 'ioref' => $io ); };
    if ($@) {
      warn "TeXCatalogue.pm:$_: cannot parse, skipping: $@\n";
      close($io);
      next;
    }
    close($io);
    $self->{'entries'}{lc($tce->{'entry'}{'id'})} = $tce;
  }
  chdir($cwd) || die ("Cannot change back to $cwd: $!");
}

# Copy every catalogue $entry under the name $entry->{'texlive'}
# if it makes sense.
# 
sub quest4texlive {
  my $self = shift;

  # The catalogue has a partial mapping from catalogue entries to
  # texlive packages: $id --> $texcat->{$id}{'texlive'}
  my $texcat = $self->{'entries'};

  # Try to build the inverse mapping:
  my (%inv, %count);
  for my $id (keys %{$texcat}) {
    my $tl = $texcat->{$id}{'texlive'};
    if (defined($tl)) {
      $tl =~ s/^bin-//;
      $count{$tl}++;
      $inv{$tl} = $id;
    }
  }
  # Go through texlive names
  for my $name (keys %inv) {
    # If this name is free and there is only one corresponding catalogue
    # entry then copy the entry under this name
    if (!exists($texcat->{$name}) && $count{$name} == 1) {
      $texcat->{$name} = $texcat->{$inv{$name}};
    }
  }
}

sub location {
  my $self = shift;
  if (@_) { $self->{'location'} = shift }
  return $self->{'location'};
}

sub entries {
  my $self = shift;
  my %newentries = @_;
  if (@_) { $self->{'entries'} = \%newentries }
  return $self->{'entries'};
}

1;
__END__

=head1 SEE ALSO

The other modules in C<Master/tlpkg/TeXLive/> (L<TeXLive::TLConfig> and
the rest), and the scripts in C<Master/tlpkg/bin/> (especially
C<tl-update-tlpdb>), the documentation in C<Master/tlpkg/doc/>, etc.

=head1 AUTHORS AND COPYRIGHT

This script and its documentation were written for the TeX Live
distribution (L<https://tug.org/texlive>) and both are licensed under the
GNU General Public License Version 2 or later.

=cut

### Local Variables:
### perl-indent-level: 2
### tab-width: 2
### indent-tabs-mode: nil
### End:
# vim:set tabstop=2 expandtab: #
