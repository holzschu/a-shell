# $Id: TLPOBJ.pm 65965 2023-02-20 17:26:54Z karl $
# TeXLive::TLPOBJ.pm - module for using tlpobj files
# Copyright 2007-2023 Norbert Preining
# This file is licensed under the GNU General Public License version 2
# or any later version.

use strict; use warnings;

package TeXLive::TLPOBJ;

my $svnrev = '$Revision: 65965 $';
my $_modulerevision = ($svnrev =~ m/: ([0-9]+) /) ? $1 : "unknown";
sub module_revision { return $_modulerevision; }

use TeXLive::TLConfig qw($DefaultCategory $CategoriesRegexp 
                         $MetaCategoriesRegexp $InfraLocation 
                         %Compressors $DefaultCompressorFormat
                         $RelocPrefix $RelocTree);
use TeXLive::TLCrypto;
use TeXLive::TLTREE;
use TeXLive::TLUtils;

our $_tmp;
my $_containerdir;


sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    name        => $params{'name'},
    category    => defined($params{'category'}) ? $params{'category'} : $DefaultCategory,
    shortdesc   => $params{'shortdesc'},
    longdesc    => $params{'longdesc'},
    catalogue   => $params{'catalogue'},
    relocated   => $params{'relocated'},
    runfiles    => defined($params{'runfiles'}) ? $params{'runfiles'} : [],
    runsize     => $params{'runsize'},
    srcfiles    => defined($params{'srcfiles'}) ? $params{'srcfiles'} : [],
    srcsize     => $params{'srcsize'},
    docfiles    => defined($params{'docfiles'}) ? $params{'docfiles'} : [],
    docsize     => $params{'docsize'},
    executes    => defined($params{'executes'}) ? $params{'executes'} : [],
    postactions => defined($params{'postactions'}) ? $params{'postactions'} : [],
    # note that binfiles is a HASH with keys of $arch!
    binfiles    => defined($params{'binfiles'}) ? $params{'binfiles'} : {},
    binsize     => defined($params{'binsize'}) ? $params{'binsize'} : {},
    depends     => defined($params{'depends'}) ? $params{'depends'} : [],
    revision    => $params{'revision'},
    cataloguedata => defined($params{'cataloguedata'}) ? $params{'cataloguedata'} : {},
  };
  $_containerdir = $params{'containerdir'} if defined($params{'containerdir'});
  bless $self, $class;
  return $self;
}


sub copy {
  my $self = shift;
  my $bla = {};
  %$bla = %$self;
  bless $bla, "TeXLive::TLPOBJ";
  return $bla;
}


sub from_file {
  my $self = shift;
  if (@_ != 1) {
    die("TLPOBJ:from_file: Need a filename for initialization");
  }
  open(TMP,"<$_[0]") || die("Cannot open tlpobj file: $_[0]");
  $self->from_fh(\*TMP);
}

sub from_fh {
  my ($self,$fh,$multi) = @_;
  my $started = 0;
  my $lastcmd = "";
  my $arch;
  my $size;

  while (my $line = <$fh>) {
    # we do not worry about whitespace at the end of a line;
    # that would be a bug in the db creation, and it takes some
    # noticeable time to get rid of it.  So just chomp.
    chomp($line);
    
    # we call tllog only when something will be logged, to speed things up.
    # this is the inner loop bounding the time to read tlpdb.
    dddebug("reading line: >>>$line<<<\n") if ($::opt_verbosity >= 3);
    $line =~ /^#/ && next;          # skip comment lines
    if ($line =~ /^\s*$/) {
      if (!$started) { next; }
      if (defined($multi)) {
        # we may read from a tldb file
        return 1;
      } else {
        # we are reading one tldb file, nothing else allowed
        die("No empty line allowed within tlpobj files!");
      }
    }

    my ($cmd, $arg) = split(/\s+/, $line, 2);
    # first command must be name
    $started || $cmd eq 'name'
      or die("First directive needs to be 'name', not $line");

    # now the big switch, ordered by decreasing number of occurences
    if ($cmd eq '') {
      if ($lastcmd eq "runfiles" || $lastcmd eq "srcfiles") {
        push @{$self->{$lastcmd}}, $arg;
      } elsif ($lastcmd eq "docfiles") {
        my ($f, $rest) = split(' ', $arg, 2);
        push @{$self->{'docfiles'}}, $f;
        # docfiles can have tags, but the parse_line function is so
        # time intense that we try to call it only when necessary
        if (defined $rest) {
          # parse_line has problems with double quotes in double quotes
          # my @words = &TeXLive::TLUtils::parse_line('\s+', 0, $rest);
          # do manual parsing
          # this is not optimal, but since we support only two tags there
          # are not so many cases
          # Warning: need tp check the double cases first!!!
          if ($rest =~ m/^language="(.*)"\s+details="(.*)"\s*$/) {
            $self->{'docfiledata'}{$f}{'details'} = $2;
            $self->{'docfiledata'}{$f}{'language'} = $1;
          } elsif ($rest =~ m/^details="(.*)"\s+language="(.*)"\s*$/) {
            $self->{'docfiledata'}{$f}{'details'} = $1;
            $self->{'docfiledata'}{$f}{'language'} = $2;
          } elsif ($rest =~ m/^details="(.*)"\s*$/) {
            $self->{'docfiledata'}{$f}{'details'} = $1;
          } elsif ($rest =~ m/^language="(.*)"\s*$/) {
            $self->{'docfiledata'}{$f}{'language'} = $1;
          } else {
            tlwarn("$0: Unparsable tagging in TLPDB line: $line\n");
          }
        }
      } elsif ($lastcmd eq "binfiles") {
        push @{$self->{'binfiles'}{$arch}}, $arg;
      } else {
        die("Continuation of $lastcmd not allowed, please fix tlpobj: line = $line!\n");
      }
    } elsif ($cmd eq "longdesc") {
      my $desc = defined $arg ? $arg : '';
      if (defined($self->{'longdesc'})) {
        $self->{'longdesc'} .= " $desc";
      } else {
        $self->{'longdesc'} = $desc;
      }
    } elsif ($cmd =~ /^catalogue-(.+)$/o) {
      $self->{'cataloguedata'}{$1} = $arg if defined $arg;
    } elsif ($cmd =~ /^(doc|src|run)files$/o) {
      my $type = $1;
      for (split ' ', $arg) {
        my ($k, $v) = split('=', $_, 2);
        if ($k eq 'size') {
        $self->{"${type}size"} = $v;
        } else {
          die "Unknown tag: $line";
        }
      }
    } elsif ($cmd eq 'containersize' || $cmd eq 'srccontainersize'
        || $cmd eq 'doccontainersize') {
      $arg =~ /^[0-9]+$/ or die "Invalid size value: $line!";
      $self->{$cmd} = $arg;
    } elsif ($cmd eq 'containermd5' || $cmd eq 'srccontainermd5'
        || $cmd eq 'doccontainermd5') {
      $arg =~ /^[a-f0-9]{32}$/ or die "Invalid md5 value: $line!";
      $self->{$cmd} = $arg;
    } elsif ($cmd eq 'containerchecksum' || $cmd eq 'srccontainerchecksum'
        || $cmd eq 'doccontainerchecksum') {
      $arg =~ /^[a-f0-9]{$TeXLive::TLConfig::ChecksumLength}$/
        or die "Invalid checksum value: $line!";
      $self->{$cmd} = $arg;
    } elsif ($cmd eq 'name') {
      $arg =~ /^([-.\w]+)$/ or die("Invalid name: $line!");
      $self->{'name'} = $arg;
      $started && die("Cannot have two name directives: $line!");
      $started = 1;
    } elsif ($cmd eq 'category') {
      $self->{'category'} = $arg;
      if ($self->{'category'} !~ /^$CategoriesRegexp/o) {
        tlwarn("Unknown category " . $self->{'category'} . " for package "
          . $self->name . " found.\nPlease update texlive.infra.\n");
      }
    } elsif ($cmd eq 'revision') {
      $self->{'revision'} = $arg;
    } elsif ($cmd eq 'shortdesc') {
      $self->{'shortdesc'} .= defined $arg ? $arg : ' ';
    } elsif ($cmd eq 'execute' || $cmd eq 'postaction'
        || $cmd eq 'depend') {
      push @{$self->{$cmd . 's'}}, $arg if defined $arg;
    } elsif ($cmd eq 'binfiles') {
      for (split ' ', $arg) {
        my ($k, $v) = split('=', $_, 2);
        if ($k eq 'arch') {
          $arch = $v;
        } elsif ($k eq 'size') {
          $size = $v;
        } else {
          die "Unknown tag: $line";
        }
      }
      if (defined($size)) {
        $self->{'binsize'}{$arch} = $size;
      }
    } elsif ($cmd eq 'relocated') {
      ($arg eq '0' || $arg eq '1') or die "Invalid value: $line!";
      $self->{'relocated'} = $arg;
    } elsif ($cmd eq 'catalogue') {
      $self->{'catalogue'} = $arg;
    } else {
      die("Unknown directive ...$line... , please fix it!");
    }
    $lastcmd = $cmd unless $cmd eq '';
  }
  return $started;
}

