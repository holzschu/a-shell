# $Id: TLPSRC.pm 67326 2023-06-11 15:34:16Z karl $
# TeXLive::TLPSRC.pm - module for handling tlpsrc files
# Copyright 2007-2023 Norbert Preining
# This file is licensed under the GNU General Public License version 2
# or any later version.

use strict; use warnings;

package TeXLive::TLPSRC;

use FileHandle;
use TeXLive::TLConfig qw($CategoriesRegexp $DefaultCategory);
use TeXLive::TLUtils;
use TeXLive::TLPOBJ;
use TeXLive::TLTREE;

my $svnrev = '$Revision: 67326 $';
my $_modulerevision = ($svnrev =~ m/: ([0-9]+) /) ? $1 : "unknown";
sub module_revision { return $_modulerevision; }

=pod

=head1 NAME

C<TeXLive::TLPSRC> -- TeX Live Package Source (C<.tlpsrc>) module

=head1 SYNOPSIS

  use TeXLive::TLPSRC;

  my $tlpsrc = TeXLive::TLPSRC->new(name => "foobar");
  $tlpsrc->from_file("/some/tlpsrc/package.tlpsrc");
  $tlpsrc->from_file("package");
  $tlpsrc->writeout;
  $tlpsrc->writeout(\*FILEHANDLE);

=head1 DESCRIPTION

The C<TeXLive::TLPSRC> module handles TeX Live Package Source
(C<.tlpsrc>) files, which contain all (and only) the information which
cannot be automatically derived from other sources, notably the TeX Live
directory tree and the TeX Catalogue.  In other words, C<.tlpsrc> files
are hand-maintained.

Often they are empty, when all information can be derived from the
package name, which is (by default) the base name of the C<.tlpsrc> file.

=cut

my $_tmp; # sorry
my %autopatterns;  # computed once internally

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    name        => $params{'name'},
    category    => defined($params{'category'}) ? $params{'category'}
                                                : $DefaultCategory,
    shortdesc   => $params{'shortdesc'},
    longdesc    => $params{'longdesc'},
    catalogue   => $params{'catalogue'},
    runpatterns => $params{'runpatterns'},
    srcpatterns => $params{'srcpatterns'},
    docpatterns => $params{'docpatterns'},
    binpatterns => $params{'binpatterns'},
    postactions => $params{'postactions'},
    executes    => defined($params{'executes'}) ? $params{'executes'} : [],
    depends     => defined($params{'depends'}) ? $params{'depends'} : [],
  };
  bless $self, $class;
  return $self;
}


