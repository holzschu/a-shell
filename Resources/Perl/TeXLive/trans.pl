#!/usr/bin/env perl
# $Id: trans.pl 59285 2021-05-20 21:12:36Z karl $
# Copyright 2009-2021 Norbert Preining
# This file is licensed under the GNU General Public License version 2
# or any later version.
#
# translation infrastructure for TeX Live programs
# if $::lang is set then that one is used
# if $::lang is unset try to auto-deduce it from LC_MESSAGES/Registry
# if $::opt_lang is set use that instead
#
# this module implements parsing of .po files, but no specialities of .po
# files are supported. Only reading of msgstr and msgid and concatenating
# multiple lines. Furthermore, string replacements are done:
#    \n  -> <newline>
#   \"   -> "
#   \\   -> \
#

use strict;
$^W = 1;

use utf8;
no utf8;

if (defined($::opt_lang)) {
  $::lang = $::opt_lang;
  if ($::lang eq "zh") {
    # set language to simplified chinese
    $::lang = "zh_CN";
  }
} else {
  if ($^O =~ /^MSWin/i) {
    # trying to deduce automatically the country code
    my ($lang, $area) =  TeXLive::TLWinGoo::reg_country();
    if ($lang) {
      $::lang = $lang;
      $::area = uc($area);
    } else {
      debug("didn't get any useful code from reg_country\n");
    }
  } else {
    # we load POSIX and locale stuff
    require POSIX;
    import POSIX qw/locale_h/;
    # now we try to deduce $::lang
    my $loc = setlocale(&POSIX::LC_MESSAGES);
    my ($lang,$area,$codeset);
    if ($loc =~ m/^([^_.]*)(_([^.]*))?(\.([^@]*))?(@.*)?$/) {
      $lang = defined($1)?$1:"";
      # lower case the area code
      $area = defined($3)?uc($3):"";
      if ($lang eq "zh") {
        if ($area =~ m/^(TW|HK)$/i) {
          $lang = "zh";
          $area = "TW";
        } else {
          # fallback to zh-cn for anything else, that is
          # zh-cn, zh-sg, zh, and maybe something else
          $lang = "zh";
          $area = "CN";
        }
      }
    }
    $::lang = $lang if ($lang);
    $::area = $area if ($area);
  }
}


our %TRANS;

#
# __ takes a string argument and checks that it 
sub __ ($@) {
  my $key = shift;
  my $ret;
  # if no $::lang is set just return without anything
  if (!defined($::lang)) {
    $ret = $key;
  } else {
    $ret = $key;
    $key =~ s/\\/\\\\/g;
    $key =~ s/\n/\\n/g;
    $key =~ s/"/\\"/g;
    # if the translation is defined return it
    if (defined($TRANS{$::lang}->{$key})) {
      $ret = $TRANS{$::lang}->{$key};
      if ($::debug_translation && ($key eq $ret)) {
        print STDERR "probably untranslated in $::lang: >>>$key<<<\n";
      }
    } else {
      # if we cannot find it, return $s itself
      if ($::debug_translation && $::lang ne "en") {
        print STDERR "no translation in $::lang: >>>$key<<<\n";
      }
      # $ret is already set initially
    }
    $ret =~ s/\\n/\n/g;
    $ret =~ s/\\"/"/g;
    $ret =~ s/\\\\/\\/g;
  }
  # translate back $ret:
  return sprintf($ret, @_);
}

sub load_translations() {
  if (defined($::lang) && ($::lang ne "en") && ($::lang ne "C")) {
    my $code = $::lang;
    my @files_to_check;
    if (defined($::area)) {
      $code .= "_$::area";
      push @files_to_check,
        $::lang . "_" . $::area, "$::lang-$::area",
        $::lang . "_" . lc($::area), "$::lang-" . lc($::area),
        # try also without area code, even if it is given!
        $::lang;
    } else {
      push @files_to_check, $::lang;
    }
    my $found = 0;
    for my $f (@files_to_check) {
      if (-r "$::installerdir/tlpkg/translations/$f.po") {
        $found = 1;
        $::lang = $f;
        last;
      }
    }
    if (!$found) {
       debug ("no translations available for $code (nor $::lang); falling back to English\n");
#      tlwarn ("\n  Sorry, no translations available for $code (nor $::lang); falling back to English.
#    Make sure that you have the package \"texlive-msg-translations\" installed.
#    (If you'd like to help translate the installer's messages, please see
#    https://tug.org/texlive/doc.html#install-tl-xlate for information.)\n\n");
    } else {
      # merge the translated strings into the text string
      open(LANG, "<$::installerdir/tlpkg/translations/$::lang.po");
      my $msgid;
      my $msgstr;
      my $inmsgid;
      my $inmsgstr;
      while (<LANG>) {
        chomp;
        next if m/^\s*#/;
        if (m/^\s*$/) {
          if ($inmsgid) {
            debug("msgid $msgid without msgstr in $::lang.po\n");
            $inmsgid = 0;
            $inmsgstr = 0;
            $msgid = "";
            $msgstr = "";
            next;
          }
          if ($inmsgstr) {
            if ($msgstr) {
              if (!utf8::decode($msgstr)) {
                warn("decoding string to utf8 didn't work: $msgstr\n");
              }
              # we decode msgid too to get \\ and not \
              if (!utf8::decode($msgid)) {
                warn("decoding string to utf8 didn't work: $msgid\n");
              }
              $TRANS{$::lang}{$msgid} = $msgstr;
            } else {
              ddebug("untranslated $::lang: ...$msgid...\n");
            }
            $inmsgid = 0;
            $inmsgstr = 0;
            $msgid = "";
            $msgstr = "";
            next;
          }
          next;
        }
        if (m/^msgid\s+"(.*)"\s*$/) {
          if ($msgid) {
            warn("stray msgid line: $_");
            next;
          }
          $inmsgid = 1;
          $msgid = $1;
          next;
        }
        if (m/^"(.*)"\s*$/) {
          if ($inmsgid) {
            $msgid .= $1;
          } elsif ($inmsgstr) {
            $msgstr .= $1;
          } else {
            tlwarn("cannot parse $::lang.po line: $_\n");
          }
          next;
        }
        if (m/^msgstr\s+"(.*)"\s*$/) {
          if (!$inmsgid) {
            tlwarn("msgstr $1 without msgid\n");
            next;
          }
          $msgstr = $1;
          $inmsgstr = 1;
          $inmsgid = 0;
        }
      }
      close(LANG);
    }
  }
}


1;

__END__

### Local Variables:
### perl-indent-level: 2
### tab-width: 2
### indent-tabs-mode: nil
### End:
# vim:set tabstop=2 expandtab: #
