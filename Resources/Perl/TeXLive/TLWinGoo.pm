# $Id: TLWinGoo.pm 69646 2024-01-31 18:17:20Z karl $
# TeXLive::TLWinGoo.pm - Windows goop.
# Copyright 2008-2024 Siep Kroonenberg, Norbert Preining
# This file is licensed under the GNU General Public License version 2
# or any later version.

# code for broadcast_env adapted from Win32::Env:
# Copyright 2006 Oleg "Rowaa[SR13]" V. Volkov, all rights reserved.
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.

#use strict; use warnings; notyet

package TeXLive::TLWinGoo;

my $svnrev = '$Revision: 69646 $';
my $_modulerevision;
if ($svnrev =~ m/: ([0-9]+) /) {
  $_modulerevision = $1;
} else {
  $_modulerevision = "unknown";
}
sub module_revision { return $_modulerevision; }

=pod

=head1 NAME

C<TeXLive::TLWinGoo> -- TeX Live Windows-specific support

=head2 SYNOPSIS

  use TeXLive::TLWinGoo;

=head2 DIAGNOSTICS

  TeXLive::TLWinGoo::admin;
  TeXLive::TLWinGoo::non_admin;
  TeXLive::TLWinGoo::reg_country;

=head2 ENVIRONMENT AND REGISTRY

  TeXLive::TLWinGoo::expand_string($s);
  TeXLive::TLWinGoo::get_system_path;
  TeXLive::TLWinGoo::get_user_path;
  TeXLive::TLWinGoo::setenv_reg($env_var, $env_data);
  TeXLive::TLWinGoo::unsetenv_reg($env_var);
  TeXLive::TLWinGoo::adjust_reg_path_for_texlive($action, $texbindir, $mode);
  TeXLive::TLWinGoo::add_to_progids($ext, $filetype);
  TeXLive::TLWinGoo::remove_from_progids($ext, $filetype);
  TeXLive::TLWinGoo::register_extension($mode, $extension, $file_type);
  TeXLive::TLWinGoo::unregister_extension($mode, $extension);
  TeXLive::TLWinGoo::register_file_type($file_type, $command);
  TeXLive::TLWinGoo::unregister_file_type($file_type);

=head2 ACTIVATING CHANGES IMMEDIATELY

  TeXLive::TLWinGoo::broadcast_env;
  TeXLive::TLWinGoo::update_assocs;

=head2 SHORTCUTS

  TeXLive::TLWinGoo::desktop_path;
  TeXLive::TLWinGoo::add_desktop_shortcut($texdir, $name, $icon,
    $prog, $args, $batgui);
  TeXLive::TLWinGoo::add_menu_shortcut($place, $name, $icon,
    $prog, $args, $batgui);
  TeXLive::TLWinGoo::remove_desktop_shortcut($name);
  TeXLive::TLWinGoo::remove_menu_shortcut($place, $name);

=head2 UNINSTALLER

  TeXLive::TLWinGoo::create_uninstaller;
  TeXLive::TLWinGoo::unregister_uninstaller;

=head2 ADMIN: MAKE INSTALLATION DIRECTORIES READ-ONLY

  TeXLive::TLWinGoo::maybe_make_ro($dir);

All exported functions return forward slashes.

=head1 DESCRIPTION

=over 4

=cut

BEGIN {
  use Exporter;
  use vars qw( @ISA @EXPORT @EXPORT_OK $Registry);
  @ISA = qw( Exporter );
  @EXPORT = qw(
    &admin
    &non_admin
  );
  @EXPORT_OK = qw(
    &admin_again
    &reg_country
    &broadcast_env
    &update_assocs
    &expand_string
    &get_system_path
    &get_user_path
    &setenv_reg
    &unsetenv_reg
    &adjust_reg_path_for_texlive
    &add_to_progids
    &remove_from_progids
    &register_extension
    &unregister_extension
    &register_file_type
    &unregister_file_type
    &shell_folder
    &desktop_path
    &add_desktop_shortcut
    &add_menu_shortcut
    &remove_desktop_shortcut
    &remove_menu_shortcut
    &create_uninstaller
    &unregister_uninstaller
    &maybe_make_ro
    &get_system_env
    &get_user_env
    &is_a_texdir
    &tex_dirs_on_path
  );
  if ($^O=~/^MSWin/i) {
    require Win32;
    require Win32::API;
    require Win32API::File;
    require File::Spec;
    require Win32::TieRegistry;
    Win32::TieRegistry->import( qw( $Registry
      REG_SZ REG_EXPAND_SZ REG_NONE KEY_READ KEY_WRITE KEY_ALL_ACCESS
         KEY_ENUMERATE_SUB_KEYS ) );
    $Registry->Delimiter('/');
    $Registry->ArrayValues(0);
    $Registry->FixSzNulls(1);
    require Win32::Shortcut;
    Win32::Shortcut->import( qw( SW_SHOWNORMAL SW_SHOWMINNOACTIVE ) );
    require Time::HiRes;
  }
} # end BEGIN

use TeXLive::TLConfig;
use TeXLive::TLUtils;
TeXLive::TLUtils->import( qw( mkdirhier ) );

sub reg_debug {
  return if ($::opt_verbosity < 1);
  my $mess = shift;
  my $regerr = Win32API::Registry::regLastError();
  if ($regerr) {
    debug("$regerr\n$mess");
  }
}

my $is_win = ($^O =~ /^MSWin/i);

# Win32: import wrappers for some horrible API functions

# import failures return a null result;
# call imported functions only if true/non-null

