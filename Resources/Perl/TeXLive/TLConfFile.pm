# $Id: TLConfFile.pm 59226 2021-05-16 18:22:05Z karl $
# TeXLive::TLConfFile.pm - reading and writing conf files
# Copyright 2010-2021 Norbert Preining
# This file is licensed under the GNU General Public License version 2
# or any later version.

package TeXLive::TLConfFile;

use TeXLive::TLUtils;

my $svnrev = '$Revision: 59226 $';
my $_modulerevision;
if ($svnrev =~ m/: ([0-9]+) /) {
  $_modulerevision = $1;
} else {
  $_modulerevision = "unknown";
}
sub module_revision {
  return $_modulerevision;
}

sub new
{
  my $class = shift;
  my ($fn, $cc, $sep, $typ) = @_;
  my $self = {} ;
  $self{'file'} = $fn;
  $self{'cc'} = $cc;
  $self{'sep'} = $sep;
  if (defined($typ)) {
    if ($typ eq 'last-win' || $typ eq 'first-win' || $typ eq 'multiple') {
      $self{'type'} = $typ;
    } else {
      printf STDERR "Unknown type of conffile: $typ\n";
      printf STDERR "Should be one of: last-win first-win multiple\n";
      return;
    }
  } else {
    # default type for backward compatibility is last-win
    $self{'type'} = 'last-win';
  }
  bless $self, $class;
  return $self->reparse;
}

sub reparse
{
  my $self = shift;
  my %config = parse_config_file($self->file, $self->cc, $self->sep);
  my $lastkey = undef;
  my $lastkeyline = undef;
  $self{'keyvalue'} = ();
  $self{'confdata'} = \%config;
  $self{'changed'} = 0;
  my $in_postcomment = 0;
  for my $i (0..$config{'lines'}) {
    if ($config{$i}{'type'} eq 'comment') {
      $lastkey = undef;
      $lastkeyline = undef;
      $is_postcomment = 0;
    } elsif ($config{$i}{'type'} eq 'data') {
      $lastkey = $config{$i}{'key'};
      $lastkeyline = $i;
      $self{'keyvalue'}{$lastkey}{$i}{'value'} = $config{$i}{'value'};
      $self{'keyvalue'}{$lastkey}{$i}{'status'} = 'unchanged';
      if (defined($config{$i}{'postcomment'})) {
        $in_postcomment = 1;
      } else {
        $in_postcomment = 0;
      }
    } elsif ($config{$i}{'type'} eq 'empty') {
      $lastkey = undef;
      $lastkeyline = undef;
      $is_postcomment = 0;
    } elsif ($config{$i}{'type'} eq 'continuation') {
      if (defined($lastkey)) {
        if (!$in_postcomment) {
          $self{'keyvalue'}{$lastkey}{$lastkeyline}{'value'} .= 
            $config{$i}{'value'};
        }
      }
      # otherwise we are in a continuation of a comment!!! so nothing to do
    } else {
      print "-- UNKNOWN TYPE\n";
    }
  }
  return $self;
}

sub file
{
  my $self = shift;
  return($self{'file'});
}
sub cc
{
  my $self = shift;
  return($self{'cc'});
}
sub sep
{
  my $self = shift;
  return($self{'sep'});
}
sub type
{
  my $self = shift;
  return($self{'type'});
}

sub key_present
{
  my ($self, $key) = @_;
  return defined($self{'keyvalue'}{$key});
}

sub keys
{
  my $self = shift;
  return keys(%{$self{'keyvalue'}});
}

sub keyvaluehash
{
  my $self = shift;
  return \%{$self{'keyvalue'}};
}
sub confdatahash
{
  my $self = shift;
  return $self{'confdata'};
}

sub by_lnr
{
  # order of lines
  # first all the line numbers >= 0,
  # then the negative line numbers in reverse order
  # (negative line numbers refer to new entries in the conffile)
  # example: 
  # line number in order: 0 3 6 7 9 -1 -2 -3
  return ($a >= 0 && $b >= 0 ? $a <=> $b : $b <=> $a);
}