sub from_file {
  my $self = shift;
  die "need exactly one filename for initialization" if @_ != 1;
  my $srcfile = $_[0];
  my $pkgname = TeXLive::TLUtils::basename($srcfile);
  $pkgname =~ s/\.tlpsrc$//;

  if (! -r "$srcfile") {
    # if the argument is not readable as is, try looking for it in the
    # hierarchy where we are.  The %INC hash records where packages were
    # found, so we use that to locate ourselves.
    (my $trydir = $INC{"TeXLive/TLPSRC.pm"}) =~ s,/[^/]*$,,;
    chomp ($trydir = `cd $trydir/../tlpsrc && pwd`);  # make absolute
    my $tryfile = "$trydir/$pkgname.tlpsrc";
    #warn "$trydir\n$tryfile\n";
    $srcfile = $tryfile if -r $tryfile;
  }
  
  open(TMP, "<$srcfile") || die("failed to open tlpsrc '$srcfile': $!");
  my @lines = <TMP>;
  close(TMP);

  my $name = $pkgname;
  my $category = "Package";
  my $shortdesc = "";
  my $longdesc= "";
  my $catalogue = "";
  my (@executes, @depends);
  my (@runpatterns, @docpatterns, @binpatterns, @srcpatterns);
  my (@postactions);
  my $foundnametag = 0;
  my $finished = 0;
  my $savedline = "";
  my %tlpvars;
  $tlpvars{"PKGNAME"} = $name;

  my $lineno = 0;
  for my $line (@lines) {
    $lineno++;
    
    # remove end of line comments
    # we require "<space>#" because since we don't want an embedded # in
    # long descriptions, as in urls, to be a comment.
    # Do this *before* we check for continuation lines: A line
    #      .... # foobar \
    # should *not* be treated as continuation line.
    $line =~ s/\s+#.*$//;

    # we allow continuation lines in tlpsrc files, i.e., lines ending with \.
    if ($line =~ /^(.*)\\$/) {
      $savedline .= $1;
      next;
    }
    if ($savedline ne "") {
      # we are in a continuation line
      $line = "$savedline$line";
      $savedline = "";
    }

    $line =~ /^\s*#/ && next;          # skip comment lines
    next if $line =~ /^\s*$/;          # skip blank lines
    # (blank lines are significant in tlpobj, but not tlpsrc)
    #
    $line =~ /^ /
      && die "$srcfile:$lineno: non-continuation indentation not allowed: `$line'";
    #
    # remove trailing comment (whitespace preceding #).
    $line =~ s/\s+#.*$//;
    #
    # remove other trailing white space.
    $line =~ s/\s+$//;

    # expand tlpvars while reading in (except in descriptions).
    # that means we have to respect *order* and define variables
    # as we read the tlpsrc file.
    if ($line !~ /^(short|long)desc\s/) {
      #debug: my $origline = $line;
      for my $k (keys %tlpvars) {
        $line =~ s/\$\{\Q$k\E\}/$tlpvars{$k}/g;
      }
      # check that no variables remain unexpanded, or rather, for any
      # remaining $ (which we don't otherwise allow in tlpsrc files, so
      # should never occur) ... except for ${ARCH} which we specially
      # expand in TLTREE.pm, and ${global_*} which need to
      # be defined in 00texlive.autopatterns.tlpsrc. (We distribute one
      # file dvi$pdf.bat, but fortunately it is matched by a directory.)
      # 
      (my $testline = $line) =~ s,\$\{ARCH\},,g;
      $testline =~ s,\$\{(global_[^}]*)\},,g;
      $testline =~ /\$/
        && die "$srcfile:$lineno: variable undefined or syntax error: $line\n";
      #debug: warn "new line $line, from $origline\n" if $origline ne $line;
    } # end variable expansion.

    # names of source packages can either be
    # - normal names: ^[-\w]+$
    # - windows specific packages: ^[-\w]+\.windows$
    # - normal texlive specific packages: ^texlive.*\..*$
    # - configuration texlive specific packages: ^00texlive.*\..*$
    if ($line =~ /^name\s/) {
      $line =~ /^name\s+([-\w]+(\.windows)?|(00)?texlive\..*)$/;
      $foundnametag 
        && die "$srcfile:$lineno: second name directive not allowed: $line"
               . "(have $name)\n";
      $name = $1;
      $foundnametag = 1;
      # let's assume that $PKGNAME doesn't occur before any name
      # directive (which would result in different expansions); there is
      # no need for it in practice.
      $tlpvars{"PKGNAME"} = $name;

    } elsif ($line =~ /^category\s+$CategoriesRegexp$/) {
      $category = $1;

    } elsif ($line =~ /^shortdesc\s*(.*)$/) {
      $shortdesc
        && die "$srcfile:$lineno: second shortdesc not allowed: $line"
               . "(have $shortdesc)\n";
      $shortdesc = $1;

    } elsif ($line =~ /^shortdesc$/) {
      $shortdesc = "";

    } elsif ($line =~ /^longdesc$/) {
      # We need to use a space here instead of a newline so that strings
      # read from *.tlpsrc and tlpdb come out the same; see $shortdesc
      # and $longdesc assignments below.
      $longdesc .= " ";

    } elsif ($line =~ /^longdesc\s+(.*)$/) {
      $longdesc .= "$1 ";

    } elsif ($line =~ /^catalogue\s+(.*)$/) {
      $catalogue
        && die "$srcfile:$lineno: second catalogue not allowed: $line"
               . "(have $catalogue)\n";
      $catalogue = $1;

    } elsif ($line =~ /^runpattern\s+(.*)$/) {
      push (@runpatterns, $1) if ($1 ne "");

    } elsif ($line =~ /^srcpattern\s+(.*)$/) {
      push (@srcpatterns, $1) if ($1 ne "");

    } elsif ($line =~ /^docpattern\s+(.*)$/) {
      push (@docpatterns, $1) if ($1 ne "");

    } elsif ($line =~ /^binpattern\s+(.*)$/) {
      push (@binpatterns, $1) if ($1 ne "");

    } elsif ($line =~ /^execute\s+(.*)$/) {
      push (@executes, $1) if ($1 ne "");

    } elsif ($line =~ /^(depend|hard)\s+(.*)$/) {
      push (@depends, $2) if ($2 ne "");

    } elsif ($line =~ /^postaction\s+(.*)$/) {
      push (@postactions, $1) if ($1 ne "");

    } elsif ($line =~ /^tlpsetvar\s+([-_a-zA-Z0-9]+)\s+(.*)$/) {
      $tlpvars{$1} = $2;

    } elsif ($line =~ /^catalogue-([^\s]+)\s+(.*)$/o) {
      $self->{'cataloguedata'}{$1} = $2 if defined $2;

    } else {
      die "$srcfile:$lineno: unknown tlpsrc directive, fix: $line\n";
    }
  }
  $self->_srcfile($srcfile);
  $self->_tlpvars(\%tlpvars);
  if ($name =~ m/^[[:space:]]*$/) {
    die "Cannot deduce name from file argument and name tag not found";
  }
  #
  # We should call TeXCatalogue::beautify(), but let's be lazy since not
  # everything comes up in practice. We want the parsing from .tlpsrc to
  # result in exactly the same string, including spaces, as parsing from
  # texlive.tlpdb. Otherwise tl-update-tlpdb's tlpdb_catalogue_compare
  # will think the strings are always different.
  $shortdesc =~ s/\s+$//g;  # rm trailing whitespace (shortdesc)
  $longdesc =~ s/\s+$//g;   # rm trailing whitespace (longdesc)
  $longdesc =~ s/\s\s+/ /g; # collapse multiple whitespace characters to one
  # see comments in beautify.
  $longdesc =~ s,http://grants.nih.gov/,grants.nih.gov/,g;
  #
  $self->name($name);
  $self->category($category);
  $self->catalogue($catalogue) if $catalogue;
  $self->shortdesc($shortdesc) if $shortdesc;
  $self->longdesc($longdesc) if $longdesc;
  $self->srcpatterns(@srcpatterns) if @srcpatterns;
  $self->runpatterns(@runpatterns) if @runpatterns;
  $self->binpatterns(@binpatterns) if @binpatterns;
  $self->docpatterns(@docpatterns) if @docpatterns;
  $self->executes(@executes) if @executes;
  $self->depends(@depends) if @depends;
  $self->postactions(@postactions) if @postactions;
}