my $SendMessage = 0;
my $update_fu = 0;
if ($is_win) {
  $SendMessage = Win32::API::More->new('user32', 'SendMessageTimeout', 'LLPPLLP', 'L');
  debug ("Import failure SendMessage\n") unless $SendMessage;
  $update_fu = Win32::API::More->new('shell32', 'SHChangeNotify', 'LIPP', 'V');
  debug ("Import failure assoc_notify\n") unless $update_fu;
}

=pod

=back

=head2 DIAGNOSTICS

=cut

# permissions with which we try to access the system environment

my $is_admin = 1;

if ($is_win) {
  $is_admin = 0 unless Win32::IsAdminUser();
}

sub KEY_FULL_ACCESS() {
  return KEY_WRITE() | KEY_READ();
}

sub sys_access_permissions {
  return $is_admin ? KEY_FULL_ACCESS() : KEY_READ();
}

sub get_system_env {
  return $Registry -> Open(
    "LMachine/system/currentcontrolset/control/session manager/Environment/",
    {Access => sys_access_permissions()});
}

sub get_user_env {
  return $Registry -> Open("CUser/Environment", {Access => KEY_FULL_ACCESS()});
}

=pod

=item C<admin>

Returns admin status, admin implying having full read-write access
to the system environment.

=cut

# $is_admin has already got its correct value

sub admin { return $is_admin; }

=pod

=item C<non_admin>

Pretend not to have admin privileges, to enforce a user- rather than
a system install.

Currently only used for testing.

=cut

sub non_admin {
  debug("TLWinGoo: switching to user mode\n");
  $is_admin = 0;
}

# just for testing; doesn't check actual user permissions
sub admin_again {
  debug("TLWinGoo: switching to admin mode\n");
  $is_admin = 1;
}

=pod

=item C<reg_country>

Two-letter country code representing the locale of the current user

=cut

sub reg_country {
  my $lm = cu_root()->{"Control Panel/international//localename"};
  return unless $lm;
  debug("found lang code lm = $lm...\n");
  if ($lm) {
    if ($lm =~ m/^zh-(tw|hk)$/i) {
      return ("zh", "tw");
    } elsif ($lm =~ m/^zh/) {
      # for anything else starting with zh return, that is zh, zh-cn, zh-sg
      # and maybe something else
      return ("zh", "cn");
    } else {
      my $lang = lc(substr $lm, 0, 2);
      my $area = lc(substr $lm, 3, 2);
      return($lang, $area);
    }
  }
  # otherwise undef will be returned
}


=pod

=back

=head2 ENVIRONMENT AND REGISTRY

Most settings can be made for a user and for the system. User
settings override system settings.

For admin users, the functions below affect both user- and system
settings. For non-admin users, only user settings are changed.

An exception is the search path: the effective searchpath consists
of the system searchpath in front concatenated with the user
searchpath at the back.

Note that in a roaming profile network setup, users take only user
settings with them to other systems, not system settings. In this
case, with a TeXLive on the network, a nonadmin install makes the
most sense.

=over 4

=item C<expand_string($s)>

This function replaces substrings C<%env_var%> with their current
values as environment variable and returns the result.

=cut

sub expand_string {
  my ($s) = @_;
  return Win32::ExpandEnvironmentStrings($s);
}

my $global_tmp = $is_win ? expand_string(get_system_env()->{'TEMP'}) : "/tmp";

sub is_a_texdir {
  my $d = shift;
  $d =~ s/\\/\//g;
  $d = $d . '/' unless $d =~ m!/$!;
  # don't consider anything under %systemroot% a texdir
  my $sr = uc($ENV{'SystemRoot'});
  $sr =~ s/\\/\//g;
  $sr = $sr . '/' unless $sr =~ m!/$!;
  return 0 if index($d, $sr)==0;
  foreach my $p (qw(luatex.exe mktexlsr.exe pdftex.exe tex.exe xetex.exe)) {
    return 1 if (-e $d.$p);
  }
  return 0;
}

=pod

=item C<get_system_path>

Returns unexpanded system path, as stored in the registry.

=cut

sub get_system_path {
  my $value = get_system_env() -> {'/Path'};
  # Remove terminating zero bytes; there may be several, at least
  # under w2k, and the FixSzNulls option only removes one.
  $value =~ s/[\s\x00]+$//;
  return $value;
}

=pod

=item C<get_user_path>

Returns unexpanded user path, as stored in the registry. The user
path often does not exist, and is rarely expandable.

=cut

sub get_user_path {
  my $value = get_user_env() -> {'/Path'};
  return "" if not $value;
  $value =~ s/[\s\x00]+$//;
  return $value;
}

=pod

=item C<setenv_reg($env_var, $env_data[, $mode]);>

Set an environment variable $env_var to $env_data.

$mode="user": set for current user. $mode="system": set for all
users. Default: both if admin, current user otherwise.

=cut

sub setenv_reg {
  my $env_var = shift;
  my $env_data = shift;
  my $mode = @_ ? shift : "default";
  die "setenv_reg: Invalid mode $mode"
    if ($mode ne "user" and $mode ne "system" and $mode ne "default");
  die "setenv_reg: mode 'system' only available for admin"
    if ($mode eq "system" and !$is_admin);
  my $env;
  if ($mode ne "system") {
    $env = get_user_env();
    $env->ArrayValues(1);
    $env->{'/'.$env_var} =
       [ $env_data, ($env_data =~ /%/) ? REG_EXPAND_SZ : REG_SZ ];
  }
  if ($mode ne "user" and $is_admin) {
    $env = get_system_env();
    $env->ArrayValues(1);
    $env->{'/'.$env_var} =
       [ $env_data, ($env_data =~ /%/) ? REG_EXPAND_SZ : REG_SZ ];
  }
}