sub recompute_revision {
  my ($self,$tltree, $revtlpsrc) = @_;
  my @files = $self->all_files;
  my $filemax = 0;
  $self->revision(0);
  foreach my $f (@files) {
    $filemax = $tltree->file_svn_lastrevision($f);
    $self->revision(($filemax > $self->revision) ? $filemax : $self->revision);
  }
  if (defined($revtlpsrc)) {
    if ($self->revision < $revtlpsrc) {
      $self->revision($revtlpsrc);
    }
  }
}

sub recompute_sizes {
  my ($self,$tltree) = @_;
  $self->{'docsize'} = $self->_recompute_size("doc",$tltree);
  $self->{'srcsize'} = $self->_recompute_size("src",$tltree);
  $self->{'runsize'} = $self->_recompute_size("run",$tltree);
  foreach $a ($tltree->architectures) {
    $self->{'binsize'}{$a} = $self->_recompute_size("bin",$tltree,$a);
  }
}


sub _recompute_size {
  my ($self,$type,$tltree,$arch) = @_;
  my $nrivblocks = 0;
  if ($type eq "bin") {
    my %binfiles = %{$self->{'binfiles'}};
    if (defined($binfiles{$arch})) {
      foreach my $f (@{$binfiles{$arch}}) {
        my $s = $tltree->size_of($f);
        $nrivblocks += int($s/$TeXLive::TLConfig::BlockSize);
        $nrivblocks++ if (($s%$TeXLive::TLConfig::BlockSize) > 0);
      }
    }
  } else {
    if (defined($self->{"${type}files"}) && (@{$self->{"${type}files"}})) {
      foreach my $f (@{$self->{"${type}files"}}) {
        my $s = $tltree->size_of($f);
        if (defined($s)) {
          $nrivblocks += int($s/$TeXLive::TLConfig::BlockSize);
          $nrivblocks++ if (($s%$TeXLive::TLConfig::BlockSize) > 0);
        } else {
        tlwarn("$0: (TLPOBJ::_recompute_size) size of $type $f undefined?!\n");
        }
      }
    }
  }
  return $nrivblocks;
}

sub writeout {
  my $self = shift;
  my $fd = (@_ ? $_[0] : *STDOUT);
  print $fd "name ", $self->name, "\n";
  print $fd "category ", $self->category, "\n";
  defined($self->{'revision'}) && print $fd "revision $self->{'revision'}\n";
  defined($self->{'catalogue'}) && print $fd "catalogue $self->{'catalogue'}\n";
  defined($self->{'shortdesc'}) && print $fd "shortdesc $self->{'shortdesc'}\n";
  defined($self->{'license'}) && print $fd "license $self->{'license'}\n";
  defined($self->{'relocated'}) && $self->{'relocated'} && print $fd "relocated 1\n";
  # don't want to use FileHandle.pm; see man perlform
  #format_name $fd "multilineformat";
  select((select($fd),$~ = "multilineformat")[0]);
  $fd->format_lines_per_page (99999); # no pages in this format
  if (defined($self->{'longdesc'})) {
    $_tmp = "$self->{'longdesc'}";
    write $fd;  # use that multilineformat
  }
  if (defined($self->{'depends'})) {
    foreach (sort @{$self->{'depends'}}) {
      print $fd "depend $_\n";
    }
  }
  if (defined($self->{'executes'})) {
    foreach (sort @{$self->{'executes'}}) {
      print $fd "execute $_\n";
    }
  }
  if (defined($self->{'postactions'})) {
    foreach (sort @{$self->{'postactions'}}) {
      print $fd "postaction $_\n";
    }
  }
  if (defined($self->{'containersize'})) {
    print $fd "containersize $self->{'containersize'}\n";
  }
  if (defined($self->{'containermd5'})) {
    print $fd "containermd5 $self->{'containermd5'}\n";
  }
  if (defined($self->{'containerchecksum'})) {
    print $fd "containerchecksum $self->{'containerchecksum'}\n";
  }
  if (defined($self->{'doccontainersize'})) {
    print $fd "doccontainersize $self->{'doccontainersize'}\n";
  }
  if (defined($self->{'doccontainermd5'})) {
    print $fd "doccontainermd5 $self->{'doccontainermd5'}\n";
  }
  if (defined($self->{'doccontainerchecksum'})) {
    print $fd "doccontainerchecksum $self->{'doccontainerchecksum'}\n";
  }
  if (defined($self->{'docfiles'}) && (@{$self->{'docfiles'}})) {
    print $fd "docfiles size=$self->{'docsize'}\n";
    foreach my $f (sort @{$self->{'docfiles'}}) {
      print $fd " $f";
      if (defined($self->{'docfiledata'}{$f}{'details'})) {
        my $tmp = $self->{'docfiledata'}{$f}{'details'};
        #$tmp =~ s/\"/\\\"/g;
        print $fd ' details="', $tmp, '"';
      }
      if (defined($self->{'docfiledata'}{$f}{'language'})) {
        my $tmp = $self->{'docfiledata'}{$f}{'language'};
        #$tmp =~ s/\"/\\\"/g;
        print $fd ' language="', $tmp, '"';
      }
      print $fd "\n";
    }
  }
  if (defined($self->{'srccontainersize'})) {
    print $fd "srccontainersize $self->{'srccontainersize'}\n";
  }
  if (defined($self->{'srccontainermd5'})) {
    print $fd "srccontainermd5 $self->{'srccontainermd5'}\n";
  }
  if (defined($self->{'srccontainerchecksum'})) {
    print $fd "srccontainerchecksum $self->{'srccontainerchecksum'}\n";
  }
  if (defined($self->{'srcfiles'}) && (@{$self->{'srcfiles'}})) {
    print $fd "srcfiles size=$self->{'srcsize'}\n";
    foreach (sort @{$self->{'srcfiles'}}) {
      print $fd " $_\n";
    }
  }
  if (defined($self->{'runfiles'}) && (@{$self->{'runfiles'}})) {
    print $fd "runfiles size=$self->{'runsize'}\n";
    foreach (sort @{$self->{'runfiles'}}) {
      print $fd " $_\n";
    }
  }
  foreach my $arch (sort keys %{$self->{'binfiles'}}) {
    if (@{$self->{'binfiles'}{$arch}}) {
      print $fd "binfiles arch=$arch size=", $self->{'binsize'}{$arch}, "\n";
      foreach (sort @{$self->{'binfiles'}{$arch}}) {
        print $fd " $_\n";
      }
    }
  }
  # writeout all the catalogue keys
  foreach my $k (sort keys %{$self->cataloguedata}) {
    next if $k eq "date";
    print $fd "catalogue-$k ", $self->cataloguedata->{$k}, "\n";
  }
}