sub writeout {
  my $self = shift;
  my $fd = (@_ ? $_[0] : *STDOUT);
  format_name $fd "multilineformat";  # format defined in TLPOBJ, and $:
  $fd->format_lines_per_page (99999); # no pages in this format
  print $fd "name ", $self->name, "\n";
  print $fd "category ", $self->category, "\n";
  defined($self->{'catalogue'}) && print $fd "catalogue $self->{'catalogue'}\n";
  defined($self->{'shortdesc'}) && print $fd "shortdesc $self->{'shortdesc'}\n";
  if (defined($self->{'longdesc'})) {
    $_tmp = "$self->{'longdesc'}";
    write $fd;  # use that multilineformat
  }
  if (defined($self->{'depends'})) {
    foreach (@{$self->{'depends'}}) {
      print $fd "depend $_\n";
    }
  }
  if (defined($self->{'executes'})) {
    foreach (@{$self->{'executes'}}) {
      print $fd "execute $_\n";
    }
  }
  if (defined($self->{'postactions'})) {
    foreach (@{$self->{'postactions'}}) {
      print $fd "postaction $_\n";
    }
  }
  if (defined($self->{'srcpatterns'}) && (@{$self->{'srcpatterns'}})) {
    foreach (sort @{$self->{'srcpatterns'}}) {
      print $fd "srcpattern $_\n";
    }
  }
  if (defined($self->{'runpatterns'}) && (@{$self->{'runpatterns'}})) {
    foreach (sort @{$self->{'runpatterns'}}) {
      print $fd "runpattern $_\n";
    }
  }
  if (defined($self->{'docpatterns'}) && (@{$self->{'docpatterns'}})) {
    foreach (sort @{$self->{'docpatterns'}}) {
      print $fd "docpattern $_\n";
    }
  }
  if (defined($self->{'binpatterns'}) && (@{$self->{'binpatterns'}})) {
    foreach (sort @{$self->{'binpatterns'}}) {
      print $fd "binpattern $_\n";
    }
  }
}