=pod

=item C<unsetenv_reg($env_var[, $mode]);>

Unset an environment variable $env_var

=cut

sub unsetenv_reg {
  my $env_var = shift;
  my $env = get_user_env();
  my $mode = @_ ? shift : "default";
  #print "Unsetenv_reg: unset $env_var with mode $mode\n";
  die "unsetenv_reg: Invalid mode $mode"
    if ($mode ne "user" and $mode ne "system" and $mode ne "default");
  die "unsetenv_reg: mode 'system' only available for admin"
    if ($mode eq "system" and !$is_admin);
  delete get_user_env()->{'/'.$env_var} if $mode ne "system";
  delete get_system_env()->{'/'.$env_var} if ($mode ne "user" and $is_admin);
}

=pod

=item C<tex_dirs_on_path($path)>

Returns tex directories found on the search path.
A directory is a TeX directory if it contains tex.exe or
pdftex.exe.

=cut

sub tex_dirs_on_path {
  my ($path) = @_;
  my ($d, $d_exp);
  my @texdirs = ();
  foreach $d (split (';', $path)) {
    $d_exp = expand_string($d);
    if (is_a_texdir($d_exp)) {
      # tlwarn("Possibly conflicting [pdf]TeX program found at $d_exp\n");
      push(@texdirs, $d_exp);
    };
  }
  return @texdirs;
}

=pod

=item C<adjust_reg_path_for_texlive($action, $tlbindir, $mode)>

Edit system or user PATH variable in the registry.
Adds or removes (depending on $action) $tlbindir directory
to system or user PATH variable in the registry (depending on $mode).

=cut

# short path names should be unique

sub short_name {
  my ($fname) = @_;
  return $fname unless $is_win;
  # GetShortPathName may return undefined, e.g. if $fname does not exist,
  # e.g. because of temporary unavailability of a network- or portable drive,
  # which should not be considered a real error
  my $shname = Win32::GetShortPathName ($fname);
  return (defined $shname) ? $shname : $fname;
}

sub adjust_reg_path_for_texlive {
  my ($action, $tlbindir, $mode) = @_;
  die("Unknown path action: $action\n")
    if ($action ne 'add') && ($action ne 'remove');
  die("Unknown path mode: $mode\n")
    if ($mode ne 'system') && ($mode ne 'user');
  debug("Warning: [pdf]tex program not found in $tlbindir\n")
    if (!is_a_texdir($tlbindir));
  my $path = ($mode eq 'system') ? get_system_path() : get_user_path();
  $tlbindir =~ s!/!\\!g;
  my $tlbindir_short = uc(short_name($tlbindir));
  my ($d, $d_short, @newpath);
  my $tex_dir_conflict = 0;
  my @texdirs;
  foreach $d (split (';', $path)) {
    $d_short = uc(short_name(expand_string($d)));
    $d_short =~ s!/!\\!g;
    ddebug("adjust_reg: compare $d_short with $tlbindir_short\n");
    if ($d_short ne $tlbindir_short) {
      push(@newpath, $d);
      if (is_a_texdir($d)) {
        $tex_dir_conflict++;
        push(@texdirs, $d);
      }
    }
  }
  if ($action eq 'add') {
    if ($tex_dir_conflict) {
      log("Warning: conflicting [pdf]tex program found on the $mode path ", 
          "in @texdirs; appending $tlbindir to the front of the path.\n");
      unshift(@newpath, $tlbindir);
    } else {
      push(@newpath, $tlbindir);
    }
  }
  if (@newpath) {
    debug("TLWinGoo: adjust_reg_path_for_texlive: calling setenv_reg in $mode\n");
    setenv_reg("Path", join(';', @newpath), $mode);
  } else {
    debug("TLWinGoo: adjust_reg_path_for_texlive: calling unsetenv_reg in $mode\n");
    unsetenv_reg("Path", $mode);
  }
  if ( ($action eq 'add') && ($mode eq 'user') ) {
    @texdirs = tex_dirs_on_path( get_system_path() );
    return 0 unless (@texdirs);
    tlwarn("Warning: conflicting [pdf]tex program found on the system path ",
           "in @texdirs; not fixable in user mode.\n");
    return 1;
  }
  return 0;
}

### File types ###

# Refactored from 2010 edition. New functionality:
# add_to_progids for defining alternate filetypes for an extension.
# Their associated programs show up in the `open with' right-click menu.

### helper subs ###

# merge recursive hash refs such as occur in the registry

sub hash_merge {
  my $target = shift; # the recursive hash ref to be modified by $mods
  my $mods = shift; # the recursive hash ref to be merged into $target
  my $k;
  foreach $k (keys %$mods) {
    if (ref($target->{$k}) eq 'HASH' and ref($mods->{$k}) eq 'HASH') {
      hash_merge($target->{$k}, $mods->{$k});
    } else {
      $target->{$k} = $mods->{$k};
      reg_debug ("at hash merge\n");
      $target->Flush();
      reg_debug ("at hash merge\n");
    }
  }
}

# prevent catastrophies during testing; not to be used in production code

sub getans {
  my $prompt = shift;
  my $ans;
  print STDERR "$prompt ";
  $ans = <STDIN>;
  if ($ans =~ /^y/i) {print STDERR "\n"; return 1;}
  die "Aborting as requested";
}

# delete a registry key recursively.
# the key parameter should be a string, not a registry object.