sub value
{
  my ($self, $key, $value, @restvals) = @_;
  my $t = $self->type;
  if (defined($value)) {
    if (defined($self{'keyvalue'}{$key})) {
      my @key_lines = sort by_lnr CORE::keys %{$self{'keyvalue'}{$key}};
      if ($t eq 'multiple') {
        my @newval = ( $value, @restvals );
        my $newlen = $#newval;
        # in case of assigning to a multiple value stuff,
        # we assign to the first n elements, delete superficial
        # or add new ones if necessary
        # $value should be a reference to an array of values
        my $listp = $self{'keyvalue'}{$key};
        my $oldlen = $#key_lines;
        my $minlen = ($newlen < $oldlen ? $newlen : $oldlen);
        for my $i (0..$minlen) {
          if ($listp->{$key_lines[$i]}{'value'} ne $newval[$i]) {
            $listp->{$key_lines[$i]}{'value'} = $newval[$i];
            if ($listp->{$key_lines[$i]}{'status'} ne 'new') {
              $listp->{$key_lines[$i]}{'status'} = 'changed';
            }
            $self{'changed'} = 1;
          }
        }
        if ($minlen < $oldlen) {
          # we are assigning less values to more lines, so we have to
          # remove the remaining ones
          for my $i (($minlen+1)..$oldlen) {
            $listp->{$key_lines[$i]}{'status'} = 'deleted';
          }
          $self{'changed'} = 1;
        }
        if ($minlen < $newlen) {
          # we have new values
          my $ll = $key_lines[$#key_lines];
          # if we are adding the first new entry, set line to -1,
          # otherwise decrease the line number (already negative
          # for new lines)
          $ll = ($ll >= 0 ? -1 : $ll-1);
          for my $i (($minlen+1)..$newlen) {
            $listp->{$ll}{'status'} = 'new';
            $listp->{$ll}{'value'} = $newval[$i];
            $ll--;
          }
          $self{'changed'} = 1;
        }
      } else {
        # select element based on first-win or last-win type
        my $ll = $key_lines[($t eq 'first-win' ? 0 : $#key_lines)];
        #print "lastwin = $ll\n";
        if ($self{'keyvalue'}{$key}{$ll}{'value'} ne $value) {
          $self{'keyvalue'}{$key}{$ll}{'value'} = $value;
          # as long as the key/value pair is not new,
          # we set its status to changed
          if ($self{'keyvalue'}{$key}{$ll}{'status'} ne 'new') {
            $self{'keyvalue'}{$key}{$ll}{'status'} = 'changed';
          }
          $self{'changed'} = 1;
        }
      }
    } else { # all new key
      my @newval = ( $value, @restvals );
      my $newlen = $#newval;
      for my $i (0..$newlen) {
        $self{'keyvalue'}{$key}{-($i+1)}{'value'} = $value;
        $self{'keyvalue'}{$key}{-($i+1)}{'status'} = 'new';
      }
      $self{'changed'} = 1;
    }
  }
  # $self->dump_myself();
  if (defined($self{'keyvalue'}{$key})) {
    my @key_lines = sort by_lnr CORE::keys %{$self{'keyvalue'}{$key}};
    if ($t eq 'first-win') {
      return $self{'keyvalue'}{$key}{$key_lines[0]}{'value'};
    } elsif ($t eq 'last-win') {
      return $self{'keyvalue'}{$key}{$key_lines[$#key_lines]}{'value'};
    } elsif ($t eq 'multiple') {
      return map { $self{'keyvalue'}{$key}{$_}{'value'} } @key_lines;
    } else {
      die "That should not happen: wrong type: $!";
    }
  }
  return;
}

sub delete_key
{
  my ($self, $key) = @_;
  %config = %{$self{'confdata'}};
  if (defined($self{'keyvalue'}{$key})) {
    for my $l (CORE::keys %{$self{'keyvalue'}{$key}}) {
      $self{'keyvalue'}{$key}{$l}{'status'} = 'deleted';
    }
    $self{'changed'} = 1;
  }
}

sub rename_key
{
  my ($self, $oldkey, $newkey) = @_;
  %config = %{$self{'confdata'}};
  for my $i (0..$config{'lines'}) {
    if (($config{$i}{'type'} eq 'data') &&
        ($config{$i}{'key'} eq $oldkey)) {
      $config{$i}{'key'} = $newkey;
      $self{'changed'} = 1;
    }
  }
  if (defined($self{'keyvalue'}{$oldkey})) {
    $self{'keyvalue'}{$newkey} = $self{'keyvalue'}{$oldkey};
    delete $self{'keyvalue'}{$oldkey};
    $self{'keyvalue'}{$newkey}{'status'} = 'changed';
    $self{'changed'} = 1;
  }
}

sub is_changed
{
  my $self = shift;
  return $self{'changed'};
}

sub save
{
  my $self = shift;
  my $outarg = shift;
  my $closeit = 0;
  # unless $outarg is defined or we are changed, return immediately
  return if (! ( defined($outarg) || $self->is_changed));
  #
  %config = %{$self{'confdata'}};
  #
  # determine where to write to
  my $out = $outarg;
  my $fhout;
  if (!defined($out)) {
    $out = $config{'file'};
    my $dn = TeXLive::TLUtils::dirname($out);
    TeXLive::TLUtils::mkdirhier($dn);
    if (!open(CFG, ">$out")) {
      tlwarn("Cannot write to $out: $!\n");
      return 0;
    }
    $closeit = 1;
    $fhout = \*CFG;
  } else {
    # check what we got there for $out
    if (ref($out) eq 'SCALAR') {
      # that is a file name
      my $dn = TeXLive::TLUtils::dirname($out);
      TeXLive::TLUtils::mkdirhier($dn);
      if (!open(CFG, ">$out")) {
        tlwarn("Cannot write to $out: $!\n");
        return 0;
      }
      $fhout = \*CFG;
      $closeit = 1;
    } elsif (ref($out) eq 'GLOB') {
      # that hopefully is a fh
      $fhout = $out;
    } else {
      tlwarn("Unknown out argument $out\n");
      return 0;
    }
  }
    
  #
  # first we write the config file as close as possible to orginal layout,
  # and after that we add new key/value pairs
  my $current_key_value_is_changed = 0;
  for my $i (0..$config{'lines'}) {
    if ($config{$i}{'type'} eq 'comment') {
      print $fhout "$config{$i}{'value'}";
      print $fhout ($config{$i}{'multiline'} ? "\\\n" : "\n");
    } elsif ($config{$i}{'type'} eq 'empty') {
      print $fhout ($config{$i}{'multiline'} ? "\\\n" : "\n");
    } elsif ($config{$i}{'type'} eq 'data') {
      $current_key_value_is_changed = 0;
      # we have to check whether the original data has been changed!!
      if ($self{'keyvalue'}{$config{$i}{'key'}}{$i}{'status'} eq 'changed') {
        $current_key_value_is_changed = 1;
        print $fhout "$config{$i}{'key'} $config{'sep'} $self{'keyvalue'}{$config{$i}{'key'}}{$i}{'value'}";
        if (defined($config{$i}{'postcomment'})) {
          print $fhout $config{$i}{'postcomment'};
        }
        # if a value is changed, we do not print out multiline stuff
        # as keys are not split
        print $fhout "\n";
      } elsif ($self{'keyvalue'}{$config{$i}{'key'}}{$i}{'status'} eq 'deleted') {
        $current_key_value_is_changed = 1;
      } else {
        $current_key_value_is_changed = 0;
        # the original already contains the final \, so only print new line
        print $fhout "$config{$i}{'original'}\n";
      }
    } elsif ($config{$i}{'type'} eq 'continuation') {
      if ($current_key_value_is_changed) {
        # ignore continuation lines if values are changed
      } else {
        print $fhout "$config{$i}{'value'}";
        print $fhout ($config{$i}{'multiline'} ? "\\\n" : "\n");
      }
    }
  }
  #
  # save new keys
  for my $k (CORE::keys %{$self{'keyvalue'}}) {
    for my $l (CORE::keys %{$self{'keyvalue'}{$k}}) {
      if ($self{'keyvalue'}{$k}{$l}{'status'} eq 'new') {
        print $fhout "$k $config{'sep'} $self{'keyvalue'}{$k}{$l}{'value'}\n";
      }
    }
  }
  close $fhout if $closeit;
  #
  # reparse myself
  if (!defined($outarg)) {
    $self->reparse;
  }
}




#
# parse/write config file
# these functions allow reading and writing of config files
# that consists of comments (comment char/string is the second argument)
# and pairs
#   \s* key \s* SEP \s* value \s*
# where SEP is the third argument,
# and key does not contain neither white space nor SEP
# and value can be arbitry
#
# continuation lines are allowed
# Furthermore, at least the separator has to be on the same line as the key!!
# Continuations followed by comment lines are invalid!
#
sub parse_config_file {
  my ($file, $cc, $sep) = @_;
  my @data;
  if (!open(CFG, "<$file")) {
    @data = ();
  } else {
    @data = <CFG>;
    chomp(@data);
    close(CFG);
  }

  my %config = ();
  $config{'file'} = $file;
  $config{'cc'} = $cc;
  $config{'sep'} = $sep;

  my $lines = $#data;
  my $cont_running = 0;
  for my $l (0..$lines) {
    $config{$l}{'original'} = $data[$l];
    if ($cont_running) {
      if ($data[$l] =~ m/^(.*)\\$/) {
        $config{$l}{'type'} = 'continuation';
        $config{$l}{'multiline'} = 1;
        $config{$l}{'value'} = $1;
        next;
      } else {
        # last line of a continuation
        # do nothing, we will finish here
        $config{$l}{'type'} = 'continuation';
        $config{$l}{'value'} = $data[$l];
        $cont_running = 0;
        next;
      }
    }
    # ignore continuation after comments, that is the behaviour the
    # kpathsea library is using, so we follow it here
    if ($data[$l] =~ m/$cc/) {
      $data[$l] =~ s/\\$//;
    }
    # continuation line
    if ($data[$l] =~ m/^(.*)\\$/) {
      $cont_running = 1;
      $config{$l}{'multiline'} = 1;
      # remove the continuation marker so that we can do everything
      # as normal below
      $data[$l] =~ s/\\$//;
      # we will continue below
    }
    # from now on, if $cont_running == 1, then it means that
    # we are in the FIRST line of a multi line setting, so evaluate
    # it accordingly to get the key if necessary

    # empty lines are treated as comments
    if ($data[$l] =~ m/^\s*$/) {
      $config{$l}{'type'} = 'empty';
      next;
    }
    if ($data[$l] =~ m/^\s*$cc/) {
      # save the full line as is into the config hash
      $config{$l}{'type'} = 'comment';
      $config{$l}{'value'} = $data[$l];
      next;
    }
    # mind that the .*? is making the .* NOT greedy, ie matching as few as
    # possible. That way we can get rid of the comments at the end of lines
    if ($data[$l] =~ m/^\s*([^\s$sep]+)\s*$sep\s*(.*?)(\s*)?($cc.*)?$/) {
      $config{$l}{'type'} = 'data';
      $config{$l}{'key'} = $1;
      $config{$l}{'value'} = $2;
      if (defined($3)) {
        my $postcomment = $3;
        if (defined($4)) {
          $postcomment .= $4;
        }
        # check that there is actually a comment in the second part of the
        # line. Otherwise we might add the continuation lines of that
        # line to the value
        if ($postcomment =~ m/$cc/) {
          $config{$l}{'postcomment'} = $postcomment;
        }
      }
      next;
    }
    # if we are still here, that means we cannot evaluate the config file
    # give a BIG FAT WARNING but save the line as comment and continue 
    # anyway
    warn("WARNING WARNING WARNING\n");
    warn("Cannot parse config file $file ($cc, $sep)\n");
    warn("The following line (l.$l) seems to be wrong:\n");
    warn(">>> $data[$l]\n");
    warn("We will treat this line as a comment!\n");
    $config{$l}{'type'} = 'comment';
    $config{$l}{'value'} = $data[$l];
  }
  # save the number of lines in the config hash
  $config{'lines'} = $lines;
  #print "====DEBUG dumping config ====\n";
  #dump_config_data(\%config);
  #print "====DEBUG writing config ====\n";
  #write_config_file(\%config);
  #print "=============================\n";
  return %config;
}

sub dump_myself {
  my $self = shift;
  print "======== DUMPING SELF =============\n";
  dump_config_data($self{'confdata'});
  print "DUMPING KEY VALUES\n";
  for my $k (CORE::keys %{$self{'keyvalue'}}) {
    print "key = $k\n";
    for my $l (sort CORE::keys %{$self{'keyvalue'}{$k}}) {
      print "  line =$l= value =", $self{'keyvalue'}{$k}{$l}{'value'}, "= status =", $self{'keyvalue'}{$k}{$l}{'status'}, "=\n";
    }
  }
  print "=========== END DUMP ==============\n";
}

sub dump_config_data {
  my $foo = shift;
  my %config = %{$foo};
  print "config file name: $config{'file'}\n";
  print "config comment char: $config{'cc'}\n";
  print "config separator: $config{'sep'}\n";
  print "config lines: $config{'lines'}\n";
  for my $i (0..$config{'lines'}) {
    print "line ", $i+1, ": $config{$i}{'type'}";
    if ($config{$i}{'type'} eq 'comment') {
      print "\nCOMMENT = $config{$i}{'value'}\n";
    } elsif ($config{$i}{'type'} eq 'data') {
      print "\nKEY = $config{$i}{'key'}\nVALUE = $config{$i}{'value'}\n";
      print "MULTLINE = ", ($config{$i}{'multiline'} ? "1" : "0"), "\n";
    } elsif ($config{$i}{'type'} eq 'empty') {
      print "\n";
      # do nothing
    } elsif ($config{$i}{'type'} eq 'continuation') {
      print "\nVALUE = $config{$i}{'value'}\n";
      print "MULTLINE = ", ($config{$i}{'multiline'} ? "1" : "0"), "\n";
    } else {
      print "-- UNKNOWN TYPE\n";
    }
  }
}
      
sub write_config_file {
  my $foo = shift;
  my %config = %{$foo};
  for my $i (0..$config{'lines'}) {
    if ($config{$i}{'type'} eq 'comment') {
      print "$config{$i}{'value'}";
      print ($config{$i}{'multiline'} ? "\\\n" : "\n");
    } elsif ($config{$i}{'type'} eq 'data') {
      print "$config{$i}{'key'} $config{'sep'} $config{$i}{'value'}";
      if ($config{$i}{'multiline'}) {
        print "\\";
      }
      print "\n";
    } elsif ($config{$i}{'type'} eq 'empty') {
      print ($config{$i}{'multiline'} ? "\\\n" : "\n");
    } elsif ($config{$i}{'type'} eq 'continuation') {
      print "$config{$i}{'value'}";
      print ($config{$i}{'multiline'} ? "\\\n" : "\n");
    } else {
      print STDERR "-- UNKNOWN TYPE\n";
    }
  }
}


1;
__END__


=head1 NAME

C<TeXLive::TLConfFile> -- TeX Live generic configuration files

=head1 SYNOPSIS

  use TeXLive::TLConfFile;

  my $conffile = TeXLive::TLConfFile->new($file_name, $comment_char,
                                          $separator, $type);
  $conffile->file;
  $conffile->cc;
  $conffile->sep;
  $conffile->type
  $conffile->key_present($key);
  $conffile->keys;
  $conffile->value($key [, $value, ...]);
  $conffile->is_changed;
  $conffile->save;
  $conffile->reparse;

=head1 DESCRIPTION

This module allows parsing, changing, saving of configuration files
of a general style. It also supports three different paradigma 
with respect to multiple occurrences of keys: C<first-win> specifies
a configuration file where the first occurrence of a key specifies
the value, C<last-win> specifies that the last wins, and
C<multiple> that all keys are kept.

The configuration files (henceforth conffiles) can contain comments
initiated by the $comment_char defined at instantiation time.
Everything after a $comment_char, as well as empty lines, will be ignored.

The rest should consists of key/value pairs separated by the separator,
defined as well at instantiation time.

Whitespace around the separator, and before and after key and value 
are allowed.

Comments can be on the same line as key/value pairs and are also preserved
over changes.

Continuation lines (i.e., lines with last character being a backslash)
are allowed after key/value pairs, but the key and
the separator has to be on the same line.

Continuations are not possible in comments, so a terminal backslash in 
a comment will be ignored, and in fact not written out on save.

=head2 Methods

=over 4

=item B<< $conffile = TeXLive::TLConfFile->new($file_name, $comment_char, $separator [, $type]) >>

instantiates a new TLConfFile and returns the object. The file specified
by C<$file_name> does not have to exist, it will be created at save time.

The C<$comment_char> can actually be any regular expression, but 
embedding grouping is a bad idea as it will break parsing.

The C<$separator> can also be any regular expression.

The C<$type>, if present, has to be one of C<last-win> (the default),
C<first-win>, or C<multiple>.

=item B<< $conffile->file >>

Returns the location of the configuration file. Not changeable (at the moment).

=item B<< $conffile->cc >>

Returns the comment character.

=item B<< $conffile->sep >>

Returns the separator.

=item B<< $conffile->type >>

Returns the type.

=item B<< $conffile->key_present($key) >>

Returns true (1) if the given key is present in the config file, otherwise
returns false (0).

=item B<< $conffile->keys >>

Returns the list of keys currently set in the config file.

=item B<< $conffile->value($key [, $value, ...]) >>

With one argument, returns the current setting of C<$key>, or undefined
if the key is not set. If the configuration file is of C<multiple>
type a list of keys ordered by occurrence in the file is returned.

With two (or more) arguments changes (or adds) the key/value pair to 
the config file and returns the I<new> value.
In case of C<first-win> or C<last-win>, the respective occurrence
of the key is changed, and the others left intact. In this case only
the first C<$value> is used.

In case of C<multiple> the C<$values> are assigned to the keys in the 
order of occurrence in the file. If extra values are present, they
are added. If on the contrary less values then already existing
keys are passed, the remaining keys are deleted.

=item B<< $conffile->rename_key($oldkey, $newkey) >>

Renames a key from C<$oldkey> to C<$newkey>. It does not automatically
save the new config file.

=item B<< $conffile->is_changed >>

Returns true (1) if some real change has happened in the configuration file,
that is a value has been changed to something different, or a new
setting has been added.

Note that changing a setting back to the original one will not reset
the changed flag.

=item B<< $conffile->save >>

Saves the config file, preserving as much structure and comments of 
the original file as possible.

=item B<< $conffile->reparse >>

Reparses the configuration file.


=back

=head1 EXAMPLES

For parsing a C<texmf.cnf> file you can use

  $tmfcnf = TeXLive::TLConfFile->new(".../texmf-dist/web2c", "[#%]", "=");

since the allowed comment characters for texmf.cnf files are # and %.
After that you can query keys:

  $tmfcnf->value("TEXMFMAIN");
  $tmfcnf->value("trie_size", 900000);
 
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