# the hard work, generate the TLPOBJ data.
#
sub make_tlpobj {
  my ($self,$tltree,$autopattern_root) = @_;
  my %allpatterns = &find_default_patterns($autopattern_root);
  my %global_tlpvars = %{$allpatterns{'tlpvars'}};
  my $category_patterns = $allpatterns{$self->category};

  # tlpsrc tlpvars are already applied during tlpsrc read in time
  # now apply the global tlpvars from 00texlive.autopatterns.tlpsrc
  # update the execute and depend strings
  my @exes = $self->executes;
  my @deps = $self->depends;
  for my $key (keys %global_tlpvars) {
    s/\$\{\Q$key\E\}/$global_tlpvars{$key}/g for @deps;
    s/\$\{\Q$key\E\}/$global_tlpvars{$key}/g for @exes;
  }
  $self->depends(@deps);
  $self->executes(@exes);

  my $tlp = TeXLive::TLPOBJ->new;
  $tlp->name($self->name);
  $tlp->category($self->category);
  $tlp->shortdesc($self->{'shortdesc'}) if (defined($self->{'shortdesc'}));
  $tlp->longdesc($self->{'longdesc'}) if (defined($self->{'longdesc'}));
  $tlp->catalogue($self->{'catalogue'}) if (defined($self->{'catalogue'}));
  $tlp->cataloguedata(%{$self->{'cataloguedata'}}) if (defined($self->{'cataloguedata'}));
  $tlp->executes(@{$self->{'executes'}}) if (defined($self->{'executes'}));
  $tlp->postactions(@{$self->{'postactions'}}) if (defined($self->{'postactions'}));
  $tlp->depends(@{$self->{'depends'}}) if (defined($self->{'depends'}));
  $tlp->revision(0);

  # convert each fmttrigger to a depend line, if not already present.
  if (defined($tlp->executes)) { # else no fmttriggers
    my @deps = (defined($tlp->depends) ? $tlp->depends : ());
    my $tlpname = $tlp->name;
    for my $e ($tlp->executes) {
      # we only check for AddFormat lines
      if ($e =~ m/^\s*AddFormat\s+(.*)\s*$/) {
        my %fmtline = TeXLive::TLUtils::parse_AddFormat_line($1);
        if (defined($fmtline{"error"})) {
          tlwarn ("error in parsing $e for return hash: $fmtline{error}\n");
        } else {
          # make sure that we don't add circular deps
          TeXLive::TLUtils::push_uniq (\@deps,
            grep { $_ ne $tlpname } @{$fmtline{'fmttriggers'}});
        }
      }
    }
    $tlp->depends(@deps);
  }

  my $filemax;
  my $usedefault;
  my @allpospats;
  my @allnegpats;
  my $pkgname = $self->name;
  my @autoaddpat;

  # src/run/doc patterns
  #
  # WARNING WARNING WARNING
  # the "bin" must be last since we drop through for further dealing
  # with specialities of the bin patterns!!!!
  for my $pattype (qw/src run doc bin/) {
    @allpospats = ();
    @allnegpats = ();
    @autoaddpat = ();
    $usedefault = 1;
    foreach my $p (@{$self->{${pattype} . 'patterns'}}) {
      # Expansion of ${global_...} variables from autopatterns.
      for my $key (keys %global_tlpvars) {
        $p =~ s/\$\{\Q$key\E\}/$global_tlpvars{$key}/g;
      }
      
      if ($p =~ m/^a\s+(.*)\s*$/) {
        # format 
        #   a toplevel1 toplevel2 toplevel3 ...
        # which add autopatterns as if we are doing single packages
        # toplevel1 toplevel2 toplevel3
        push @autoaddpat, split(' ', $1);
      } elsif ($p =~ m/^!\+(.*)$/) {
        push @allnegpats, $1;
      } elsif ($p =~ m/^\+!(.*)$/) {
        push @allnegpats, $1;
      } elsif ($p =~ m/^\+(.*)$/) {
        push @allpospats, $1;
      } elsif ($p =~ m/^!(.*)$/) {
        push @allnegpats, $1;
        $usedefault = 0;
      } else {
        push @allpospats, $p;
        $usedefault = 0;
      }
    }

    if ($usedefault) {
      push @autoaddpat, $pkgname;
    }
    if (defined($category_patterns)) {
      for my $a (@autoaddpat) {
        my $type_patterns = $category_patterns->{$pattype};
        for my $p (@{$type_patterns}) {
          # the occurrence of %[str:]NAME[:str]% and its 
          # expansion is documented in 00texlive.autopatterns.tlpsrc
          # we have to make a copy of $p otherwise we change it in the
          # hash once and for all
          my $pp = $p;
          while ($pp =~ m/%(([^%]*):)?NAME(:([^%]*))?%/) {
            my $nn = $a;
            if (defined($1)) {
              $nn =~ s/^$2//;
            }
            if (defined($3)) {
              $nn =~ s/$4$//;
            }
            $pp =~ s/%(([^%]*):)?NAME(:([^%]*))?%/$nn/;
          }
          # replace the string %NAME% with the actual package name
          #(my $pp = $p) =~ s/%NAME%/$a/g;
          # sort through the patterns, and make sure that * are added to 
          # tag the default patterns
          if ($pp =~ m/^!(.*)$/) {
            push @allnegpats, "*$1";
          } else {
            push @allpospats, "*$pp";
          }
        }
      }
    }
    # at this point we do NOT do the actual pattern matching for 
    # bin patterns, since we have some specialities to do
    last if ($pattype eq "bin");
    
    # for all other patterns we create the list and add the files
    foreach my $p (@allpospats) {
      ddebug("pos pattern $p\n");
      $self->_do_normal_pattern($p,$tlp,$tltree,$pattype);
    }
    foreach my $p (@allnegpats) {
      ddebug("neg pattern $p\n");
      $self->_do_normal_pattern($p,$tlp,$tltree,$pattype,1);
    }
  }
  #
  # binpatterns
  #
  # mind that @allpospats and @allnegpats have already been set up
  # in the above loop. We only have to deal with the specialities of
  # the bin patterns
  foreach my $p (@allpospats) {
    my @todoarchs = $tltree->architectures;
    my $finalp = $p;
    if ($p =~ m%^(\w+)/(!?[-_a-z0-9,]+)\s+(.*)$%) {
      my $pt = $1;
      my $aa = $2;
      my $pr = $3;
      if ($aa =~ m/^!(.*)$/) {
        # negative specification
        my %negarchs;
        foreach (split(/,/,$1)) {
          $negarchs{$_} = 1;
        }
        my @foo = ();
        foreach (@todoarchs) {
          push @foo, $_ unless defined($negarchs{$_});
        }
        @todoarchs = @foo;
      } else {
        @todoarchs = split(/,/,$aa);
      }
      # set $p to the pattern without arch specification
      $finalp = "$pt $pr";
    }
    # one final trick
    # if the original pattern string matches bin/windows/ then we *only*
    # work on the windows arch
    if ($finalp =~ m! bin/windows/!) {
      @todoarchs = qw/windows/;
    }
    # now @todoarchs contains only those archs for which we want
    # to match the pattern
    foreach my $arch (sort @todoarchs) {
      # get only those files matching the pattern
      my @archfiles = $tltree->get_matching_files('bin',$finalp, $pkgname, $arch);
      if (!@archfiles) {
        if (($arch ne "windows") || defined($::tlpsrc_pattern_warn_win)) {
          tlwarn("$self->{name} ($arch): no hit on binpattern $finalp\n");
        }
      }
      $tlp->add_binfiles($arch,@archfiles);
    }
  }
  foreach my $p (@allnegpats) {
    my @todoarchs = $tltree->architectures;
    my $finalp = $p;
    if ($p =~ m%^(\w+)/(!?[-_a-z0-9,]+)\s+(.*)$%) {
      my $pt = $1;
      my $aa = $2;
      my $pr = $3;
      if ($aa =~ m/^!(.*)$/) {
        # negative specification
        my %negarchs;
        foreach (split(/,/,$1)) {
          $negarchs{$_} = 1;
        }
        my @foo = ();
        foreach (@todoarchs) {
          push @foo, $_ unless defined($negarchs{$_});
        }
        @todoarchs = @foo;
      } else {
        @todoarchs = split(/,/,$aa);
      }
      # set $p to the pattern without arch specification
      $finalp = "$pt $pr";
    }
    # now @todoarchs contains only those archs for which we want
    # to match the pattern
    foreach my $arch (sort @todoarchs) {
      # get only those files matching the pattern
      my @archfiles = $tltree->get_matching_files('bin', $finalp, $pkgname, $arch);
      if (!@archfiles) {
        if (($arch ne "windows") || defined($::tlpsrc_pattern_warn_win)) {
          tlwarn("$self->{name} ($arch): no hit on negative binpattern $finalp\n")
            unless $::tlpsrc_pattern_no_warn_negative;
            # see comments in libexec/place script.
        }
      }
      $tlp->remove_binfiles($arch,@archfiles);
    }
  }
  # add the revision number of the .tlpsrc file to the compute list:
  $tlp->recompute_revision($tltree, 
          $tltree->file_svn_lastrevision("tlpkg/tlpsrc/$self->{name}.tlpsrc"));
  $tlp->recompute_sizes($tltree);
  return $tlp;
}

sub _do_normal_pattern {
  my ($self,$p,$tlp,$tltree,$type,$negative) = @_;
  my $is_default_pattern = 0;
  if ($p =~ m/^\*/) {
    $is_default_pattern = 1;
    $p =~ s/^\*//;
  }
  my @matchfiles = $tltree->get_matching_files($type, $p, $self->{'name'});
  if (!$is_default_pattern && !@matchfiles
      && ($p !~ m,^f ignore,) && ($p !~ m,^d tlpkg/backups,)) {
    tlwarn("$self->{name}: no hit for pattern $p\n")
      unless $negative && $::tlpsrc_pattern_no_warn_negative;
  }
  if (defined($negative) && $negative == 1) {
    $tlp->remove_files($type,@matchfiles);
  } else {
    $tlp->add_files($type,@matchfiles);
  }
}