sub writeout_simple {
  my $self = shift;
  my $fd = (@_ ? $_[0] : *STDOUT);
  print $fd "name ", $self->name, "\n";
  print $fd "category ", $self->category, "\n";
  if (defined($self->{'depends'})) {
    foreach (sort @{$self->{'depends'}}) {
      print $fd "depend $_\n";
    }
  }
  if (defined($self->{'executes'})) {
    foreach (sort @{$self->{'executes'}}) {
      print $fd "execute $_\n";
    }
  }
  if (defined($self->{'postactions'})) {
    foreach (sort @{$self->{'postactions'}}) {
      print $fd "postaction $_\n";
    }
  }
  if (defined($self->{'docfiles'}) && (@{$self->{'docfiles'}})) {
    print $fd "docfiles\n";
    foreach (sort @{$self->{'docfiles'}}) {
      print $fd " $_\n";
    }
  }
  if (defined($self->{'srcfiles'}) && (@{$self->{'srcfiles'}})) {
    print $fd "srcfiles\n";
    foreach (sort @{$self->{'srcfiles'}}) {
      print $fd " $_\n";
    }
  }
  if (defined($self->{'runfiles'}) && (@{$self->{'runfiles'}})) {
    print $fd "runfiles\n";
    foreach (sort @{$self->{'runfiles'}}) {
      print $fd " $_\n";
    }
  }
  foreach my $arch (sort keys %{$self->{'binfiles'}}) {
    if (@{$self->{'binfiles'}{$arch}}) {
      print $fd "binfiles arch=$arch\n";
      foreach (sort @{$self->{'binfiles'}{$arch}}) {
        print $fd " $_\n";
      }
    }
  }
}

sub as_json {
  my $self = shift;
  my %addargs = @_;
  my %foo = %{$self};
  # set the additional args
  for my $k (keys %addargs) {
    if (defined($addargs{$k})) {
      $foo{$k} = $addargs{$k};
    } else {
      delete($foo{$k});
    }
  }
  # make sure numbers are encoded as numbers
  for my $k (qw/revision runsize docsize srcsize containersize lrev rrev
                srccontainersize doccontainersize runcontainersize/) {
    $foo{$k} += 0 if exists($foo{$k});
  }
  for my $k (keys %{$foo{'binsize'}}) {
    $foo{'binsize'}{$k} += 0;
  }
  # encode boolean as boolean flags
  if (exists($foo{'relocated'})) {
    if ($foo{'relocated'}) {
      $foo{'relocated'} = TeXLive::TLUtils::True();
    } else {
      $foo{'relocated'} = TeXLive::TLUtils::False();
    }
  }
  # adjust the docfiles entry to the specification in JSON-formats
  my @docf = $self->docfiles;
  my $dfd = $self->docfiledata;
  my @newdocf;
  for my $f ($self->docfiles) {
    my %newd;
    $newd{'file'} = $f;
    if (defined($dfd->{$f})) {
      # "details" and "language" keys now, but more could be added any time.
      # (Such new keys would have to be added in update_from_catalogue.)
      for my $k (keys %{$dfd->{$f}}) {
        $newd{$k} = $dfd->{$f}->{$k};
      }
    }
    push @newdocf, \%newd;
  }
  $foo{'docfiles'} = [ @newdocf ];
  delete($foo{'docfiledata'});
  #
  my $utf8_encoded_json_text = TeXLive::TLUtils::encode_json(\%foo);
  return $utf8_encoded_json_text;
}


sub cancel_reloc_prefix {
  my $self = shift;
  my @docfiles = $self->docfiles;
  for (@docfiles) { s:^$RelocPrefix/::; }
  $self->docfiles(@docfiles);
  my @runfiles = $self->runfiles;
  for (@runfiles) { s:^$RelocPrefix/::; }
  $self->runfiles(@runfiles);
  my @srcfiles = $self->srcfiles;
  for (@srcfiles) { s:^$RelocPrefix/::; }
  $self->srcfiles(@srcfiles);
  # if there are bin files they have definitely NOT the
  # texmf-dist prefix, so we cannot cancel it anyway
}

sub replace_reloc_prefix {
  my $self = shift;
  my @docfiles = $self->docfiles;
  for (@docfiles) { s:^$RelocPrefix/:$RelocTree/:; }
  $self->docfiles(@docfiles);
  my @runfiles = $self->runfiles;
  for (@runfiles) { s:^$RelocPrefix/:$RelocTree/:; }
  $self->runfiles(@runfiles);
  my @srcfiles = $self->srcfiles;
  for (@srcfiles) { s:^$RelocPrefix/:$RelocTree/:; }
  $self->srcfiles(@srcfiles);
  # docfiledata needs to be adapted too
  my $data = $self->docfiledata;
  my %newdata;
  while (my ($k, $v) = each %$data) {
    $k =~ s:^$RelocPrefix/:$RelocTree/:;
    $newdata{$k} = $v;
  }
  $self->docfiledata(%newdata);
  # if there are bin files they have definitely NOT the
  # texmf-dist prefix, so no reloc to replace
}

sub cancel_common_texmf_tree {
  my $self = shift;
  my @docfiles = $self->docfiles;
  for (@docfiles) { s:^$RelocTree/:$RelocPrefix/:; }
  $self->docfiles(@docfiles);
  my @runfiles = $self->runfiles;
  for (@runfiles) { s:^$RelocTree/:$RelocPrefix/:; }
  $self->runfiles(@runfiles);
  my @srcfiles = $self->srcfiles;
  for (@srcfiles) { s:^$RelocTree/:$RelocPrefix/:; }
  $self->srcfiles(@srcfiles);
  # docfiledata needs to be adapted too
  my $data = $self->docfiledata;
  my %newdata;
  while (my ($k, $v) = each %$data) {
    $k =~ s:^$RelocTree/:$RelocPrefix/:;
    $newdata{$k} = $v;
  }
  $self->docfiledata(%newdata);
  # if there are bin files they have definitely NOT the
  # texmf-dist prefix, so we cannot cancel it anyway
}

sub common_texmf_tree {
  my $self = shift;
  my $tltree;
  my $dd = 0;
  my @files = $self->all_files;
  foreach ($self->all_files) {
    my $tmp;
    ($tmp) = split m@/@;
    if (defined($tltree) && ($tltree ne $tmp)) {
      return;
    } else {
      $tltree = $tmp;
    }
  }
  # if there are no files then it is by default relocatable, so 
  # return the right tree
  if (!@files) {
    $tltree = $RelocTree;
  }
  return $tltree;
}