sub reg_delete_recurse {
  my $parent = shift;
  my $childname = shift;
  my $parentpath = $parent->Path;
  ddebug("Deleting $parentpath$childname\n");
  my $child;
  if ($childname !~ '^/') { # subkey
    $child = $parent->Open ($childname, {Access => KEY_FULL_ACCESS()});
    reg_debug ("at open $childname for all access\n");
    return 1 unless defined($child);
    foreach my $v (keys %$child) {
      if ($v =~ '^/') { # value
        delete $child->{$v};
        reg_debug ("at delete $childname/$v\n");
        $child->Flush();
        reg_debug ("at delete $childname/$v\n");
        Time::HiRes::usleep(20000);
      } else { # subkey
        return 0 unless reg_delete_recurse ($child, $v);
      }
    }
    #delete $child->{'/'};
  }
  delete $parent->{$childname};
  reg_debug ("at delete $parentpath$childname\n");
  $parent->Flush();
  reg_debug ("at delete $parentpath$childname\n");
  Time::HiRes::usleep(20000);
  return 1;
}

sub cu_root {
  my $k = $Registry -> Open("CUser", {
    Access => KEY_FULL_ACCESS(), Delimiter => '/'
  });
  reg_debug ("at open HKCU for all access\n");
  die "Cannot open HKCU for writing" unless $k;
  return $k;
}

sub lm_root {
  my $k = $Registry -> Open("LMachine", {
      Access => ($is_admin ? KEY_FULL_ACCESS() : KEY_READ()),
      Delimiter => '/'
  });
  reg_debug ("at open HKLM\n");
  die "Cannot open HKLM for ".($is_admin ? "writing" : "reading")
      unless $k;
  return $k;
}

sub do_write_regkey {
  my $keypath = shift; # modulo cu/lm
  my $keyhash = shift; # ref to a possibly nested hash; empty hash allowed
  my $remove_cu = shift;
  die "No regkey specified" unless $keypath && defined($keyhash);
  # for error reporting:
  my $hivename = $is_admin ? 'HKLM' : 'HKCU';

  # split into parent and final subkey
  # remove initial slash from parent
  # ensure subkey ends with slash
  my ($parentpath, $keyname);
  if ($keypath =~ /^\/?(.+\/)([^\/]+)\/?$/) {
    ($parentpath, $keyname) = ($1, $2);
    $keyname .= '/';
    debug ("key - $hivename - $parentpath - $keyname\n");
  } else {
    die "Cannot determine final component of $keypath";
  }

  my $cu_key = cu_root();
  my $lm_key = lm_root();
  # cu_root() and lm_root() already die upon failure
  my $parentkey;

  # make sure parent exists
  if ($is_admin) {
    $parentkey = $lm_key->Open($parentpath);
    reg_debug ("at open $parentpath; creating...\n");
    if (!$parentkey) {
      # in most cases, this probably shouldn't happen for lm
      $parentkey = $lm_key->CreateKey($parentpath);
      reg_debug ("at creating $parentpath\n");
    }
  } else {
    $parentkey = $cu_key->Open($parentpath);
    reg_debug ("at open $parentpath; creating...\n");
    if (!$parentkey) {
      $parentkey = $cu_key->CreateKey($parentpath);
      reg_debug ("at creating $parentpath\n");
    }
  }
  if (!$parentkey) {
    tlwarn "Cannot create parent of $hivename/$keypath\n";
    return 0;
  }

  # create or merge key
  if ($parentkey->{$keyname}) {
    hash_merge($parentkey->{$keyname}, $keyhash);
  } else {
    $parentkey->{$keyname} = $keyhash;
    reg_debug ("at creating $keyname\n");
  }
  if (!$parentkey->{$keyname}) {
    tlwarn "Failure to create $hivename/$keypath\n";
    return 0;
  }
  if ($is_admin and $cu_key->{$keypath} and $remove_cu) {
    # delete possibly conflicting cu key
    tlwarn "Failure to delete $hivename/$keypath key\n" unless
      reg_delete_recurse ($cu_key->{$parentpath}, $keyname);
  }
  return 1;
}

# remove a registry key under HKCU or HKLM, depending on privilege level

sub do_remove_regkey {
  my $keypath = shift; # key or value
  my $remove_cu = shift;
  my $hivename = $is_admin ? 'HKLM' : 'HKCU';

  my $parentpath = "";
  my $keyname = "";
  my $valname = "";
  # two successive delimiters: value.
  # *? = non-greedy match: want FIRST double delimiter
  if ($keypath =~ /^(.*?\/)(\/.*)$/) {
    ($parentpath, $valname) = ($1, $2);
    $parentpath =~ s!^/!!; # remove leading delimiter
  } elsif ($keypath =~ /^\/?(.+\/)([^\/]+)\/?$/) {
    ($parentpath, $keyname) = ($1, $2);
    $keyname .= '/';
  } else {
    die "Cannot determine final component of $keypath";
  }

  my $cu_key = cu_root();
  my $lm_key = lm_root();
  my ($parentkey, $k, $skv, $d);
  if ($is_admin) {
    $parentkey = $lm_key->Open($parentpath);
  } else {
    $parentkey = $cu_key->Open($parentpath);
  }
  reg_debug ("at opening $parentpath\n");
  if (!$parentkey) {
    debug ("$hivename/$parentpath not present or not writable".
      " so $keypath not removed\n");
    return 1;
  }
  if ($keyname) {
    #getans("Deleting $parentpath$keyname regkey? ");
    reg_delete_recurse($parentkey, $keyname);
    if ($parentkey->{$keyname}) {
      tlwarn "Failure to delete $hivename/$keypath\n";
      return 0;
    }
    if ($is_admin and $cu_key->{$parentpath}) {
      reg_delete_recurse($cu_key->{$parentpath}, $keyname);
      if ($cu_key->{$parentpath}->{$keyname}) {
        tlwarn "Failure to delete HKCU/$keypath\n";
        return 0;
      }
    }
  } else {
    delete $parentkey->{$valname};
    reg_debug ("at deleting $valname\n");
    if ($parentkey->{$valname}) {
      tlwarn "Failure to delete $hivename/$keypath\n";
      return 0;
    }
    if ($is_admin and $cu_key->{$parentpath}) {
      delete $cu_key->{$parentpath}->{$valname};
      reg_debug ("at deleting $valname\n");
      if ($cu_key->{$parentpath}->{$valname}) {
        tlwarn "Failure to delete HKCU/$keypath\n";
        return 0;
      }
    }
  }
  return 1;
}