# =item C<find_default_patterns($tlroot)>
# 
# Get the default patterns for all categories from an external file.
# 
# Return hash with keys being the categories (Package, Collection, etc.)
# and values being refs to another hash.  The subhash's keys are the
# file types (run bin doc ...) with values being refs to an array of
# patterns for that type.
# 
# The returned hash has an additional key C<tlpvars> for global tlpsrc
# variables, which can be used in any C<.tlpsrc> files. The names of these
# variables all start with C<global_>.
# 
# =cut 
# (all doc at bottom, let's not rewrite now.)

sub find_default_patterns {
  my ($tlroot) = @_;
  # %autopatterns is global.
  return %autopatterns if keys %autopatterns;  # only compute once
  
  my $apfile = "$tlroot/tlpkg/tlpsrc/00texlive.autopatterns.tlpsrc";
  die "No autopatterns file found: $apfile" if ! -r $apfile;

  my $tlsrc = new TeXLive::TLPSRC;
  $tlsrc->from_file ($apfile);
  if ($tlsrc->binpatterns) {
    for my $p ($tlsrc->binpatterns) {
      my ($cat, @rest) = split ' ', $p;
      push @{$autopatterns{$cat}{"bin"}}, join(' ', @rest);
    }
  }
  if ($tlsrc->srcpatterns) {
    for my $p ($tlsrc->srcpatterns) {
      my ($cat, @rest) = split ' ', $p;
      push @{$autopatterns{$cat}{"src"}}, join(' ', @rest);
    }
  }
  if ($tlsrc->docpatterns) {
    for my $p ($tlsrc->docpatterns) {
      my ($cat, @rest) = split ' ', $p;
      push @{$autopatterns{$cat}{"doc"}}, join(' ', @rest);
    }
  }
  if ($tlsrc->runpatterns) {
    for my $p ($tlsrc->runpatterns) {
      my ($cat, @rest) = split ' ', $p;
      push @{$autopatterns{$cat}{"run"}}, join(' ', @rest);
    }
  }

  for my $cat (keys %autopatterns) {
    ddebug ("Category $cat\n");
    for my $d (@{$autopatterns{$cat}{"bin"}}) {
      ddebug ("auto bin pattern $d\n");
    }
    for my $d (@{$autopatterns{$cat}{"src"}}) {
      ddebug ("auto src pattern $d\n");
    }
    for my $d (@{$autopatterns{$cat}{"doc"}}) {
      ddebug ("auto doc pattern $d\n");
    }
    for my $d (@{$autopatterns{$cat}{"run"}}) {
      ddebug ("auto run pattern $d\n");
    }
  }
  
  # check defined variables to ensure their names start with "global_".
  my %gvars = %{$tlsrc->_tlpvars};
  for my $v (keys %gvars) {
    if ($v !~ /^(global_[-_a-zA-Z0-9]+)$/) {
      tlwarn("$apfile: variable does not start with global_: $v\n")
        unless $v eq "PKGNAME";
        # the auto-defined PKGNAME is not expected to be global.
      delete $gvars{$v};
    }
  } # we'll usually unnecessarily create a second hash, but so what.
  $autopatterns{'tlpvars'} = \%gvars;

  return %autopatterns;
}


# member access functions
#
sub _srcfile {
  my $self = shift;
  if (@_) { $self->{'_srcfile'} = shift }
  return $self->{'_srcfile'};
}
sub _tlpvars {
  my $self = shift;
  if (@_) { $self->{'_tlpvars'} = shift; }
  return $self->{'_tlpvars'};
}
sub name {
  my $self = shift;
  if (@_) { $self->{'name'} = shift }
  return $self->{'name'};
}
sub category {
  my $self = shift;
  if (@_) { $self->{'category'} = shift }
  return $self->{'category'};
}
sub shortdesc {
  my $self = shift;
  if (@_) { $self->{'shortdesc'} = shift }
  return $self->{'shortdesc'};
}
sub longdesc {
  my $self = shift;
  if (@_) { $self->{'longdesc'} = shift }
  return $self->{'longdesc'};
}
sub catalogue {
  my $self = shift;
  if (@_) { $self->{'catalogue'} = shift }
  return $self->{'catalogue'};
}
sub cataloguedata {
  my $self = shift;
  my %ct = @_;
  if (@_) { $self->{'cataloguedata'} = \%ct }
  return $self->{'cataloguedata'};
}
sub srcpatterns {
  my $self = shift;
  if (@_) { @{ $self->{'srcpatterns'} } = @_ }
  if (defined($self->{'srcpatterns'})) {
    return @{ $self->{'srcpatterns'} };
  } else {
    return;
  }
}
sub docpatterns {
  my $self = shift;
  if (@_) { @{ $self->{'docpatterns'} } = @_ }
  if (defined($self->{'docpatterns'})) {
    return @{ $self->{'docpatterns'} };
  } else {
    return;
  }
}
sub binpatterns {
  my $self = shift;
  if (@_) { @{ $self->{'binpatterns'} } = @_ }
  if (defined($self->{'binpatterns'})) {
    return @{ $self->{'binpatterns'} };
  } else {
    return;
  }
}
sub depends {
  my $self = shift;
  if (@_) { @{ $self->{'depends'} } = @_ }
  return @{ $self->{'depends'} };
}
sub runpatterns {
  my $self = shift;
  if (@_) { @{ $self->{'runpatterns'} } = @_ }
  if (defined($self->{'runpatterns'})) {
    return @{ $self->{'runpatterns'} };
  } else {
    return;
  }
}
sub executes {
  my $self = shift;
  if (@_) { @{ $self->{'executes'} } = @_ }
  return @{ $self->{'executes'} };
}
sub postactions {
  my $self = shift;
  if (@_) { @{ $self->{'postactions'} } = @_ }
  return @{ $self->{'postactions'} };
}