sub make_container {
  my ($self, $type, $instroot, %other) = @_;
  my $destdir = ($other{'destdir'} || undef);
  my $containername = ($other{'containername'} || undef);
  my $relative = ($other{'relative'} || undef);
  my $user = ($other{'user'} || undef);
  my $copy_instead_of_link = ($other{'copy_instead_of_link'} || undef);
  if (!($type eq 'tar' ||
        TeXLive::TLUtils::member($type, @{$::progs{'working_compressors'}}))) {
    tlwarn "$0: TLPOBJ supports @{$::progs{'working_compressors'}} and tar containers, not $type\n";
    tlwarn "$0: falling back to $DefaultCompressorFormat as container type!\n";
    $type = $DefaultCompressorFormat;
  }

  if (!defined($containername)) {
    $containername = $self->name;
  }
  my @files = $self->all_files;
  my $compresscmd;
  my $tlpobjdir = "$InfraLocation/tlpobj";
  @files = TeXLive::TLUtils::sort_uniq(@files);
  # we do relative packages ONLY if the files do NOT span multiple
  # texmf trees. check this here
  my $tltree;
  if ($relative) {
    $tltree = $self->common_texmf_tree;
    if (!defined($tltree)) {
      die ("$0: package $containername spans multiple trees, "
           . "relative generation not allowed");
    }
    if ($tltree ne $RelocTree) {
      die ("$0: building $containername container relocatable but the common"
           . " prefix is not $RelocTree");
    } 
    s,^$RelocTree/,, foreach @files;
  }
  # load Cwd only if necessary ...
  require Cwd;
  my $cwd = &Cwd::getcwd;
  if ("$destdir" !~ m@^(.:)?[/\\]@) {
    # we have an relative containerdir, so we have to make it absolute
    $destdir = "$cwd/$destdir";
  }
  &TeXLive::TLUtils::mkdirhier("$destdir");
  chdir($instroot);
  # in the relative case we have to chdir to the respective tltree
  # and put the tlpobj into the root!
  my $removetlpkgdir = 0;
  if ($relative) {
    chdir("./$tltree");
    # in the relocatable case we will probably create the tlpkg dir
    # in texmf-dist/tlpkg and want to remove it afterwards.
    $removetlpkgdir = 1;
    # we don't need to change the $tlpobjdir because we put it in
    # all cases into tlpkg/tlpobj
    #$tlpobjdir = "./tlpkg/tlpobj";
  }
  # we add the .tlpobj into the .tlpobj directory
  my $removetlpobjdir = 0;
  if (! -d "$tlpobjdir") {
    &TeXLive::TLUtils::mkdirhier("$tlpobjdir");
    $removetlpobjdir = 1;
  }
  open(TMP,">$tlpobjdir/$self->{'name'}.tlpobj") 
  || die "$0: create($tlpobjdir/$self->{'name'}.tlpobj) failed: $!";
  # when we do relative we have to cancel the prefix before writing out
  my $selfcopy = $self->copy;
  if ($relative) {
    $selfcopy->cancel_common_texmf_tree;
    $selfcopy->relocated($relative);
  }
  $selfcopy->writeout(\*TMP);
  close(TMP);
  push(@files, "$tlpobjdir/$self->{'name'}.tlpobj");
  # versioned containers
  my $tarname = "$containername.r" . $self->revision . ".tar";
  my $unversionedtar;
  $unversionedtar = "$containername.tar" if (! $user);

  # start the fun
  my $tar = $::progs{'tar'};
  if (!defined($tar)) {
    tlwarn("$0: programs not set up, trying \"tar\".\n");
    $tar = "tar";
  }

  $containername = $tarname;

  # Here we need to distinguish between making the master containers for
  # tlnet (where we can assume GNU tar) and making backups on a user's
  # machine (where we can assume nothing).  We determine this by whether
  # there's a revision suffix in the container name.
  # 
  # For the master containers, we want to set the owner/group, exclude
  # .svn directories, and force ustar format.  This last is for the sake
  # of packages such as pgf which have filenames long enough that they
  # overflow standard tar format and result in special things being
  # done.  We don't want the GNU-specific special things.
  #
  # We use versioned containers throughout, user mode is determined by
  # argument.
  my $is_user_container = $user;
  my @attrs
    = $is_user_container
      ? ()
      : ( "--owner", "0",  "--group", "0",  "--exclude", ".svn",
          "--format", "ustar" );
  my @cmdline = ($tar, "-cf", "$destdir/$tarname", @attrs);
  
  # Get list of files and symlinks to back up.  Nothing else should be
  # in the list.
  my @files_to_backup = ();
  for my $f (@files) {
    if (-f $f || -l $f) {
      push(@files_to_backup, $f);
    } elsif (! -e $f) {
      tlwarn("$0: (make_container $containername) $f does not exist\n");
    } else {
      tlwarn("$0: (make_container $containername) $f not file or symlink\n");
      if (! wndws()) {
        tlwarn("$0:   ", `ls -l $f 2>&1`);
      }
    }
  }
  
  my $tartempfile = "";
  if (wndws()) {
    # Since we provide our own (GNU) tar on Windows, we know it has -T.
    my $tmpdir = TeXLive::TLUtils::tl_tmpdir();
    $tartempfile = "$tmpdir/mc$$";
    open(TMP, ">$tartempfile") || die "open(>$tartempfile) failed: $!";
    print TMP map { "$_\n" } @files_to_backup;
    close(TMP) || warn "close(>$tartempfile) failed: $!";
    push(@cmdline, "-T", $tartempfile);
  } else {
    # For Unix, we pass all the files on the command line, because there
    # is no portable (across different platforms and different tars)  way
    # to pass them on stdin.  Unfortunately, this can be too lengthy of
    # a command line -- our biggest package is tex4ht, which needs about
    # 200k.  CentOS 5.2, at least, starts complaining around 140k.
    # 
    # Therefore, if the command is likely to be too long, we call
    # our collapse_dirs routine; in practice, this eliminates
    # essentially all the individual files, leaving just a few
    # directories, which is no problem.  (For example, tex4ht collapses
    # down to five directories and one file.)
    # 
    # Although in principle we could do this in all cases, collapse_dirs
    # isn't the most thoroughly tested function in the world.  It seems
    # safer to only do it in the (few) potentially problematic cases.
    # 
    if (length ("@files_to_backup") > 50000) {
      @files_to_backup = TeXLive::TLUtils::collapse_dirs(@files_to_backup);
      # A complication, as always.  collapse_dirs returns absolute paths.
      # We want to change them back to relative so that the backup tar
      # has the same structure.
      # In relative mode we have to remove the texmf-dist prefix, too.
      s,^$instroot/,, foreach @files_to_backup;
      if ($relative) {
        s,^$RelocTree/,, foreach @files_to_backup;
      }
    }
    push(@cmdline, @files_to_backup);
  }

  # Run tar. Unlink both here in case the container is also plain tar.
  unlink("$destdir/$tarname");
  unlink("$destdir/$unversionedtar") if (! $user);
  unlink("$destdir/$containername");
  xsystem(@cmdline);

  if ($type ne 'tar') {
    # compress it
    my $compressor = $::progs{$type};
    if (!defined($compressor)) {
      # fall back to $type as compressor, but that shouldn't happen
      tlwarn("$0: programs not set up, trying \"$type\".\n");
      $compressor = $type;
    }
    my @compressorargs = @{$Compressors{$type}{'compress_args'}};
    my $compressorextension = $Compressors{$type}{'extension'};
    $containername = "$tarname.$compressorextension";
    debug("selected compressor: $compressor with @compressorargs, "
          . "on $destdir/$tarname\n");
  
    # compress it.
    if (-r "$destdir/$tarname") {
      # system return 0 on success
      if (system($compressor, @compressorargs, "$destdir/$tarname")) {
        tlwarn("$0: Couldn't compress $destdir/$tarname\n");
        return (0,0, "");
      }
      # make sure we remove the original tar since old lz4 versions
      # cannot automatically delete it.
      # We remove the tar file only when the compressed file was
      # correctly created, something that should only happen in the
      # most strange cases.
      unlink("$destdir/$tarname")
        if ((-r "$destdir/$tarname") && (-r "$destdir/$containername"));
      # in case of system containers also create the links to the 
      # versioned containers
      if (! $user) {
        my $linkname = "$destdir/$unversionedtar.$compressorextension";
        unlink($linkname) if (-r $linkname);
        if ($copy_instead_of_link) {
          TeXLive::TLUtils::copy("-f", "$destdir/$containername", $linkname)
        } else {
          if (!symlink($containername, $linkname)) {
            tlwarn("$0: Couldn't generate link $linkname -> $containername?\n");
          }
        }
      }
    } else {
      tlwarn("$0: Couldn't find $destdir/$tarname to run $compressor\n");
      return (0, 0, "");
    }
  }
  
  # compute the size.
  if (! -r "$destdir/$containername") {
    tlwarn ("$0: Couldn't find $destdir/$containername\n");
    return (0, 0, "");
  }
  my $size = (stat "$destdir/$containername") [7];
  #
  # if we are creating a system container, or there is a way to
  # compute the checksums, do it
  my $checksum = "";
  if (!$is_user_container || $::checksum_method) {
    $checksum = TeXLive::TLCrypto::tlchecksum("$destdir/$containername");
  }
  
  # cleaning up
  unlink("$tlpobjdir/$self->{'name'}.tlpobj");
  unlink($tartempfile) if $tartempfile;
  rmdir($tlpobjdir) if $removetlpobjdir;
  rmdir($InfraLocation) if $removetlpkgdir;
  xchdir($cwd);

  debug(" done $containername, size $size, csum $checksum\n");
  return ($size, $checksum, "$destdir/$containername");
}



sub is_arch_dependent {
  my $self = shift;
  if (keys %{$self->{'binfiles'}}) {
    return 1;
  } else {
    return 0;
  }
}

# computes the total size of a package
# if no arguments are given this is
#   docsize + runsize + srcsize + max of binsize
sub total_size {
  my ($self,@archs) = @_;
  my $ret = $self->docsize + $self->runsize + $self->srcsize;
  if ($self->is_arch_dependent) {
    my $max = 0;
    my %foo = %{$self->binsize};
    foreach my $k (keys %foo) {
      $max = $foo{$k} if ($foo{$k} > $max);
    }
    $ret += $max;
  }
  return($ret);
}