#############################
# not overwriting an existing file association

# read error is sometimes access_denied,
# therefore we ONLY decide that a value does not exist if
# an attempt to read it errors out with file_not_found.

# windows error codes
my $file_not_found = 2; # ERROR_FILE_NOT_FOUND
my $reg_ok = 0; # ERROR_SUCCESS

# inaccessible value (note. actual filetypes shound not have spaces)
my $reg_unknown = 'not accessible';

# Effective default value of any key under Classes.
# admin: HKLM; user: HKCU or otherwise HKLM
sub current_filetype {
  my $extension = shift;
  my $filetype;
  my $regerror;

  if ($is_admin) {
    $regerror = $reg_ok;
    $filetype = lm_root()->{"Software/Classes/$extension//"} # REG_SZ
      or $regerror = Win32API::Registry::regLastError();
    if ($regerror != $reg_ok and $regerror != $file_not_found) {
      return $reg_unknown;
    }
  } else {
    # Mysterious failures on w7_64 => merge HKLM/HKCU info explicitly
    # rather than checking HKCR
    $regerror = $reg_ok;
    $filetype = cu_root()->{"Software/Classes/$extension//"} or
      $regerror = Win32API::Registry::regLastError();
    if ($regerror != $reg_ok and $regerror != $file_not_found) {
      return $reg_unknown;
    }
    if (!defined($filetype) or ($filetype eq "")) {
      $regerror = $reg_ok;
      $filetype = lm_root()->{"Software/Classes/$extension//"} or
        $regerror = Win32API::Registry::regLastError();
      if ($regerror != $reg_ok and $regerror != $file_not_found) {
        return $reg_unknown;
      }
    };
  }
  $filetype = "" unless defined($filetype);
  return $filetype;
}

### now the exported file type functions ###

=pod

=item C<add_to_progids($ext, $filetype)>