1;
__END__


=head1 FILE SPECIFICATION

A C<tlpsrc> file consists of lines of the form:

I<key> I<value>

where I<key> can be one of: C<name> C<category> C<catalogue>
C<shortdesc> C<longdesc> C<depend> C<execute> C<postaction> C<tlpsetvar>
C<runpattern> C<srcpattern> C<docpattern> C<binpattern>.

Continuation lines are supported via a trailing backslash.  That is, if
the C<.tlpsrc> file contains two physical lines like this:
  
  foo\
  bar

they are concatenated into C<foobar>.  The backslash and the newline are
removed; no other whitespace is added or removed.

Comment lines begin with a # and continue to the end of the line.
Within a line, a # that is preceded by whitespace is also a comment.

Blank lines are ignored.

The I<key>s are described in the following sections.

=head2 C<name>

identifies the package; C<value> must consist only of C<[-_a-zA-Z0-9]>,
i.e., with what Perl considers a C<\w>. It is optional; if not
specified, the name of the C<.tlpsrc> file will be used (with the
C<.tlpsrc> removed).

There are three exceptions to this rule:

=over 4

=item B<name.ARCH>

where B<ARCH> is a supported architecture-os combination.  This has two
uses.  First, packages are split (automatically) into containers for the
different architectures to make possible installations including only
the necessary binaries.  Second, one can add 'one-arch-only' packages,
often used to deal with Windows peculiarities.

=item B<texlive>I<some.thing>

(notice the dot in the package name) These packages are core TeX Live
packages. They are treated as usual packages in almost all respects, but
have that extra dot to be sure they will never clash with any package
that can possibly appear on CTAN. The only such package currently is
C<texlive.infra>, which contains L<tlmgr> and other basic infrastructure
functionality.

=item B<00texlive>I<something>

These packages are used for internal operation and storage containers
for settings.  I<00texlive> packages are never be split into separate
arch-packages, and containers are never generated for these packages.

The full list of currently used packages of this type is:

=over 8

=item B<00texlive.config>

This package contains configuration options for the TeX Live archive.
If container_split_{doc,src}_files occurs in the depend lines the
{doc,src} files are split into separate containers (.tar.xz) 
during container build time. Note that this has NO effect on the
appearance within the texlive.tlpdb. It is only on container level.
The container_format/XXXXX specifies the format, currently allowed
is only "xz", which generates .tar.xz files. zip can be supported.
release/NNNN specifies the release number as used in the installer.

=item B<00texlive.installation>

This package serves a double purpose:

1. at installation time the present values are taken as default for
the installer

2. on an installed system it serves as configuration file. Since
we have to remember these settings for additional package
installation, removal, etc.

=item B<00texlive.image>

This package collects some files which are not caught by any of the
other TL packages. Its primary purpose is to make the file coverage
check happy.  The files here are not copied by the installer
and containers are not built; they exist only in the
TeX Live Master tree.

=item B<00texlive.installer>

This package defines the files to go into the installer
archives (install-tl-unx.tar.gz, install-tl.zip) built
by the tl-make-installer script.  Most of what's here is also
included in the texlive.infra package -- ordinarily duplicates
are not allowed, but in this case, 00texlive.installer is never
used *except* to build the installer archives, so it's ok.

=back

=back

=head2 C<category>

identifies the category into which this package belongs. This determines
the default patterns applied. Possible categories are defined in
C<TeXLive::TLConfig>, currently C<Collection>, C<Scheme>, C<TLCore>,
C<Package>, C<ConTeXt>. Most packages fall into the C<Package> category,
and this is the default if not specified.

=head2 C<catalogue>

identifies the name under which this package can be found in the TeX
Catalogue. If not specified, the package name is used.

=head2 C<shortdesc>

gives a one line description of the package. Later lines overwrite
earlier, so there's no use in giving it more than once. If not
specified, the default is taken from the TeX Catalogue, which suffices
for almost all normal packages. Thus, in TeX Live, primarily used for
collections and schemes.

=head2 C<longdesc>

gives a long description of the package. Later lines are appended to
earlier ones. As with C<shortdesc>, if not specified, the default is
taken from the TeX Catalogue, which suffices for almost all normal
packages.

=head2 C<depend>

specifies the list of dependencies, which are just other package names.
All the C<depend> lines contribute to the dependencies of the package.
For example, C<latex.tlpsrc> contains (among others):
  
  depend latexconfig
  depend latex-fonts
  depend pdftex

to ensure these packages are installed if the C<latex> package is.  The
directive C<hard> is an alias for C<depend>, since that's we specified
for the C<DEPENDS.txt> files package authors can provide; see
L<https://www.tug.org/texlive/pkgcontrib.html#deps>.

=head2 C<execute>

specifies an install-time action to be executed. The following actions
are supported:

=over 4

=item C<execute addMap> I<font>C<.map>

enables the font map file I<font>C<.map> in the C<updmap.cfg> file.

=item C<execute addMixedMap> I<font>C<.map>

enables the font map file I<font>C<.map> for Mixed mode in the
C<updmap.cfg> file.

=item C<execute AddHyphen name=I<texlang> file=I<file> [I<var>...]>

activates the hyphenation pattern with name I<texlang> and load the file
I<file> for that language.  The additional variables I<var> are:
C<lefthyphenmin>, C<righthyphenmin> (both integers), C<synonyms> (a
comma-separated list of alias names for that hyphenation), C<databases>
(a comma-separated list of databases the entry should go in; currently
recognized are: C<dat> (C<language.dat>), C<def> (C<language.def>) and
C<lua> (C<language.dat.lua>)), C<file_patterns> and C<file_exceptions>
(files with the patterns (resp. exceptions) in plain txt), and
C<luaspecial> (string).