# update_from_catalogue($tlc)
# Update the current TLPOBJ object with the information from the
# corresponding entry in C<$tlc->entries>.
#
sub update_from_catalogue {
  my ($self, $tlc) = @_;
  my $tlcname = $self->name;
  if (defined($self->catalogue)) {
    $tlcname = $self->catalogue;
  } elsif ($tlcname =~ m/^bin-(.*)$/) {
    if (!defined($tlc->entries->{$tlcname})) {
      $tlcname = $1;
    }
  }
  $tlcname = lc($tlcname);
  if (defined($tlc->entries->{$tlcname})) {
    my $entry = $tlc->entries->{$tlcname};
    # Record the id of the catalogue entry if it's found.
    if ($entry->entry->{'id'} ne $tlcname) {
      $self->catalogue($entry->entry->{'id'});
    }
    if (defined($entry->license)) {
      $self->cataloguedata->{'license'} ||= $entry->license;
    }
    if (defined($entry->version) && $entry->version ne "") {
      $self->cataloguedata->{'version'} ||= $entry->version;
    }
    if (defined($entry->ctan) && $entry->ctan ne "") {
      $self->cataloguedata->{'ctan'} ||= $entry->ctan;
    }
    # TODO TODO TODO
    # we should rewrite the also fields to TeX Live package names ...
    # for now these are CTAN package names!
    # warning, we expect that cataloguedata entries are strings, 
    # so stringify these lists
    if (@{$entry->also}) {
      $self->cataloguedata->{'also'} ||= "@{$entry->also}";
    }
    if (@{$entry->alias}) {
      $self->cataloguedata->{'alias'} ||= "@{$entry->alias}";
    }
    if (@{$entry->topics}) {
      $self->cataloguedata->{'topics'} ||= "@{$entry->topics}";
    }
    if (%{$entry->contact}) {
      for my $k (keys %{$entry->contact}) {
        $self->cataloguedata->{"contact-$k"} ||= $entry->contact->{$k};
      }
    }
    #if (defined($entry->texlive)) {
    # $self->cataloguedata->{'texlive'} = $entry->texlive;
    #}
    #if (defined($entry->miktex)) {
    #  $self->cataloguedata->{'miktex'} = $entry->miktex;
    #}
    if (defined($entry->caption) && $entry->caption ne "") {
      $self->{'shortdesc'} = $entry->caption unless $self->{'shortdesc'};
    }
    if (defined($entry->description) && $entry->description ne "") {
      $self->{'longdesc'} = $entry->description unless $self->{'longdesc'};
    }
    #
    # we need to do the following:
    # - take the href entry for a documentation file entry in the TC
    # - remove the 'ctan:' prefix
    # - remove the <ctan path='...'> part
    # - match the rest against all docfiles in an intelligent way
    #
    # Example:
    # juramisc.xml contains:
    # <documentation details='Package documentation' language='de'
    #   href='ctan:/macros/latex/contrib/juramisc/doc/jmgerdoc.pdf'/>
    # <ctan path='/macros/latex/contrib/juramisc'/>
    my @tcdocfiles = keys %{$entry->docs};  # Catalogue doc files.
    my %tcdocfilebasenames;                 # basenames of those, as we go.
    my @tlpdocfiles = $self->docfiles;      # TL doc files.
    foreach my $tcdocfile (sort @tcdocfiles) {  # sort so shortest first
      #warn "looking at tcdocfile $tcdocfile\n";
      my $tcdocfilebasename = $tcdocfile;
      $tcdocfilebasename =~ s/^ctan://;  # remove ctan: prefix
      $tcdocfilebasename =~ s,.*/,,;     # remove all but the base file name
      #warn "  got basename $tcdocfilebasename\n";
      #
      # If we've already seen this basename, skip.  This is for the sake
      # of README files, which can exist in different directories but
      # get renamed into different files in TL for various annoying reasons;
      # e.g., ibygrk, rsfs, songbook.  In these cases, it turns out we
      # always prefer the first entry (top-level README).
      next if exists $tcdocfilebasenames{$tcdocfilebasename};
      $tcdocfilebasenames{$tcdocfilebasename} = 1;
      #
      foreach my $tlpdocfile (@tlpdocfiles) {
        #warn "considering merge into tlpdocfile $tlpdocfile\n";
        if ($tlpdocfile =~ m,/$tcdocfilebasename$,) {
          # update the language/detail tags from Catalogue if present.
          if (defined($entry->docs->{$tcdocfile}{'details'})) {
            my $tmp = $entry->docs->{$tcdocfile}{'details'};
            #warn "merging details for $tcdocfile: $tmp\n";
            # remove all embedded quotes, they are just a pain
            $tmp =~ s/"//g;
            $self->{'docfiledata'}{$tlpdocfile}{'details'} = $tmp;
          }
          if (defined($entry->docs->{$tcdocfile}{'language'})) {
            my $tmp = $entry->docs->{$tcdocfile}{'language'};
            #warn "merging lang for $tcdocfile: $tmp\n";
            $self->{'docfiledata'}{$tlpdocfile}{'language'} = $tmp;
          }
        }
      }
    }
  }
}

sub is_meta_package {
  my $self = shift;
  if ($self->category =~ /^$MetaCategoriesRegexp$/) {
    return 1;
  }
  return 0;
}

sub docfiles_package {
  my $self = shift;
  if (not($self->docfiles)) { return ; }
  my $tlp = new TeXLive::TLPOBJ;
  $tlp->name($self->name . ".doc");
  $tlp->shortdesc("doc files of " . $self->name);
  $tlp->revision($self->revision);
  $tlp->category($self->category);
  $tlp->add_docfiles($self->docfiles);
  $tlp->docsize($self->docsize);
  # $self->clear_docfiles();
  # $self->docsize(0);
  return($tlp);
}

sub srcfiles_package {
  my $self = shift;
  if (not($self->srcfiles)) { return ; }
  my $tlp = new TeXLive::TLPOBJ;
  $tlp->name($self->name . ".source");
  $tlp->shortdesc("source files of " . $self->name);
  $tlp->revision($self->revision);
  $tlp->category($self->category);
  $tlp->add_srcfiles($self->srcfiles);
  $tlp->srcsize($self->srcsize);
  # $self->clear_srcfiles();
  # $self->srcsize(0);
  return($tlp);
}

sub split_bin_package {
  my $self = shift;
  my %binf = %{$self->binfiles};
  my @retlist;
  foreach $a (keys(%binf)) {
    my $tlp = new TeXLive::TLPOBJ;
    $tlp->name($self->name . ".$a");
    $tlp->shortdesc("$a files of " . $self->name);
    $tlp->revision($self->revision);
    $tlp->category($self->category);
    $tlp->add_binfiles($a,@{$binf{$a}});
    $tlp->binsize( $a => $self->binsize->{$a} );
    push @retlist, $tlp;
  }
  if (keys(%binf)) {
    push @{$self->{'depends'}}, $self->name . ".ARCH";
  }
  $self->clear_binfiles();
  return(@retlist);
}


# Helpers.
#
sub add_files {
  my ($self,$type,@files) = @_;
  die("Cannot use add_files for binfiles, we need that arch!")
    if ($type eq "bin");
  &TeXLive::TLUtils::push_uniq(\@{ $self->{"${type}files"} }, @files);
}

sub remove_files {
  my ($self,$type,@files) = @_;
  die("Cannot use remove_files for binfiles, we need that arch!")
    if ($type eq "bin");
  my @finalfiles;
  foreach my $f (@{$self->{"${type}files"}}) {
    if (not(&TeXLive::TLUtils::member($f,@files))) {
      push @finalfiles,$f;
    }
  }
  $self->{"${type}files"} = [ @finalfiles ];
}

sub contains_file {
  my ($self,$fn) = @_;
  # if the filename already contains a / do not add it at the beginning
  my $ret = "";
  if ($fn =~ m!/!) {
    return(grep(m!$fn$!, $self->all_files));
  } else {
    return(grep(m!(^|/)$fn$!,$self->all_files));
  }
}

sub all_files {
  my ($self) = shift;
  my @ret = ();

  push (@ret, $self->docfiles);
  push (@ret, $self->runfiles);
  push (@ret, $self->srcfiles);
  push (@ret, $self->allbinfiles);

  return @ret;
}