Add $filetype to the list of alternate progids/filetypes of extension $ext.
The associated program shows up in the `open with' right-click menu.

=cut

sub add_to_progids {
  my $ext = shift;
  my $filetype = shift;
  #$Registry->ArrayValues(1);
  #do_write_regkey("Software/Classes/$ext/OpenWithProgIds/",
  #    {"/$filetype" => [0, REG_NONE()]});
  #$Registry->ArrayValues(0);
  do_write_regkey("Software/Classes/$ext/OpenWithProgIds/",
      {"/$filetype" => ""});
}

=pod

=item C<remove_from_progids($ext, $filetype)>

Remove $filetype from the list of alternate filetypes for $ext

=cut

sub remove_from_progids {
  my $ext = shift;
  my $filetype = shift;
  do_remove_regkey("Software/Classes/$ext/OpenWithProgIds//$filetype");
}

=pod

=item C<register_extension($mode, $extension, $file_type)>

Add registry entry to associate $extension with $file_type. Slashes
are flipped where necessary.

If $mode is 0, nothing is actually done.

For $mode 1, the filetype for the extension is preserved, but only
if there is a registry key under Classes for it. For $mode>0,
the new filetype is always added to the openwithprogids list.

For $mode 2, the filetype is always overwritten. The old filetype
moves to the openwithprogids list if necessary.

=cut

sub register_extension {
  my $mode = shift;
  return 1 if $mode == 0;
  my $extension = shift;
  # ensure leading dot
  $extension = '.'.$extension unless $extension =~ /^\./;
  $extension = lc($extension);
  my $file_type = shift;
  my $regkey;

  my $old_file_type = current_filetype($extension);
  if ($old_file_type and $old_file_type ne $reg_unknown) {
    if ($is_admin) {
      if (not lm_root()->{"Software/Classes/$old_file_type/"}) {
        $old_file_type = "";
      }
    } else {
      if ((not cu_root()->{"Software/Classes/$old_file_type/"}) and
          (not lm_root()->{"Software/Classes/$old_file_type/"})) {
        $old_file_type = "";
      }
    }
  }
  # admin: whether to remove HKCU entry. admin never _writes_ to HKCU
  my $remove_cu = ($mode == 2) && admin();

  # can do the following safely:
  debug ("Adding $file_type to OpenWithProgIds of $extension\n");
  add_to_progids ($extension, $file_type);

  if ($old_file_type and $old_file_type ne $file_type) {
    if ($mode == 1) {
      debug ("Not overwriting $old_file_type with $file_type for $extension\n");
    } else { # $mode ==2, overwrite
      debug("Linking $extension to $file_type\n");
      if ($old_file_type ne $reg_unknown) {
        debug ("Moving $old_file_type to OpenWithProgIds\n");
        add_to_progids ($extension, $old_file_type);
      }
      $regkey = {'/' => $file_type};
      do_write_regkey("Software/Classes/$extension/", $regkey, $remove_cu);
    }
  } else {
    $regkey = {'/' => $file_type};
    do_write_regkey("Software/Classes/$extension/", $regkey, $remove_cu);
  }
}

=pod

=item C<unregister_extension($mode, $extension, $file_type)>

Reversal of register_extension.

=cut

sub unregister_extension {
  # we don't error check; we just do the best we can.
  my $mode = shift;
  return 1 if $mode == 0;
  # mode 1 and 2 treated identically:
  # only unregister if the current value is as expected
  my $extension = shift;
  my $file_type = shift;
  $extension = '.'.$extension unless $extension =~ /^\./;
  remove_from_progids($extension, $file_type);
  my $old_file_type = current_filetype("$extension");
  if ($old_file_type ne $file_type) {
    debug("Filetype $extension now $old_file_type; not ours, so not removed\n");
    return 1;
  } else {
    debug("unregistering extension $extension\n");
    do_remove_regkey("Software/Classes/$extension//");
  }
}

=pod

=item C<register_file_type($file_type, $command)>

Add registry entries to associate $file_type with $command. Slashes
are flipped where necessary. Double quotes should be added by the
caller if necessary.

=cut

sub register_file_type {
  my $file_type = shift;
  my $command = shift;
  tlwarn "register_file_type called with empty command\n" unless $command;
  $command =~s!/!\\!g;
  debug ("Linking $file_type to $command\n");
  my $keyhash = {
    "shell/" => {
      "open/" => {
        "command/" => {
          "/" => $command
        }
      }
    }
  };
  do_write_regkey("Software/Classes/$file_type", $keyhash);
}

=pod

=item C<unregister_file_type($file_type)>

Reversal of register_file_type.

=cut

sub unregister_file_type {
  # we don't error check; we just do the best we can.
  # All our filetypes start with 'TL.' so we consider them
  # our own even if they have been tampered with.
  my $file_type = shift;
  debug ("unregistering $file_type\n");
  do_remove_regkey("Software/Classes/$file_type/");
}

=pod

=back

=head2 ACTIVATING CHANGES IMMEDIATELY

=over 4

=item C<broadcast_env>

Broadcasts system message that enviroment has changed. This only has
an effect on newly-started programs, not on running programs or the
processes they spawn.

=cut

sub broadcast_env() {
  if ($SendMessage) {
    use constant HWND_BROADCAST => 0xffff;
    use constant WM_SETTINGCHANGE => 0x001A;
    my $result = "";
    my $ans = "12345678"; # room for dword
    $result = $SendMessage->Call(HWND_BROADCAST, WM_SETTINGCHANGE,
        0, 'Environment', 0, 2000, $ans) if $SendMessage;
    debug("Broadcast complete; result: $result.\n");
  } else {
    debug("No SendMessage available\n");
  }
}

=pod

=item C<update_assocs>

Notifies the system that filetypes have changed.

=cut

sub update_assocs() {
  use constant SHCNE_ASSOCCHANGED => 0x8000000;
  use constant SHCNF_IDLIST => 0;
  if ($update_fu) {
    debug("Notifying changes in filetypes...\n");
    my $result = $update_fu->Call(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, 0, 0);
    if ($result) {
      debug("Done notifying filetype changes\n");
    } else{
      debug("Failure notifying filetype changes\n");
    }
  } else {
    debug("No update_fu\n");
  }
}

=pod

=back

=head2 SHORTCUTS

=over 4

=item C<add_shortcut($dir, $name, $icon, $prog, $args, $batgui)>

Add a shortcut, with name $name and icon $icon, pointing to
program $prog with parameters $args (a string).  Use a non-null
batgui parameter if the shortcut starts a gui program via a
batchfile. Then the inevitable command prompt will be hidden
rightaway, leaving only the gui program visible.

=item C<add_desktop_shortcut($name, $icon, $prog, $args, $batgui)>

Add a shortcut on the desktop.

=item C<add_menu_shortcut($place, $name, $icon,
  $prog, $args, $batgui)>

Add a menu shortcut at place $place, relative to Start/Programs.

=cut

sub add_shortcut {
  my ($dir, $name, $icon, $prog, $args, $batgui) = @_;

  # make sure $dir exists
  if ((not -e $dir) and (not -d $dir)) {
    mkdirhier($dir);
  }
  if (not -d $dir) {
    tlwarn ("Failed to create directory $dir for shortcut\n");
    return;
  }
  # create shortcut
  debug "Creating shortcut $name for $prog in $dir\n";
  my ($shc, $shpath, $shfile);
  $shc = new Win32::Shortcut();
  $shc->{'IconLocation'} = $icon if -f $icon;
  $shc->{'Path'} = $prog;
  $shc->{'Arguments'} = $args;
  $shc->{'ShowCmd'} = $batgui ? SW_SHOWMINNOACTIVE : SW_SHOWNORMAL;
  $shc->{'WorkingDirectory'} = '%USERPROFILE%';
  $shfile = $dir;
  $shfile =~ s!\\!/!g;
  $shfile .= ($shfile =~ m!/$! ? '' : '/') . $name . '.lnk';
  $shc->Save($shfile);
}

sub desktop_path() {
  return Win32::GetFolderPath(
    (admin() ? Win32::CSIDL_COMMON_DESKTOPDIRECTORY :
       Win32::CSIDL_DESKTOPDIRECTORY), CREATE);
}

sub menu_path() {
  return Win32::GetFolderPath(
    (admin() ? Win32::CSIDL_COMMON_PROGRAMS : Win32::CSIDL_PROGRAMS), CREATE);
}

sub add_desktop_shortcut {
  my ($name, $icon, $prog, $args, $batgui) = @_;
  add_shortcut (desktop_path(), $name, $icon, $prog, $args, $batgui);
}

sub add_menu_shortcut {
  my ($place, $name, $icon, $prog, $args, $batgui) = @_;
  $place =~ s!\\!/!g;
  my $shdir = menu_path() . ($place =~  m!^/!=~ '/' ? '' : '/') . $place;
  add_shortcut ($shdir, $name, $icon, $prog, $args, $batgui);
}


=pod

=item C<remove_desktop_shortcut($name)>

For uninstallation of an individual package.

=item C<remove_menu_shortcut($place, $name)>

For uninstallation of an individual package.

=cut

sub remove_desktop_shortcut {
  my $name = shift;
  unlink desktop_path().'/'.$name.'.lnk';
}

sub remove_menu_shortcut {
  my $place = shift;
  my $name = shift;
  $place =~ s!\\!/!g;
  $place = '/'.$place unless $place =~ m!^/!;
  unlink menu_path().$place.'/'.$name.'.lnk';
}

=pod

=back

=head2 UNINSTALLER

=over 4

=item C<create_uninstaller>

Writes registry entries for add/remove programs which  reference
the uninstaller script and creates uninstaller batchfiles to finish
the job.

=cut

sub create_uninstaller {
  # TEXDIR
  &log("Creating uninstaller\n");
  my $td_fw = shift;
  $td_fw =~ s!\\!/!;
  my $td = $td_fw;
  $td =~ s!/!\\!g;

  my $tdmain = `"$td\\bin\\windows\\kpsewhich" -var-value=TEXMFMAIN`;
  $tdmain =~ s!/!\\!g;
  chomp $tdmain;

  my $uninst_fw = "$td_fw/tlpkg/installer";
  my $uninst_dir = $uninst_fw;
  $uninst_dir =~ s!/!\\!g;
  mkdirhier("$uninst_fw"); # wasn't this done yet?
  if (! (open UNINST, ">", "$uninst_fw/uninst.bat")) {
    tlwarn("Failed to create uninstaller\n");
    return 0;
  }
  print UNINST <<UNEND;
rem \@echo off
setlocal
path $td\\tlpkg\\tlperl\\bin;$td\\bin\\windows;%path%
set PERL5LIB=$td\\tlpkg\\tlperl\\lib
rem Clean environment from other Perl variables
set PERL5OPT=
set PERLIO=
set PERLIO_DEBUG=
set PERLLIB=
set PERL5DB=
set PERL5DB_THREADED=
set PERL5SHELL=
set PERL_ALLOW_NON_IFS_LSP=
set PERL_DEBUG_MSTATS=
set PERL_DESTRUCT_LEVEL=
set PERL_DL_NONLAZY=
set PERL_ENCODING=
set PERL_HASH_SEED=
set PERL_HASH_SEED_DEBUG=
set PERL_ROOT=
set PERL_SIGNALS=
set PERL_UNICODE=

perl.exe \"$tdmain\\scripts\\texlive\\uninstall-windows.pl\" \%1

if errorlevel 1 goto :eof
rem test for taskkill and try to stop exit tray menu
taskkill /? >nul 2>&1
if not errorlevel 1 1>nul 2>&1 taskkill /IM tl-tray-menu.exe /f
copy \"$uninst_dir\\uninst2.bat\" \"\%TEMP\%\"
rem pause
\"\%TEMP\%\\uninst2.bat\"
UNEND
;
  close UNINST;

  # We could simply delete everything under the root at one go,
  # but this might be catastrophic if TL doesn't have its own root.
  if (! (open UNINST2, ">$uninst_fw/uninst2.bat")) {
    tlwarn("Failed to complete creating uninstaller\n");
    return 0;
  }
  print UNINST2 <<UNEND2;
rmdir /s /q \"$td\\bin\"
rmdir /s /q \"$td\\readme-html.dir\"
rmdir /s /q \"$td\\readme-txt.dir\"
if exist \"$td\\temp\" rmdir /s /q \"$td\\temp\"
rmdir /s /q \"$td\\texmf-dist\"
rmdir /s /q \"$td\\tlpkg\"
del /q \"$td\\README.*\"
del /q \"$td\\LICENSE.*\"
if exist \"$td\\doc.html\" del /q \"$td\\doc.html\"
del /q \"$td\\index.html\"
del /q \"$td\\texmf.cnf\"
del /q \"$td\\texmfcnf.lua\"
del /q \"$td\\install-tl*.*\"
del /q \"$td\\tl-tray-menu.exe\"
rem del /q \"$td\\texlive.profile\"
del /q \"$td\\release-texlive.txt\"
UNEND2
;
  for my $d ('TEXMFSYSVAR', 'TEXMFSYSCONFIG') {
    my $kd = `"$td\\bin\\windows\\kpsewhich" -var-value=$d`;
    chomp $kd;
    print UNINST2 "rmdir /s /q \"", $kd, "\"\r\n";
  }
  if ($td !~ /^.:$/) { # not root of drive; remove directory if empty
    print UNINST2 <<UNEND3;
for \%\%f in (\"$td\\*\") do goto :done
for /d \%\%f in (\"$td\\*\") do goto :done
rd \"$td\"
:done
\@echo Done uninstalling TeXLive.
\@pause
del \"%0\"
UNEND3
;
  }
  close UNINST2;
  # user install: create uninstaller shortcut
  # admin install: no shortcut because it would be visible to
  # users who are not authorized to run it
  if (!admin()) {
    &log("Creating shortcut for uninstaller\n");
    TeXLive::TLWinGoo::add_menu_shortcut(
        $TeXLive::TLConfig::WindowsMainMenuName, "Uninstall TeX Live", "",
        "$uninst_dir\\uninst.bat", "", 0);
  }
  # register uninstaller
  # but not for a user install under win10 because then
  # it shows up in Settings / Apps / Apps & features,
  # where it will trigger an inappropriate UAC prompt
  if (admin()) {
    &log("Registering uninstaller\n");
    my $k;
    my $uninst_key = $Registry -> Open((admin() ? "LMachine" : "CUser") .
        "/software/microsoft/windows/currentversion/",
        {Access => KEY_FULL_ACCESS()});
    if ($uninst_key) {
      $k = $uninst_key->CreateKey(
        "uninstall/TeXLive$::TeXLive::TLConfig::ReleaseYear/");
      if ($k) {
        $k->{"/DisplayName"} = "TeX Live $::TeXLive::TLConfig::ReleaseYear";
        $k->{"/UninstallString"} = "\"$td\\tlpkg\\installer\\uninst.bat\"";
        $k->{'/DisplayVersion'} = $::TeXLive::TLConfig::ReleaseYear;
        $k->{'/Publisher'} = 'TeX Live';
        $k->{'/URLInfoAbout'} = "http://www.tug.org/texlive";
      }
    }
    if (!$k and admin()) {
      tlwarn("Failed to register uninstaller\n".
         "You can still run $td\\tlpkg\\installer\\uninst.bat manually.\n");
      return 0;
    }
  }
}

=pod

=item C<unregister_uninstaller>

Removes TeXLive from Add/Remove Programs.

=cut

sub unregister_uninstaller {
  my ($w32_multi_user) = @_;
  my $regkey_uninst_path = ($w32_multi_user ? "LMachine" : "CUser") . 
    "/software/microsoft/windows/currentversion/uninstall/";
  my $regkey_uninst = $Registry->Open($regkey_uninst_path,
    {Access => KEY_FULL_ACCESS()});
  reg_delete_recurse(
    $regkey_uninst, "TeXLive$::TeXLive::TLConfig::ReleaseYear/") 
    if $regkey_uninst;
  tlwarn "Failure to unregister uninstaller\n" if
    $regkey_uninst->{"TeXLive$::TeXLive::TLConfig::ReleaseYear/"};
}

=pod

=back

=head2 ADMIN

=over 4

=item C<TeXLive::TLWinGoo::maybe_make_ro($dir)>

Write-protects a directory $dir recursively, using ACLs, but only if
we are a multi-user install, and only if $dir is on an
NTFS-formatted local fixed disk, and only on Windows Vista and
later.  It writes a log message what it does and why.

=back

=cut

sub maybe_make_ro {
  my $dir = shift;
  debug ("Calling maybe_make_ro on $dir\n");
  tldie "$dir not a directory\n" unless -d $dir;
  if (!admin()) {
    log "Not an admin install; not making read-only\n";
    return 1;
  }

  $dir = Cwd::abs_path($dir);

  # GetDriveType: check that $dir is on local fixed disk
  # need to feed GetDriveType the drive root
  my ($volume,$dirs,$file) = File::Spec->splitpath($dir);
  debug "Split path: | $volume | $dirs | $file\n";
  # GetDriveType won't handle UNC paths so handle this case separately
  if ($volume =~ m!^[\\/][\\/]!) {
    log "$dir on UNC network path; not making read-only\n";
    return 1;
  }
  my $dt = Win32API::File::GetDriveType($volume);
  debug "Drive type $dt\n";
  if ($dt ne Win32API::File::DRIVE_FIXED) {
    log "Not a local fixed drive; not making read-only\n";
    return 1;
  }

  # FsType: test for NTFS, or, better, check whether ACLs are supported
  # FsType needs to be called for the current directory
  my $curdir = Cwd::getcwd();
  debug "Current directory $curdir\n";
  chdir $dir;
  my $newdir = Cwd::getcwd();
  debug "New current directory $newdir\n";
  tldie "Cannot cd to $dir, current dir is $newdir\n" unless
    lc($newdir) eq lc($dir);
  my ($fstype, $flags, $maxl) = Win32::FsType(); # of current drive
  if (!($flags & 0x00000008)) {
    log "$dir does not supports ACLs; not making read-only\n";
    # go back to original directory
    chdir $curdir;
    return 1;
  }

  # ran out of excuses: do it
  # we use cmd /c
  # $dir now being the current directory, we can save ourselves
  # some quoting troubles by using . for $dir.

  # some 'well-known sids':
  # S-1-5-11     Authenticated users
  # S-1-5-32-545 Users
  # S-1-5-32-544 administrators
  # S-1-3-0      creator owner (does not work right)
  # S-1-3-1      creator group

  # /reset is necessary for removing non-standard existing permissions
  my $cmd = 'cmd /c "icacls . /reset && icacls . /inheritance:r'.
    ' /grant:r *S-1-5-32-544:(OI)(CI)F'.
    ' /grant:r *S-1-5-11:(OI)(CI)RX /grant:r *S-1-5-32-545:(OI)(CI)RX"';
  log "Making read-only\n".Encode::decode(console_out,`$cmd`)."\n";

  # go back to original directory
  chdir $curdir;
  return 1;
}

# needs a terminal 1 for require to succeed!
1;

### Local Variables:
### perl-indent-level: 2
### tab-width: 2
### indent-tabs-mode: nil
### End:
# vim:set tabstop=2 expandtab: #