The variable C<databases> defaults to C<dat,def>, or C<dat,def,lua> if
one of the keys C<file_patterns>, C<file_exceptions> or C<luaspecial> is
used.

=item C<execute AddFormat name=I<fmt> engine=I<eng> [I<var>...]>

activates the format with name I<fmt> based on the engine I<eng>. The 
additional variables I<var> are:
C<mode> which can only be equal to C<disable> in which case the format
will only be mentioned but disabled (prefixed with C<#!>;
C<patterns> which gives the patterns file, if not present C<-> is used;
C<options> which gives the additional options for the C<fmtutil.cnf> file.

=back

=head2 C<postaction>

specifies a post-install or post-removal action to be
executed. The difference to the C<execute> statement is that 
C<postaction> is concerned with system integration, i.e., adjusting
things outside the installation directory, while C<execute> touches
only things within the installation.

The following actions are supported:

=over 4

=item C<postaction shortcut name=I<name> type=menu|desktop icon=I<path> cmd=I<cmd> args=I<args> hide=0|1>

On W32 creates a shortcut either in the main TeX Live menu or on the
desktop. See the documentation of L<TeXLive::TLWinGoo> for details.

=item C<postaction filetype name=I<name> cmd=I<cmd>>

On W32 associates the file type I<name> with the command I<cmd>.

=item C<postaction fileassoc extension=I<.ext> filetype=I<name>>

On W32 declares files with the extenstion I<.ext> of file type I<name>.

=item C<postaction script file=I<file> [filew32=I<filew32>]>

This postaction executes the given I<file> with two arguments, the first
being either the string C<install> or C<remove>, the second being the
root of the installation.

If the C<filew32> argument is given this script is run on Windows systems
instead of the one given via C<file>.

=back

=head2 C<tlpsetvar> I<var> I<val>

sets variable I<var> to I<val>. Order matters: the variable can be
expanded with C<${>I<var>C<}>, only after it is defined. Characters
allowed in the I<var> name are C<-_a-zA-Z0-9>.

For example, the Xindy program is not supported on all platforms, so we
define a variable:

  tlpsetvar no_xindy_platforms i386-solaris,x86_64-linuxmusl,x86_64-solaris

that can then by used in each C<binpattern> needed:

  binpattern f/!${no_xindy_platforms} bin/${ARCH}/texindy
  binpattern f/!${no_xindy_platforms} bin/${ARCH}/tex2xindy
  ...

(The C<binpattern> details are below; here, just notice the variable
definition and expansion.)

Ordinarily, variables can be used only within the C<.tlpsrc> file where
they are defined. There is one exception: global tlpsrc variables can be
defined in the C<00texlive.autopatterns.tlpsrc> file (mentioned below);
their names must start with C<global_>,
and can only be used in C<depend>, C<execute>, and C<...pattern>
directives, another C<tlpsetvar>. For example, our
C<autopatterns.tlpsrc> defines:

  tlpsetvar global_latex_deps babel,cm,hyphen-base,latex-fonts

And then any other C<.tlpsrc> files can use it as
C<${global_latex_deps}>; in this case, C<latex-bin.tlpsrc>,
C<latex-bin-dev.tlpsrc>, C<platex.tlpsrc>, and others (in C<execute
AddFormat> directives).

=head2 C<(src|run|doc|bin)pattern> I<pattern>

adds I<pattern> (next section) to the respective list of patterns.

=head1 PATTERNS

Patterns specify which files are to be included into a C<tlpobj> at
expansion time. Patterns are of the form

  [PREFIX]TYPE[/[!]ARCHSPEC] PAT

where

  PREFIX = + | +! | !
  TYPE = t | f | d | r
  ARCHSPEC = <list of architectures separated by comma>

Simple patterns without PREFIX and ARCHSPEC specifications are explained
first.

=over 4

=item C<f> I<path>

includes all files which match C<path> where B<only> the last component
of C<path> can contain the usual glob characters C<*> and C<?> (but no
others!). The special string C<ignore> for I<path> means to ignore this
pattern (used to eliminate the auto-pattern matching).

=item C<d> I<path>

includes all the files in and below the directory specified as C<path>.

=item C<r> I<regexp>

includes all files matching the regexp C</^regexp$/>.

=item C<a> I<name1> [<name2> ...]

includes auto-generated patterns for each I<nameN> as if the package
itself would be named I<nameN>. That is useful if a package (such as
C<venturisadf>) contains top-level directories named after different
fonts.

=item C<t> I<word1 ... wordN wordL>

includes all the files in and below all directories of the form

  word1/word2/.../wordN/.../any/dirs/.../wordL/

i.e., all the first words but the last form the prefix of the path, then
there can be an arbitrary number of subdirectories, followed by C<wordL>
as the final directory. This is primarily used in
C<00texlive.autopatterns.tlpsrc> in a custom way, but here is the one
real life example from a standard package, C<omega.tlpsrc>:

  runpattern t texmf-dist fonts omega

matches C<texmf-dist/fonts/**/omega>, where C<**> matches any number of
intervening subdirectories, e.g.:

  texmf-dist/fonts/ofm/public/omega
  texmf-dist/fonts/tfm/public/omega
  texmf-dist/fonts/type1/public/omega

=back

=head2 Special patterns

=head3 Prefix characters: C<+> and C<!>

If the C<PREFIX> contains the symbol C<!> the meaning of the pattern is
reversed, i.e., files matching this pattern are removed from the list of
included files.

The prefix C<+> means to append to the list of automatically synthesized
patterns, instead of replacing them.

The C<+> and C<!> prefixes can be combined.  This is useful to exclude
directories from the automatic pattern list.  For example,
C<graphics.tlpsrc> contains this line:

  docpattern +!d texmf-dist/doc/latex/tufte-latex/graphics

so that the subdirectory of the C<tufte-latex> package that happens to
be named "graphics" is not mistakenly included in the C<graphics>
package.

=head2 Auto-generated patterns (C<00texlive.autopatterns>)

If a given pattern section is empty or I<all> the provided patterns have
the prefix C<+> (e.g., C<+f ...>), then patterns such as the following,
listed by type, are I<automatically> added at expansion time. The list
here contains examples, rather than being definitive; the added patterns
are actually taken from C<00texlive.autopatterns.tlpsrc>. (That file
also defines any global tlpsrc variables, as described above under
L</tlpsetvar>).

=over 4

=item C<runpattern>

For category C<Package>:

  t texmf-dist I<topdir> %NAME%

where C<%NAME%> means the current package name, and I<topdir> is one of:
C<bibtex> C<context> C<dvips> C<fonts> C<makeindex> C<metafont>
C<metapost> C<mft> C<omega> C<scripts> C<tex>.

For category C<ConTeXt>:

  d texmf-dist/tex/context/third/%context-:NAME%
  d texmf-dist/metapost/context/third/%context-:NAME%
  f texmf-dist/tex/context/interface/third/*%context-:NAME%.xml

(where C<%context-:NAME%> is replaced by the package name with an initial
C<context-> is removed. E.g., if the package is called C<context-foobar>
the replacement in the above rules will be C<foobar>.)

For other categories I<no> patterns are automatically added to the 
list of C<runpattern>s.

=item C<docpattern>

for category C<TLCore>:

  t texmf-dist doc %NAME%
  f texmf-dist/doc/man/man1/%NAME%.*

for category C<Package>:

  t texmf-dist doc %NAME%
  f texmf-dist/doc/man/man1/%NAME%.*

for category C<ConTeXt>:

  d texmf-dist/doc/context/third/%context-:NAME%

=item C<srcpattern>

for category C<Package>:

  t texmf-dist source %NAME%

for category C<ConTeXt>:

  d texmf-dist/source/context/third/%context-:NAME%

(see above for the C<$NAME%> construct)

=item C<binpattern>

No C<binpattern>s are ever automatically added.

=back

=head3 Special treatment of binpatterns

The binpatterns have to deal with all the different architectures. To
ease the writing of patterns, we have the following features:

=over 4

=item Architecture expansion

Within a binpattern, the string C<${ARCH}> is automatically expanded to
all available architectures.

=item C<bat/exe/dll/texlua> for Windows

C<binpattern>s that match Windows, e.g., C<f bin/windows/foobar> or C<f
bin/${ARCH}/foobar>, also match the files C<foobar.bat>, C<foobar.cmd>,
C<foobar.dll>, C<foobar.exe>, and C<foobar.texlua>.

In addition, C<foobar.exe.manifest> and C<foobar.dll.manifest> are matched.

The above two properties allows to capture the binaries for all
architectures in one binpattern

  binpattern f bin/${ARCH}/dvips

and would get C<bin/windows/dvips.exe> into the runfiles for C<arch=windows>.

This C<bat>/C<exe>/etc. expansion I<only> works for patterns of the C<f>
type.

=item ARCHSPEC specification of a pattern

Sometimes files should be included into the list of binfiles of a
package only for some architectures, or for all but some architectures.
This can be done by specifying the list of architectures for which this
pattern should be matched after the pattern specifier using a C</>:

  binpattern f/windows tlpkg/bin/perl.exe

will include the file C<tlpkg/bin/perl.exe> only in the binfiles for
the architecture C<windows>. Another example:

  binpattern f/arch1,arch2,arch3 path/$ARCH/foo/bar

This will only try to match this pattern for arch1, arch2, and arch3.

Normally, a binpattern is matched against all possible architectures. If
you want to exclude some architectures, instead of listing all the ones
you want to include as above, you can prefix the list of architectures
with a ! and these architectures will not be tested. Example:

  binpattern f/!arch1,arch2 path/$ARCH/foo/bar

will be matched against all architectures I<except> arch1 and arch2.

=back

=head1 MEMBER ACCESS FUNCTIONS

For any of the above I<key>s a function

  $tlpsrc->key

is available, which returns the current value when called without an argument,
and sets the respective value when called with an argument.

Arguments and return values for C<name>, C<category>, C<shortdesc>,
C<longdesc>, C<catalogue> are single scalars. Arguments and return values
for C<depends>, C<executes>, and the various C<patterns> are lists.

In addition, the C<_srcfile> member refers to the filename for this
C<TLPSRC> object, if set (normally by C<from_file>).

=head1 OTHER FUNCTIONS

The following functions can be called for a C<TLPSRC> object:

=over 4

=item C<new>

The constructor C<new> returns a new C<TLPSRC> object. The arguments
to the C<new> constructor can be in the usual hash representation for
the different keys above:

  $tlpsrc = TLPSRC->new(name => "foobar",
                        shortdesc => "The foobar package");

=item C<from_file("filename")>

Reads a C<tlpsrc> file from disk.  C<filename> can either be a full path
(if it's readable, it's used), or just a package identifier such as
C<plain>.  In the latter case, the directory searched is the C<tlpsrc>
sibling of the C<TeXLive> package directory where C<TLPSRC.pm> was found.

  $tlpsrc=new TeXLive::TLPSRC;
  $tlpsrc->from_file("/path/to/the/tlpsrc/somepkg.tlpsrc");
  $tlpsrc->from_file("somepkg");

=item C<writeout>

writes the textual representation of a C<TLPSRC> object to stdout, or the
filehandle if given:

  $tlpsrc->writeout;
  $tlpsrc->writeout(\*FILEHANDLE);

=item C<make_tlpobj($tltree)>

creates a C<TLPOBJ> object from a C<TLPSRC> object and a C<TLTREE> object.
This function does the necessary work to expand the manual data and
enrich it with the content from C<$tltree> to a C<TLPOBJ> object.

=back

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