sub allbinfiles {
  my $self = shift;
  my @ret = ();
  my %binfiles = %{$self->binfiles};

  foreach my $arch (keys %binfiles) {
    push (@ret, @{$binfiles{$arch}});
  }

  return @ret;
}

sub format_definitions {
  my $self = shift;
  my $pkg = $self->name;
  my @ret;
  for my $e ($self->executes) {
    if ($e =~ m/AddFormat\s+(.*)\s*/) {
      my %r = TeXLive::TLUtils::parse_AddFormat_line("$1");
      if (defined($r{"error"})) {
        die "$r{'error'}, package $pkg, execute $e";
      }
      push @ret, \%r;
    }
  }
  return @ret;
}

#
# execute stuff
#
sub fmtutil_cnf_lines {
  my $obj = shift;
  my @disabled = @_;
  my @fmtlines = ();
  my $first = 1;
  my $pkg = $obj->name;
  foreach my $e ($obj->executes) {
    if ($e =~ m/AddFormat\s+(.*)\s*/) {
      my %r = TeXLive::TLUtils::parse_AddFormat_line("$1");
      if (defined($r{"error"})) {
        die "$r{'error'}, package $pkg, execute $e";
      }
      if ($first) {
        push @fmtlines, "#\n# from $pkg:\n";
        $first = 0;
      }
      my $mode = ($r{"mode"} ? "" : "#! ");
      $mode = "#! " if TeXLive::TLUtils::member ($r{'name'}, @disabled);
      push @fmtlines, "$mode$r{'name'} $r{'engine'} $r{'patterns'} $r{'options'}\n";
    }
  }
  return @fmtlines;
}


sub updmap_cfg_lines {
  my $obj = shift;
  my @disabled = @_;
  my %maps;
  foreach my $e ($obj->executes) {
    if ($e =~ m/addMap (.*)$/) {
      $maps{$1} = 1;
    } elsif ($e =~ m/addMixedMap (.*)$/) {
      $maps{$1} = 2;
    } elsif ($e =~ m/addKanjiMap (.*)$/) {
      $maps{$1} = 3;
    }
    # others are ignored here
  }
  my @updmaplines;
  foreach (sort keys %maps) {
    next if TeXLive::TLUtils::member($_, @disabled);
    if ($maps{$_} == 1) {
      push @updmaplines, "Map $_\n";
    } elsif ($maps{$_} == 2) {
      push @updmaplines, "MixedMap $_\n";
    } elsif ($maps{$_} == 3) {
      push @updmaplines, "KanjiMap $_\n";
    } else {
      tlerror("Should not happen!\n");
    }
  }
  return(@updmaplines);
}


our @disabled; # global, should handle differently ...

sub language_dat_lines {
  my $self = shift;
  local @disabled = @_;  # we use @disabled in the nested sub
  my @lines = $self->_parse_hyphen_execute(\&make_dat_lines, 'dat');
  return @lines;

  sub make_dat_lines {
    my ($name, $lhm, $rhm, $file, $syn) = @_;
    my @ret;
    return if TeXLive::TLUtils::member($name, @disabled);
    push @ret, "$name $file\n";
    foreach (@$syn) {
      push @ret, "=$_\n";
    }
    return @ret;
  }
}


sub language_def_lines {
  my $self = shift;
  local @disabled = @_;  # we use @disabled in the nested sub
  my @lines = $self->_parse_hyphen_execute(\&make_def_lines, 'def');
  return @lines;

  sub make_def_lines {
    my ($name, $lhm, $rhm, $file, $syn) = @_;
    return if TeXLive::TLUtils::member($name, @disabled);
    my $exc = "";
    my @ret;
    push @ret, "\\addlanguage\{$name\}\{$file\}\{$exc\}\{$lhm\}\{$rhm\}\n";
    foreach (@$syn) {
      # synonyms in language.def ???
      push @ret, "\\addlanguage\{$_\}\{$file\}\{$exc\}\{$lhm\}\{$rhm\}\n";
      #debug("Ignoring synonym $_ for $name when creating language.def\n");
    }
    return @ret;
  }
}


sub language_lua_lines {
  my $self = shift;
  local @disabled = @_;  # we use @disabled in the nested sub
  my @lines = $self->_parse_hyphen_execute(\&make_lua_lines, 'lua', '--');
  return @lines;

  sub make_lua_lines {
    my ($name, $lhm, $rhm, $file, $syn, $patt, $hyph, $special) = @_;
    return if TeXLive::TLUtils::member($name, @disabled);
    my @syn = (@$syn); # avoid modifying the original
    map { $_ = "'$_'" } @syn;
    my @ret;
    push @ret, "['$name'] = {", "\tloader = '$file',",
               "\tlefthyphenmin = $lhm,", "\trighthyphenmin = $rhm,",
               "\tsynonyms = { " . join(', ', @syn) . " },";
    push @ret, "\tpatterns = '$patt'," if defined $patt;
    push @ret, "\thyphenation = '$hyph'," if defined $hyph;
    push @ret, "\tspecial = '$special'," if defined $special;
    push @ret, '},';
    map { $_ = "\t$_\n" } @ret;
    return @ret;
  }
}


sub _parse_hyphen_execute {
  my ($obj, $coderef, $db, $cc) = @_;
  $cc ||= '%'; # default comment char
  my @langlines = ();
  my $pkg = $obj->name;
  my $first = 1;
  foreach my $e ($obj->executes) {
    if ($e =~ m/AddHyphen\s+(.*)\s*/) {
      my %r = TeXLive::TLUtils::parse_AddHyphen_line("$1");
      if (defined($r{"error"})) {
        die "$r{'error'}, package $pkg, execute $e";
      }
      if (not TeXLive::TLUtils::member($db, @{$r{"databases"}})) {
        next;
      }
      if ($first) {
        push @langlines, "$cc from $pkg:\n";
        $first = 0;
      }
      if ($r{"comment"}) {
          push @langlines, "$cc $r{comment}\n";
      }
      my @foo = &$coderef ($r{"name"}, $r{"lefthyphenmin"},
                           $r{"righthyphenmin"}, $r{"file"}, $r{"synonyms"},
                           $r{"file_patterns"}, $r{"file_exceptions"},
                           $r{"luaspecial"});
      push @langlines, @foo;
    }
  }
  return @langlines;
}



# member access functions
#
sub _set_get_array_value {
  my $self = shift;
  my $key = shift;
  if (@_) { 
    if (defined($_[0])) {
      $self->{$key} = [ @_ ];
    } else {
      $self->{$key} = [ ];
    }
  }
  return @{ $self->{$key} };
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
sub revision {
  my $self = shift;
  if (@_) { $self->{'revision'} = shift }
  return $self->{'revision'};
}
sub relocated {
  my $self = shift;
  if (@_) { $self->{'relocated'} = shift }
  return ($self->{'relocated'} ? 1 : 0);
}
sub catalogue {
  my $self = shift;
  if (@_) { $self->{'catalogue'} = shift }
  return $self->{'catalogue'};
}
sub srcfiles {
  _set_get_array_value(shift, "srcfiles", @_);
}
sub containersize {
  my $self = shift;
  if (@_) { $self->{'containersize'} = shift }
  return ( defined($self->{'containersize'}) ? $self->{'containersize'} : -1 );
}
sub srccontainersize {
  my $self = shift;
  if (@_) { $self->{'srccontainersize'} = shift }
  return ( defined($self->{'srccontainersize'}) ? $self->{'srccontainersize'} : -1 );
}
sub doccontainersize {
  my $self = shift;
  if (@_) { $self->{'doccontainersize'} = shift }
  return ( defined($self->{'doccontainersize'}) ? $self->{'doccontainersize'} : -1 );
}
sub containermd5 {
  my $self = shift;
  if (@_) { $self->{'containermd5'} = shift }
  if (defined($self->{'containermd5'})) {
    return ($self->{'containermd5'});
  } else {
    tlwarn("TLPOBJ: MD5 sums are no longer supported, please adapt your code!\n");
    return ("");
  }
}
sub srccontainermd5 {
  my $self = shift;
  if (@_) { $self->{'srccontainermd5'} = shift }
  if (defined($self->{'srccontainermd5'})) {
    return ($self->{'srccontainermd5'});
  } else {
    tlwarn("TLPOBJ: MD5 sums are no longer supported, please adapt your code!\n");
    return ("");
  }
}
sub doccontainermd5 {
  my $self = shift;
  if (@_) { $self->{'doccontainermd5'} = shift }
  if (defined($self->{'doccontainermd5'})) {
    return ($self->{'doccontainermd5'});
  } else {
    tlwarn("TLPOBJ: MD5 sums are no longer supported, please adapt your code!\n");
    return ("");
  }
}
sub containerchecksum {
  my $self = shift;
  if (@_) { $self->{'containerchecksum'} = shift }
  return ( defined($self->{'containerchecksum'}) ? $self->{'containerchecksum'} : "" );
}
sub srccontainerchecksum {
  my $self = shift;
  if (@_) { $self->{'srccontainerchecksum'} = shift }
  return ( defined($self->{'srccontainerchecksum'}) ? $self->{'srccontainerchecksum'} : "" );
}
sub doccontainerchecksum {
  my $self = shift;
  if (@_) { $self->{'doccontainerchecksum'} = shift }
  return ( defined($self->{'doccontainerchecksum'}) ? $self->{'doccontainerchecksum'} : "" );
}
sub srcsize {
  my $self = shift;
  if (@_) { $self->{'srcsize'} = shift }
  return ( defined($self->{'srcsize'}) ? $self->{'srcsize'} : 0 );
}
sub clear_srcfiles {
  my $self = shift;
  $self->{'srcfiles'} = [ ] ;
}
sub add_srcfiles {
  my ($self,@files) = @_;
  $self->add_files("src",@files);
}
sub remove_srcfiles {
  my ($self,@files) = @_;
  $self->remove_files("src",@files);
}
sub docfiles {
  _set_get_array_value(shift, "docfiles", @_);
}
sub clear_docfiles {
  my $self = shift;
  $self->{'docfiles'} = [ ] ;
}
sub docsize {
  my $self = shift;
  if (@_) { $self->{'docsize'} = shift }
  return ( defined($self->{'docsize'}) ? $self->{'docsize'} : 0 );
}
sub add_docfiles {
  my ($self,@files) = @_;
  $self->add_files("doc",@files);
}
sub remove_docfiles {
  my ($self,@files) = @_;
  $self->remove_files("doc",@files);
}
sub docfiledata {
  my $self = shift;
  my %newfiles = @_;
  if (@_) { $self->{'docfiledata'} = \%newfiles }
  return $self->{'docfiledata'};
}
sub binfiles {
  my $self = shift;
  my %newfiles = @_;
  if (@_) { $self->{'binfiles'} = \%newfiles }
  return $self->{'binfiles'};
}
sub clear_binfiles {
  my $self = shift;
  $self->{'binfiles'} = { };
}
sub binsize {
  my $self = shift;
  my %newsizes = @_;
  if (@_) { $self->{'binsize'} = \%newsizes }
  return $self->{'binsize'};
}
sub add_binfiles {
  my ($self,$arch,@files) = @_;
  &TeXLive::TLUtils::push_uniq(\@{ $self->{'binfiles'}{$arch} }, @files);
}
sub remove_binfiles {
  my ($self,$arch,@files) = @_;
  my @finalfiles;
  foreach my $f (@{$self->{'binfiles'}{$arch}}) {
    if (not(&TeXLive::TLUtils::member($f,@files))) {
      push @finalfiles,$f;
    }
  }
  $self->{'binfiles'}{$arch} = [ @finalfiles ];
}
sub runfiles {
  _set_get_array_value(shift, "runfiles", @_);
}
sub clear_runfiles {
  my $self = shift;
  $self->{'runfiles'} = [ ] ;
}
sub runsize {
  my $self = shift;
  if (@_) { $self->{'runsize'} = shift }
  return ( defined($self->{'runsize'}) ? $self->{'runsize'} : 0 );
}
sub add_runfiles {
  my ($self,@files) = @_;
  $self->add_files("run",@files);
}
sub remove_runfiles {
  my ($self,@files) = @_;
  $self->remove_files("run",@files);
}
sub depends {
  _set_get_array_value(shift, "depends", @_);
}
sub executes {
  _set_get_array_value(shift, "executes", @_);
}
sub postactions {
  _set_get_array_value(shift, "postactions", @_);
}
sub containerdir {
  my @self = shift;
  if (@_) { $_containerdir = $_[0] }
  return $_containerdir;
}
sub cataloguedata {
  my $self = shift;
  my %ct = @_;
  if (@_) { $self->{'cataloguedata'} = \%ct }
  return $self->{'cataloguedata'};
}

$: = " \n"; # don't break at -
format multilineformat =
longdesc ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<~~
$_tmp
.

1;
__END__


=head1 NAME

C<TeXLive::TLPOBJ> -- TeX Live Package Object (C<.tlpobj>) module

=head1 SYNOPSIS

  use TeXLive::TLPOBJ;

  my $tlpobj = TeXLive::TLPOBJ->new(name => "foobar");

=head1 DESCRIPTION

The L<TeXLive::TLPOBJ> module provide access to TeX Live Package Object
(C<.tlpobj>) files, which describe a self-contained TL package.

=head1 FILE SPECIFICATION

See L<TeXLive::TLPSRC> documentation for the general syntax and
specification. The differences are:

=over 4

=item The various C<*pattern> keys are invalid.

=item Instead, there are respective C<*files> keys described below.
All the C<*files> keys are followed by a list of files in the given
category, one per line, each line I<indented> by one space.

=item Several new keys beginning with C<catalogue-> specify information
automatically taken from the TeX Catalogue.

=item A new key C<revision> is defined (automatically computed),
which specifies the maximum of all the last-changed revisions of files
contained in the package, plus possible other changes. By default,
Catalogue-only changes do not change the revision.

=item A new key C<relocated>, either 0 or 1, which indicates that this
packages has been relocated, i.e., in the containers the initial
C<texmf-dist> directory has been stripped off and replaced with static
string C<RELOC>.

=back

=over 4

=item C<srcfiles>, C<runfiles>, C<binfiles>, C<docfiles>
each of these items contains addition the sum of sizes of the single
files (in units of C<TeXLive::TLConfig::BlockSize> blocks, currently 4k).

  srcfiles size=NNNNNN
  runfiles size=NNNNNN

=item C<docfiles>

The docfiles line itself is similar to the C<srcfiles> and C<runfiles> lines
above:

  docfiles size=NNNNNN

But the lines listing the files are allowed to have additional tags,
(which in practice come from the TeX Catalogue)

  /------- excerpt from achemso.tlpobj
  |...
  |docfiles size=220
  | texmf-dist/doc/latex/achemso/achemso.pdf details="Package documentation" language="en"
  |...

Currently only the tags C<details> and C<language> are supported. These
additional information can be accessed via the C<docfiledata> function
returning a hash with the respective files (including path) as key.

=item C<binfiles>

Since C<binfiles> can be different for different architectures, a single
C<tlpobj> file can, and typically does, contain C<binfiles> lines for
all available architectures. The architecture is specified on the
C<binfiles> using the C<arch=>I<XXX> tag. Thus, C<binfiles> lines look
like

  binfiles arch=XXXX size=NNNNN

=back

Here is an excerpt from the representation of the C<dvipsk> package,
with C<|> characters inserted to show the indentation:

  |name dvipsk
  |category TLCore
  |revision 52851
  |docfiles size=285
  | texmf-dist/doc/dvips/dvips.html
  | ...
  |runfiles size=93
  | texmf-dist/dvips/base/color.pro
  | ...
  | texmf-dist/scripts/pkfix/pkfix.pl
  |binfiles arch=i386-solaris size=87
  | bin/i386-solaris/afm2tfm
  | bin/i386-solaris/dvips
  |binfiles arch=windows size=51
  | bin/windows/afm2tfm.exe
  | bin/windows/dvips.exe
  |...

=head1 PACKAGE VARIABLES

TeXLive::TLPOBJ has one package-wide variable, C<containerdir>, which is
where generated container files are saved (if not otherwise specified).

  TeXLive::TLPOBJ->containerdir("path/to/container/dir");

=head1 MEMBER ACCESS FUNCTIONS

For any of the I<keys> a function

  $tlpobj->key

is available, which returns the current value when called without an argument,
and sets the respective value when called with an argument. For the
TeX Catalogue Data the function

  $tlpobj->cataloguedata

returns and takes as argument a hash.

Arguments and return values for C<name>, C<category>, C<shortdesc>,
C<longdesc>, C<catalogue>, C<revision> are single scalars.

Arguments and return values for C<depends>, C<executes> are lists.

Arguments and return values for C<docfiles>, C<runfiles>, C<srcfiles>
are lists.

Arguments and return values for C<binfiles> is a hash with the
architectures as keys.

Arguments and return values for C<docfiledata> is a hash with the
full file names of docfiles as key, and the value is again a hash.

The size values are handled with these functions:

  $tlpobj->docsize
  $tlpobj->runsize
  $tlpobj->srcsize
  $tlpobj->binsize("arch1" => size1, "arch2" => size2, ...)

which set or get the current value of the respective sizes. Note that also
the C<binsize> function returns (and takes as argument) a hash with the
architectures as keys, similar to the C<runfiles> functions (see above).

Futhermore, if the tlpobj is contained ina tlpdb which describes a media
where the files are distributed in packed format (usually as .tar.xz),
there are 6 more possible keys:

  $tlpobj->containersize
  $tlpobj->doccontainersize
  $tlpobj->srccontainersize
  $tlpobj->containerchecksum
  $tlpobj->doccontainerchecksum
  $tlpobj->srccontainerchecksum

describing the respective sizes and checksums in bytes and as hex string, resp.
The latter two are only present if src/doc file container splitting is
activated for that install medium.

=head1 OTHER FUNCTIONS

The following functions can be called for a C<TLPOBJ> object:

=over 4

=item C<new>

The constructor C<new> returns a new C<TLPSRC> object. The arguments
to the C<new> constructor can be in the usual hash representation for
the different keys above:

  $tlpobj=TLPOBJ->new(name => "foobar", shortdesc => "The foobar package");

=item C<from_file("filename")>

reads a C<tlpobj> file.

  $tlpobj = new TLPOBJ;
  $tlpobj->from_file("path/to/the/tlpobj/file");

=item C<from_fh($filehandle[, $multi])>

read the textual representation of a TLPOBJ from an already opened
file handle.  If C<$multi> is undef (i.e., not given) then multiple
tlpobj in the same file are treated as errors. If C<$multi> is defined,
then returns after reading one tlpobj.

Returns C<1> if it found a C<tlpobj>, otherwise C<0>.

=item C<writeout>

writes the textual representation of a C<TLPOBJ> object to C<stdout>,
or the filehandle if given:

  $tlpsrc->writeout;
  $tlpsrc->writeout(\*FILEHANDLE);

=item C<writeout_simple>

debugging function for comparison with C<tpm>/C<tlps>, will go away.

=item C<as_json>

returns the representation of the C<TLPOBJ> in JSON format.

=item C<common_texmf_tree>

if all files of the package are from the same texmf tree, this tree 
is returned, otherwise an undefined value. That is also a check
whether a package is relocatable.

=item C<make_container($type,$instroot, [ destdir => $destdir, containername => $containername, relative => 0|1, user => 0|1 ])>

creates a container file of the all files in the C<TLPOBJ>
in C<$destdir> (if not defined then C<< TLPOBJ->containerdir >> is used).

The C<$type> variable specifies the type of container to be used.
Currently only C<zip> or C<xz> are allowed, and generate
zip files and tar.xz files, respectively.

The file name of the created container file is C<$containername.extension>,
where extension is either C<.zip> or C<.tar.xz>, depending on the
setting of C<$type>. If no C<$containername> is specified the package name
is used.

All container files B<also> contain the respective
C<TLPOBJ> file in C<tlpkg/tlpobj/$name.tlpobj>.

The argument C<$instroot> specifies the root of the installation from
which the files should be taken.

If the argument C<$relative> is passed and true (perlish true) AND the
packages does not span multiple texmf trees (i.e., all the first path
components of all files are the same) then a relative packages is created,
i.e., the first path component is stripped. In this case the tlpobj file
is placed into the root of the installation.

This is used to distribute packages which can be installed in any arbitrary
texmf tree (of other distributions, too).

If user is present and true, no extra arguments for container generation are
passed to tar (to make sure that user tar doesn't break).

Return values are the size, the checksum, and the full name of the container.

=item C<recompute_sizes($tltree)>

recomputes the sizes based on the information present in C<$tltree>.

=item C<recompute_revision($tltree [, $revtlpsrc ])>

recomputes the revision based on the information present in C<$tltree>.
The optional argument C<$rectlpsrc> can be an additional revision number
which is taken into account. C<$tlpsrc->make_tlpobj> adds the revision
number of the C<tlpsrc> file here so that collections (which do not
contain files) also have revision number.

=item C<update_from_catalogue($texcatalogue)>

adds information from a C<TeXCatalogue> object
(currently license, version, url, and updates docfiles with details and
languages tags if present in the Catalogue).

=item C<split_bin_package>

splits off the binfiles of C<TLPOBJ> into new independent C<TLPOBJ> with
the original name plus ".arch" for every arch for which binfiles are present.
The original package is changed in two respects: the binfiles are removed
(since they are now in the single name.arch packages), and an additional
depend on "name.ARCH" is added. Note that the ARCH is a placeholder.

=item C<srcfiles_package>

=item C<docfiles_package>

splits off the srcfiles or docfiles of C<TLPOBJ> into new independent
C<TLPOBJ> with
the original name plus ".sources". The source/doc files are
B<not> removed from the original package, since these functions are only
used for the creation of split containers.

=item C<is_arch_dependent>

returns C<1> if there are C<binfiles>, otherwise C<0>.

=item C<total_size>

If no argument is given returns the sum of C<srcsize>, C<docsize>,
C<runsize>.

If arguments are given, they are assumed to be architecture names, and
it returns the above plus the sum of sizes of C<binsize> for those
architectures.

=item C<is_meta_package>

Returns true if the package is a meta package as defined in TLConfig
(Currently Collection and Scheme).

=item C<clear_{src,run,doc,bin}files>

Removes all the src/run/doc/binfiles from the C<TLPOBJ>.

=item C<{add,remove}_{src,run,doc}files(@files)>

adds or removes files to the respective list of files.

=item C<{add,remove}_binfiles($arch, @files)>

adds or removes files from the list of C<binfiles> for the given architecture.

=item C<{add,remove}_files($type, $files)>

adds or removes files for the given type (only for C<run>, C<src>, C<doc>).

=item C<contains_file($filename)>

returns the list of files matching $filename which are contained in
the package. If $filename contains a / the matching is only anchored
at the end with $. Otherwise it is prefix with a / and anchored at the end.

=item C<all_files>

returns a list of all files of all types.  However, binary files won't
be found until dependencies have been expanded via (most likely)
L<TeXLive::TLPDB::expand_dependencies>.  For a more or less standalone
example, see the C<find_old_files> function in the
script C<Master/tlpkg/libexec/place>.

=item C<allbinfiles>

returns a list of all binary files.

=item C<< $tlpobj->format_definitions  >>

The function C<format_definitions> returns a list of references to hashes
where each hash is a format definition.

=item C<< $tlpobj->fmtutil_cnf_lines >>

The function C<fmtutil_cnf_lines> returns the lines for fmtutil.cnf 
for this package.

=item C<< $tlpobj->updmap_cfg_lines >>

The function C<updmap_cfg_lines> returns the list lines for updmap.cfg
for the given package.

=item C<< $tlpobj->language_dat_lines >>

The function C<language_dat_lines> returns the list of all
lines for language.dat that can be generated from the tlpobj

=item C<< $tlpobj->language_def_lines >>

The function C<language_def_lines> returns the list of all
lines for language.def that can be generated from the tlpobj.

=item C<< $tlpobj->language_lua_lines >>

The function C<language_lua_lines> returns the list of all
lines for language.dat.lua that can be generated from the tlpobj.

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
