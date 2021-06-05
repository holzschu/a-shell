package local::lib;
use 5.006;
BEGIN {
  if ($ENV{RELEASE_TESTING}) {
    require strict;
    strict->import;
    require warnings;
    warnings->import;
  }
}
use Config ();

our $VERSION = '2.000024';
$VERSION = eval $VERSION;

BEGIN {
  *_WIN32 = ($^O eq 'MSWin32' || $^O eq 'NetWare' || $^O eq 'symbian')
    ? sub(){1} : sub(){0};
  # punt on these systems
  *_USE_FSPEC = ($^O eq 'MacOS' || $^O eq 'VMS' || $INC{'File/Spec.pm'})
    ? sub(){1} : sub(){0};
}
my $_archname = $Config::Config{archname};
my $_version = $Config::Config{version};
my @_inc_version_list = reverse split / /, $Config::Config{inc_version_list};
my $_path_sep = $Config::Config{path_sep};

our $_DIR_JOIN = _WIN32 ? '\\' : '/';
our $_DIR_SPLIT = (_WIN32 || $^O eq 'cygwin') ? qr{[\\/]}
                                              : qr{/};
our $_ROOT = _WIN32 ? do {
  my $UNC = qr{[\\/]{2}[^\\/]+[\\/][^\\/]+};
  qr{^(?:$UNC|[A-Za-z]:|)$_DIR_SPLIT};
} : qr{^/};
our $_PERL;

sub _perl {
  if (!$_PERL) {
    # untaint and validate
    ($_PERL, my $exe) = $^X =~ /((?:.*$_DIR_SPLIT)?(.+))/;
    $_PERL = 'perl'
      if $exe !~ /perl/;
    if (_is_abs($_PERL)) {
    }
    elsif (-x $Config::Config{perlpath}) {
      $_PERL = $Config::Config{perlpath};
    }
    elsif ($_PERL =~ $_DIR_SPLIT && -x $_PERL) {
      $_PERL = _rel2abs($_PERL);
    }
    else {
      ($_PERL) =
        map { /(.*)/ }
        grep { -x $_ }
        map { ($_, _WIN32 ? ("$_.exe") : ()) }
        map { join($_DIR_JOIN, $_, $_PERL) }
        split /\Q$_path_sep\E/, $ENV{PATH};
    }
  }
  $_PERL;
}

sub _cwd {
  if (my $cwd
    = defined &Cwd::sys_cwd ? \&Cwd::sys_cwd
    : defined &Cwd::cwd     ? \&Cwd::cwd
    : undef
  ) {
    no warnings 'redefine';
    *_cwd = $cwd;
    goto &$cwd;
  }
  my $drive = shift;
  return Win32::Cwd()
    if _WIN32 && defined &Win32::Cwd && !$drive;
  local @ENV{qw(PATH IFS CDPATH ENV BASH_ENV)};
  my $cmd = $drive ? "eval { Cwd::getdcwd(q($drive)) }"
                   : 'getcwd';
  my $perl = _perl;
  my $cwd = `"$perl" -MCwd -le "print $cmd"`;
  chomp $cwd;
  if (!length $cwd && $drive) {
    $cwd = $drive;
  }
  $cwd =~ s/$_DIR_SPLIT?$/$_DIR_JOIN/;
  $cwd;
}

sub _catdir {
  if (_USE_FSPEC) {
    require File::Spec;
    File::Spec->catdir(@_);
  }
  else {
    my $dir = join($_DIR_JOIN, @_);
    $dir =~ s{($_DIR_SPLIT)(?:\.?$_DIR_SPLIT)+}{$1}g;
    $dir;
  }
}

sub _is_abs {
  if (_USE_FSPEC) {
    require File::Spec;
    File::Spec->file_name_is_absolute($_[0]);
  }
  else {
    $_[0] =~ $_ROOT;
  }
}

sub _rel2abs {
  my ($dir, $base) = @_;
  return $dir
    if _is_abs($dir);

  $base = _WIN32 && $dir =~ s/^([A-Za-z]:)// ? _cwd("$1")
        : $base                              ? _rel2abs($base)
                                             : _cwd;
  return _catdir($base, $dir);
}

our $_DEVNULL;
sub _devnull {
  return $_DEVNULL ||=
    _USE_FSPEC      ? (require File::Spec, File::Spec->devnull)
    : _WIN32        ? 'nul'
    : $^O eq 'os2'  ? '/dev/nul'
    : '/dev/null';
}

sub import {
  my ($class, @args) = @_;
  print("Entering import");
  if ($0 eq '-') {
    push @args, @ARGV;
    require Cwd;
  }

  my @steps;
  my %opts;
  my %attr;
  my $shelltype;

  while (@args) {
    my $arg = shift @args;
    # check for lethal dash first to stop processing before causing problems
    # the fancy dash is U+2212 or \xE2\x88\x92
    if ($arg =~ /\xE2\x88\x92/) {
      die <<'DEATH';
WHOA THERE! It looks like you've got some fancy dashes in your commandline!
These are *not* the traditional -- dashes that software recognizes. You
probably got these by copy-pasting from the perldoc for this module as
rendered by a UTF8-capable formatter. This most typically happens on an OS X
terminal, but can happen elsewhere too. Please try again after replacing the
dashes with normal minus signs.
DEATH
    }
    elsif ($arg eq '--self-contained') {
      die <<'DEATH';
FATAL: The local::lib --self-contained flag has never worked reliably and the
original author, Mark Stosberg, was unable or unwilling to maintain it. As
such, this flag has been removed from the local::lib codebase in order to
prevent misunderstandings and potentially broken builds. The local::lib authors
recommend that you look at the lib::core::only module shipped with this
distribution in order to create a more robust environment that is equivalent to
what --self-contained provided (although quite possibly not what you originally
thought it provided due to the poor quality of the documentation, for which we
apologise).
DEATH
    }
    elsif( $arg =~ /^--deactivate(?:=(.*))?$/ ) {
      my $path = defined $1 ? $1 : shift @args;
      push @steps, ['deactivate', $path];
    }
    elsif ( $arg eq '--deactivate-all' ) {
      push @steps, ['deactivate_all'];
    }
    elsif ( $arg =~ /^--shelltype(?:=(.*))?$/ ) {
      $shelltype = defined $1 ? $1 : shift @args;
    }
    elsif ( $arg eq '--no-create' ) {
      $opts{no_create} = 1;
    }
    elsif ( $arg eq '--quiet' ) {
      $attr{quiet} = 1;
    }
    elsif ( $arg =~ /^--/ ) {
      die "Unknown import argument: $arg";
    }
    else {
      push @steps, ['activate', $arg, \%opts];
    }
  }
  if (!@steps) {
    push @steps, ['activate', undef, \%opts];
  }

  my $self = $class->new(%attr);

  for (@steps) {
    my ($method, @args) = @$_;
    $self = $self->$method(@args);
  }

  if ($0 eq '-') {
    print $self->environment_vars_string($shelltype);
    exit 0;
  }
  else {
    $self->setup_local_lib;
  }
}

sub new {
  my $class = shift;
  bless {@_}, $class;
}

sub clone {
  my $self = shift;
  bless {%$self, @_}, ref $self;
}

sub inc { $_[0]->{inc}     ||= \@INC }
sub libs { $_[0]->{libs}   ||= [ \'PERL5LIB' ] }
sub bins { $_[0]->{bins}   ||= [ \'PATH' ] }
sub roots { $_[0]->{roots} ||= [ \'PERL_LOCAL_LIB_ROOT' ] }
sub extra { $_[0]->{extra} ||= {} }
sub quiet { $_[0]->{quiet} }

sub _as_list {
  my $list = shift;
  grep length, map {
    !(ref $_ && ref $_ eq 'SCALAR') ? $_ : (
      defined $ENV{$$_} ? split(/\Q$_path_sep/, $ENV{$$_})
                        : ()
    )
  } ref $list ? @$list : $list;
}
sub _remove_from {
  my ($list, @remove) = @_;
  return @$list
    if !@remove;
  my %remove = map { $_ => 1 } @remove;
  grep !$remove{$_}, _as_list($list);
}

my @_lib_subdirs = (
  [$_version, $_archname],
  [$_version],
  [$_archname],
  (map [$_], @_inc_version_list),
  [],
);

sub install_base_bin_path {
  my ($class, $path) = @_;
  return _catdir($path, 'bin');
}
sub install_base_perl_path {
  my ($class, $path) = @_;
  return _catdir($path, 'lib', 'perl5');
}
sub install_base_arch_path {
  my ($class, $path) = @_;
  _catdir($class->install_base_perl_path($path), $_archname);
}

sub lib_paths_for {
  my ($class, $path) = @_;
  my $base = $class->install_base_perl_path($path);
  return map { _catdir($base, @$_) } @_lib_subdirs;
}

sub _mm_escape_path {
  my $path = shift;
  $path =~ s/\\/\\\\/g;
  if ($path =~ s/ /\\ /g) {
    $path = qq{"$path"};
  }
  return $path;
}

sub _mb_escape_path {
  my $path = shift;
  $path =~ s/\\/\\\\/g;
  return qq{"$path"};
}

sub installer_options_for {
  my ($class, $path) = @_;
  return (
    PERL_MM_OPT =>
      defined $path ? "INSTALL_BASE="._mm_escape_path($path) : undef,
    PERL_MB_OPT =>
      defined $path ? "--install_base "._mb_escape_path($path) : undef,
  );
}

sub active_paths {
  my ($self) = @_;
  $self = ref $self ? $self : $self->new;

  return grep {
    # screen out entries that aren't actually reflected in @INC
    my $active_ll = $self->install_base_perl_path($_);
    grep { $_ eq $active_ll } @{$self->inc};
  } _as_list($self->roots);
}


sub deactivate {
  my ($self, $path) = @_;
  $self = $self->new unless ref $self;
  $path = $self->resolve_path($path);
  $path = $self->normalize_path($path);

  my @active_lls = $self->active_paths;

  if (!grep { $_ eq $path } @active_lls) {
    warn "Tried to deactivate inactive local::lib '$path'\n";
    return $self;
  }

  my %args = (
    bins  => [ _remove_from($self->bins,
      $self->install_base_bin_path($path)) ],
    libs  => [ _remove_from($self->libs,
      $self->install_base_perl_path($path)) ],
    inc   => [ _remove_from($self->inc,
      $self->lib_paths_for($path)) ],
    roots => [ _remove_from($self->roots, $path) ],
  );

  $args{extra} = { $self->installer_options_for($args{roots}[0]) };

  $self->clone(%args);
}

sub deactivate_all {
  my ($self) = @_;
  $self = $self->new unless ref $self;

  my @active_lls = $self->active_paths;

  my %args;
  if (@active_lls) {
    %args = (
      bins => [ _remove_from($self->bins,
        map $self->install_base_bin_path($_), @active_lls) ],
      libs => [ _remove_from($self->libs,
        map $self->install_base_perl_path($_), @active_lls) ],
      inc => [ _remove_from($self->inc,
        map $self->lib_paths_for($_), @active_lls) ],
      roots => [ _remove_from($self->roots, @active_lls) ],
    );
  }

  $args{extra} = { $self->installer_options_for(undef) };

  $self->clone(%args);
}

sub activate {
	print("Entering activate\n");
  my ($self, $path, $opts) = @_;
	print($path);
	print("\n");
  $opts ||= {};
  $self = $self->new unless ref $self;
  $path = $self->resolve_path($path);
	print($path);
	print("\n");
  $self->ensure_dir_structure_for($path, { quiet => $self->quiet })
    unless $opts->{no_create};

  $path = $self->normalize_path($path);

  my @active_lls = $self->active_paths;

  if (grep { $_ eq $path } @active_lls[1 .. $#active_lls]) {
    $self = $self->deactivate($path);
  }

  my %args;
  if ($opts->{always} || !@active_lls || $active_lls[0] ne $path) {
    %args = (
      bins  => [ $self->install_base_bin_path($path), @{$self->bins} ],
      libs  => [ $self->install_base_perl_path($path), @{$self->libs} ],
      inc   => [ $self->lib_paths_for($path), @{$self->inc} ],
      roots => [ $path, @{$self->roots} ],
    );
  }

  $args{extra} = { $self->installer_options_for($path) };

  $self->clone(%args);
}

sub normalize_path {
  my ($self, $path) = @_;
  $path = ( Win32::GetShortPathName($path) || $path )
    if $^O eq 'MSWin32';
  return $path;
}

sub build_environment_vars_for {
  my $self = $_[0]->new->activate($_[1], { always => 1 });
  $self->build_environment_vars;
}
sub build_activate_environment_vars_for {
  my $self = $_[0]->new->activate($_[1], { always => 1 });
  $self->build_environment_vars;
}
sub build_deactivate_environment_vars_for {
  my $self = $_[0]->new->deactivate($_[1]);
  $self->build_environment_vars;
}
sub build_deact_all_environment_vars_for {
  my $self = $_[0]->new->deactivate_all;
  $self->build_environment_vars;
}
sub build_environment_vars {
  my $self = shift;
  (
    PATH                => join($_path_sep, _as_list($self->bins)),
    PERL5LIB            => join($_path_sep, _as_list($self->libs)),
    PERL_LOCAL_LIB_ROOT => join($_path_sep, _as_list($self->roots)),
    %{$self->extra},
  );
}

sub setup_local_lib_for {
  my $self = $_[0]->new->activate($_[1]);
  $self->setup_local_lib;
}

sub setup_local_lib {
  my $self = shift;

  # if Carp is already loaded, ensure Carp::Heavy is also loaded, to avoid
  # $VERSION mismatch errors (Carp::Heavy loads Carp, so we do not need to
  # check in the other direction)
  require Carp::Heavy if $INC{'Carp.pm'};

  $self->setup_env_hash;
  @INC = @{$self->inc};
}

sub setup_env_hash_for {
  my $self = $_[0]->new->activate($_[1]);
  $self->setup_env_hash;
}
sub setup_env_hash {
  my $self = shift;
  my %env = $self->build_environment_vars;
  for my $key (keys %env) {
    if (defined $env{$key}) {
      $ENV{$key} = $env{$key};
    }
    else {
      delete $ENV{$key};
    }
  }
}

sub print_environment_vars_for {
  print $_[0]->environment_vars_string_for(@_[1..$#_]);
}

sub environment_vars_string_for {
  my $self = $_[0]->new->activate($_[1], { always => 1});
  $self->environment_vars_string;
}
sub environment_vars_string {
  my ($self, $shelltype) = @_;

  $shelltype ||= $self->guess_shelltype;

  my $extra = $self->extra;
  my @envs = (
    PATH                => $self->bins,
    PERL5LIB            => $self->libs,
    PERL_LOCAL_LIB_ROOT => $self->roots,
    map { $_ => $extra->{$_} } sort keys %$extra,
  );
  $self->_build_env_string($shelltype, \@envs);
}

sub _build_env_string {
  my ($self, $shelltype, $envs) = @_;
  my @envs = @$envs;

  my $build_method = "build_${shelltype}_env_declaration";

  my $out = '';
  while (@envs) {
    my ($name, $value) = (shift(@envs), shift(@envs));
    if (
        ref $value
        && @$value == 1
        && ref $value->[0]
        && ref $value->[0] eq 'SCALAR'
        && ${$value->[0]} eq $name) {
      next;
    }
    $out .= $self->$build_method($name, $value);
  }
  my $wrap_method = "wrap_${shelltype}_output";
  if ($self->can($wrap_method)) {
    return $self->$wrap_method($out);
  }
  return $out;
}

sub build_bourne_env_declaration {
  my ($class, $name, $args) = @_;
  my $value = $class->_interpolate($args, '${%s:-}', qr/["\\\$!`]/, '\\%s');

  if (!defined $value) {
    return qq{unset $name;\n};
  }

  $value =~ s/(^|\G|$_path_sep)\$\{$name:-\}$_path_sep/$1\${$name}\${$name:+$_path_sep}/g;
  $value =~ s/$_path_sep\$\{$name:-\}$/\${$name:+$_path_sep\${$name}}/;

  qq{${name}="$value"; export ${name};\n}
}

sub build_csh_env_declaration {
  my ($class, $name, $args) = @_;
  my ($value, @vars) = $class->_interpolate($args, '${%s}', qr/["\$]/, '"\\%s"');
  if (!defined $value) {
    return qq{unsetenv $name;\n};
  }

  my $out = '';
  for my $var (@vars) {
    $out .= qq{if ! \$?$name setenv $name '';\n};
  }

  my $value_without = $value;
  if ($value_without =~ s/(?:^|$_path_sep)\$\{$name\}(?:$_path_sep|$)//g) {
    $out .= qq{if "\${$name}" != '' setenv $name "$value";\n};
    $out .= qq{if "\${$name}" == '' };
  }
  $out .= qq{setenv $name "$value_without";\n};
  return $out;
}

sub build_cmd_env_declaration {
  my ($class, $name, $args) = @_;
  my $value = $class->_interpolate($args, '%%%s%%', qr(%), '%s');
  if (!$value) {
    return qq{\@set $name=\n};
  }

  my $out = '';
  my $value_without = $value;
  if ($value_without =~ s/(?:^|$_path_sep)%$name%(?:$_path_sep|$)//g) {
    $out .= qq{\@if not "%$name%"=="" set "$name=$value"\n};
    $out .= qq{\@if "%$name%"=="" };
  }
  $out .= qq{\@set "$name=$value_without"\n};
  return $out;
}

sub build_powershell_env_declaration {
  my ($class, $name, $args) = @_;
  my $value = $class->_interpolate($args, '$env:%s', qr/["\$]/, '`%s');

  if (!$value) {
    return qq{Remove-Item -ErrorAction 0 Env:\\$name;\n};
  }

  my $maybe_path_sep = qq{\$(if("\$env:$name"-eq""){""}else{"$_path_sep"})};
  $value =~ s/(^|\G|$_path_sep)\$env:$name$_path_sep/$1\$env:$name"+$maybe_path_sep+"/g;
  $value =~ s/$_path_sep\$env:$name$/"+$maybe_path_sep+\$env:$name+"/;

  qq{\$env:$name = \$("$value");\n};
}
sub wrap_powershell_output {
  my ($class, $out) = @_;
  return $out || " \n";
}

sub build_fish_env_declaration {
  my ($class, $name, $args) = @_;
  my $value = $class->_interpolate($args, '$%s', qr/[\\"'$ ]/, '\\%s');
  if (!defined $value) {
    return qq{set -e $name;\n};
  }

  # fish has special handling for PATH, CDPATH, and MANPATH.  They are always
  # treated as arrays, and joined with ; when storing the environment.  Other
  # env vars can be arrays, but will be joined without a separator.  We only
  # really care about PATH, but might as well make this routine more general.
  if ($name =~ /^(?:CD|MAN)?PATH$/) {
    $value =~ s/$_path_sep/ /g;
    my $silent = $name =~ /^(?:CD)?PATH$/ ? " ^"._devnull : '';
    return qq{set -x $name $value$silent;\n};
  }

  my $out = '';
  my $value_without = $value;
  if ($value_without =~ s/(?:^|$_path_sep)\$$name(?:$_path_sep|$)//g) {
    $out .= qq{set -q $name; and set -x $name $value;\n};
    $out .= qq{set -q $name; or };
  }
  $out .= qq{set -x $name $value_without;\n};
  $out;
}

sub _interpolate {
  my ($class, $args, $var_pat, $escape, $escape_pat) = @_;
  return
    unless defined $args;
  my @args = ref $args ? @$args : $args;
  return
    unless @args;
  my @vars = map { $$_ } grep { ref $_ eq 'SCALAR' } @args;
  my $string = join $_path_sep, map {
    ref $_ eq 'SCALAR' ? sprintf($var_pat, $$_) : do {
      s/($escape)/sprintf($escape_pat, $1)/ge; $_;
    };
  } @args;
  return wantarray ? ($string, \@vars) : $string;
}

sub pipeline;

sub pipeline {
  my @methods = @_;
  my $last = pop(@methods);
  if (@methods) {
    \sub {
      my ($obj, @args) = @_;
      $obj->${pipeline @methods}(
        $obj->$last(@args)
      );
    };
  } else {
    \sub {
      shift->$last(@_);
    };
  }
}

sub resolve_path {
  my ($class, $path) = @_;

  $path = $class->${pipeline qw(
    resolve_relative_path
    resolve_home_path
    resolve_empty_path
  )}($path);

  $path;
}

sub resolve_empty_path {
  my ($class, $path) = @_;
  if (defined $path) {
    $path;
  } else {
    '~/Documents/perl5';
  }
}

sub resolve_home_path {
  my ($class, $path) = @_;
  $path =~ /^~([^\/]*)/ or return $path;
  my $user = $1;
  my $homedir = do {
    if (! length($user) && defined $ENV{HOME}) {
      $ENV{HOME};
    }
    else {
      require File::Glob;
      File::Glob::bsd_glob("~$user", File::Glob::GLOB_TILDE());
    }
  };
  unless (defined $homedir) {
    require Carp; require Carp::Heavy;
    Carp::croak(
      "Couldn't resolve homedir for "
      .(defined $user ? $user : 'current user')
    );
  }
  $path =~ s/^~[^\/]*/$homedir/;
  $path;
}

sub resolve_relative_path {
  my ($class, $path) = @_;
  _rel2abs($path);
}

sub ensure_dir_structure_for {
  my ($class, $path, $opts) = @_;
	print("Entering ensure_dir_structure_for\n");
  $opts ||= {};
  my @dirs;
  foreach my $dir (
    $class->lib_paths_for($path),
    $class->install_base_bin_path($path),
  ) {
    my $d = $dir;
    while (!-d $d) {
      push @dirs, $d;
      require File::Basename;
      $d = File::Basename::dirname($d);
    }
  }

  warn "Attempting to create directory ${path}\n"
    if !$opts->{quiet} && @dirs;

  my %seen;
  foreach my $dir (reverse @dirs) {
    next
      if $seen{$dir}++;

    mkdir $dir
      or -d $dir
      or die "Unable to create $dir: $!"
  }
  return;
}

sub guess_shelltype {
  my $shellbin
    = defined $ENV{SHELL} && length $ENV{SHELL}
      ? ($ENV{SHELL} =~ /([\w.]+)$/)[-1]
    : ( $^O eq 'MSWin32' && exists $ENV{'!EXITCODE'} )
      ? 'bash'
    : ( $^O eq 'MSWin32' && $ENV{PROMPT} && $ENV{COMSPEC} )
      ? ($ENV{COMSPEC} =~ /([\w.]+)$/)[-1]
    : ( $^O eq 'MSWin32' && !$ENV{PROMPT} )
      ? 'powershell.exe'
    : 'sh';

  for ($shellbin) {
    return
        /csh$/                   ? 'csh'
      : /fish$/                  ? 'fish'
      : /command(?:\.com)?$/i    ? 'cmd'
      : /cmd(?:\.exe)?$/i        ? 'cmd'
      : /4nt(?:\.exe)?$/i        ? 'cmd'
      : /powershell(?:\.exe)?$/i ? 'powershell'
                                 : 'bourne';
  }
}

1;
__END__

=encoding utf8

=head1 NAME

local::lib - create and use a local lib/ for perl modules with PERL5LIB

=head1 SYNOPSIS

In code -

  use local::lib; # sets up a local lib at ~/Documents/perl5

  use local::lib '~/foo'; # same, but ~/foo

  # Or...
  use FindBin;
  use local::lib "$FindBin::Bin/../support";  # app-local support library

From the shell -

  # Install LWP and its missing dependencies to the '~/Documents/perl5' directory
  perl -MCPAN -Mlocal::lib -e 'CPAN::install(LWP)'

  # Just print out useful shell commands
  $ perl -Mlocal::lib
  PERL_MB_OPT='--install_base /home/username/perl5'; export PERL_MB_OPT;
  PERL_MM_OPT='INSTALL_BASE=/home/username/perl5'; export PERL_MM_OPT;
  PERL5LIB="/home/username/perl5/lib/perl5"; export PERL5LIB;
  PATH="/home/username/perl5/bin:$PATH"; export PATH;
  PERL_LOCAL_LIB_ROOT="/home/usename/perl5:$PERL_LOCAL_LIB_ROOT"; export PERL_LOCAL_LIB_ROOT;

From a F<.bash_profile> or F<.bashrc> file -

  eval "$(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)"

=head2 The bootstrapping technique

A typical way to install local::lib is using what is known as the
"bootstrapping" technique.  You would do this if your system administrator
hasn't already installed local::lib.  In this case, you'll need to install
local::lib in your home directory.

Even if you do have administrative privileges, you will still want to set up your
environment variables, as discussed in step 4. Without this, you would still
install the modules into the system CPAN installation and also your Perl scripts
will not use the lib/ path you bootstrapped with local::lib.

By default local::lib installs itself and the CPAN modules into ~/Documents/perl5.

Windows users must also see L</Differences when using this module under Win32>.

=over 4

=item 1.

Download and unpack the local::lib tarball from CPAN (search for "Download"
on the CPAN page about local::lib).  Do this as an ordinary user, not as root
or administrator.  Unpack the file in your home directory or in any other
convenient location.

=item 2.

Run this:

  perl Makefile.PL --bootstrap

If the system asks you whether it should automatically configure as much
as possible, you would typically answer yes.

In order to install local::lib into a directory other than the default, you need
to specify the name of the directory when you call bootstrap, as follows:

  perl Makefile.PL --bootstrap=~/foo

=item 3.

Run this: (local::lib assumes you have make installed on your system)

  make test && make install

=item 4.

Now we need to setup the appropriate environment variables, so that Perl
starts using our newly generated lib/ directory. If you are using bash or
any other Bourne shells, you can add this to your shell startup script this
way:

  echo 'eval "$(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)"' >>~/.bashrc

If you are using C shell, you can do this as follows:

  /bin/csh
  echo $SHELL
  /bin/csh
  echo 'eval `perl -I$HOME/perl5/lib/perl5 -Mlocal::lib`' >> ~/.cshrc

If you passed to bootstrap a directory other than default, you also need to
give that as import parameter to the call of the local::lib module like this
way:

  echo 'eval "$(perl -I$HOME/foo/lib/perl5 -Mlocal::lib=$HOME/foo)"' >>~/.bashrc

After writing your shell configuration file, be sure to re-read it to get the
changed settings into your current shell's environment. Bourne shells use
C<. ~/.bashrc> for this, whereas C shells use C<source ~/.cshrc>.

=back

If you're on a slower machine, or are operating under draconian disk space
limitations, you can disable the automatic generation of manpages from POD when
installing modules by using the C<--no-manpages> argument when bootstrapping:

  perl Makefile.PL --bootstrap --no-manpages

To avoid doing several bootstrap for several Perl module environments on the
same account, for example if you use it for several different deployed
applications independently, you can use one bootstrapped local::lib
installation to install modules in different directories directly this way:

  cd ~/mydir1
  perl -Mlocal::lib=./
  eval $(perl -Mlocal::lib=./)  ### To set the environment for this shell alone
  printenv                      ### You will see that ~/mydir1 is in the PERL5LIB
  perl -MCPAN -e install ...    ### whatever modules you want
  cd ../mydir2
  ... REPEAT ...

If you use F<.bashrc> to activate a local::lib automatically, the local::lib
will be re-enabled in any sub-shells used, overriding adjustments you may have
made in the parent shell.  To avoid this, you can initialize the local::lib in
F<.bash_profile> rather than F<.bashrc>, or protect the local::lib invocation
with a C<$SHLVL> check:

  [ $SHLVL -eq 1 ] && eval "$(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)"

If you are working with several C<local::lib> environments, you may want to
remove some of them from the current environment without disturbing the others.
You can deactivate one environment like this (using bourne sh):

  eval $(perl -Mlocal::lib=--deactivate,~/path)

which will generate and run the commands needed to remove C<~/path> from your
various search paths. Whichever environment was B<activated most recently> will
remain the target for module installations. That is, if you activate
C<~/path_A> and then you activate C<~/path_B>, new modules you install will go
in C<~/path_B>. If you deactivate C<~/path_B> then modules will be installed
into C<~/pathA> -- but if you deactivate C<~/path_A> then they will still be
installed in C<~/pathB> because pathB was activated later.

You can also ask C<local::lib> to clean itself completely out of the current
shell's environment with the C<--deactivate-all> option.
For multiple environments for multiple apps you may need to include a modified
version of the C<< use FindBin >> instructions in the "In code" sample above.
If you did something like the above, you have a set of Perl modules at C<<
~/mydir1/lib >>. If you have a script at C<< ~/mydir1/scripts/myscript.pl >>,
you need to tell it where to find the modules you installed for it at C<<
~/mydir1/lib >>.

In C<< ~/mydir1/scripts/myscript.pl >>:

  use strict;
  use warnings;
  use local::lib "$FindBin::Bin/..";  ### points to ~/mydir1 and local::lib finds lib
  use lib "$FindBin::Bin/../lib";     ### points to ~/mydir1/lib

Put this before any BEGIN { ... } blocks that require the modules you installed.

=head2 Differences when using this module under Win32

To set up the proper environment variables for your current session of
C<CMD.exe>, you can use this:

  C:\>perl -Mlocal::lib
  set PERL_MB_OPT=--install_base C:\DOCUME~1\ADMINI~1\perl5
  set PERL_MM_OPT=INSTALL_BASE=C:\DOCUME~1\ADMINI~1\perl5
  set PERL5LIB=C:\DOCUME~1\ADMINI~1\perl5\lib\perl5
  set PATH=C:\DOCUME~1\ADMINI~1\perl5\bin;%PATH%

  ### To set the environment for this shell alone
  C:\>perl -Mlocal::lib > %TEMP%\tmp.bat && %TEMP%\tmp.bat && del %TEMP%\tmp.bat
  ### instead of $(perl -Mlocal::lib=./)

If you want the environment entries to persist, you'll need to add them to the
Control Panel's System applet yourself or use L<App::local::lib::Win32Helper>.

The "~" is translated to the user's profile directory (the directory named for
the user under "Documents and Settings" (Windows XP or earlier) or "Users"
(Windows Vista or later)) unless $ENV{HOME} exists. After that, the home
directory is translated to a short name (which means the directory must exist)
and the subdirectories are created.

=head3 PowerShell

local::lib also supports PowerShell, and can be used with the
C<Invoke-Expression> cmdlet.

  Invoke-Expression "$(perl -Mlocal::lib)"

=head1 RATIONALE

The version of a Perl package on your machine is not always the version you
need.  Obviously, the best thing to do would be to update to the version you
need.  However, you might be in a situation where you're prevented from doing
this.  Perhaps you don't have system administrator privileges; or perhaps you
are using a package management system such as Debian, and nobody has yet gotten
around to packaging up the version you need.

local::lib solves this problem by allowing you to create your own directory of
Perl packages downloaded from CPAN (in a multi-user system, this would typically
be within your own home directory).  The existing system Perl installation is
not affected; you simply invoke Perl with special options so that Perl uses the
packages in your own local package directory rather than the system packages.
local::lib arranges things so that your locally installed version of the Perl
packages takes precedence over the system installation.

If you are using a package management system (such as Debian), you don't need to
worry about Debian and CPAN stepping on each other's toes.  Your local version
of the packages will be written to an entirely separate directory from those
installed by Debian.

=head1 DESCRIPTION

This module provides a quick, convenient way of bootstrapping a user-local Perl
module library located within the user's home directory. It also constructs and
prints out for the user the list of environment variables using the syntax
appropriate for the user's current shell (as specified by the C<SHELL>
environment variable), suitable for directly adding to one's shell
configuration file.

More generally, local::lib allows for the bootstrapping and usage of a
directory containing Perl modules outside of Perl's C<@INC>. This makes it
easier to ship an application with an app-specific copy of a Perl module, or
collection of modules. Useful in cases like when an upstream maintainer hasn't
applied a patch to a module of theirs that you need for your application.

On import, local::lib sets the following environment variables to appropriate
values:

=over 4

=item PERL_MB_OPT

=item PERL_MM_OPT

=item PERL5LIB

=item PATH

=item PERL_LOCAL_LIB_ROOT

=back

When possible, these will be appended to instead of overwritten entirely.

These values are then available for reference by any code after import.

=head1 CREATING A SELF-CONTAINED SET OF MODULES

See L<lib::core::only> for one way to do this - but note that
there are a number of caveats, and the best approach is always to perform a
build against a clean perl (i.e. site and vendor as close to empty as possible).

=head1 IMPORT OPTIONS

Options are values that can be passed to the C<local::lib> import besides the
directory to use. They are specified as C<use local::lib '--option'[, path];>
or C<perl -Mlocal::lib=--option[,path]>.

=head2 --deactivate

Remove the chosen path (or the default path) from the module search paths if it
was added by C<local::lib>, instead of adding it.

=head2 --deactivate-all

Remove all directories that were added to search paths by C<local::lib> from the
search paths.

=head2 --shelltype

Specify the shell type to use for output.  By default, the shell will be
detected based on the environment.  Should be one of: C<bourne>, C<csh>,
C<cmd>, or C<powershell>.

=head2 --no-create

Prevents C<local::lib> from creating directories when activating dirs.  This is
likely to cause issues on Win32 systems.

=head1 CLASS METHODS

=head2 ensure_dir_structure_for

=over 4

=item Arguments: $path

=item Return value: None

=back

Attempts to create a local::lib directory, including subdirectories and all
required parent directories. Throws an exception on failure.

=head2 print_environment_vars_for

=over 4

=item Arguments: $path

=item Return value: None

=back

Prints to standard output the variables listed above, properly set to use the
given path as the base directory.

=head2 build_environment_vars_for

=over 4

=item Arguments: $path

=item Return value: %environment_vars

=back

Returns a hash with the variables listed above, properly set to use the
given path as the base directory.

=head2 setup_env_hash_for

=over 4

=item Arguments: $path

=item Return value: None

=back

Constructs the C<%ENV> keys for the given path, by calling
L</build_environment_vars_for>.

=head2 active_paths

=over 4

=item Arguments: None

=item Return value: @paths

=back

Returns a list of active C<local::lib> paths, according to the
C<PERL_LOCAL_LIB_ROOT> environment variable and verified against
what is really in C<@INC>.

=head2 install_base_perl_path

=over 4

=item Arguments: $path

=item Return value: $install_base_perl_path

=back

Returns a path describing where to install the Perl modules for this local
library installation. Appends the directories C<lib> and C<perl5> to the given
path.

=head2 lib_paths_for

=over 4

=item Arguments: $path

=item Return value: @lib_paths

=back

Returns the list of paths perl will search for libraries, given a base path.
This includes the base path itself, the architecture specific subdirectory, and
perl version specific subdirectories.  These paths may not all exist.

=head2 install_base_bin_path

=over 4

=item Arguments: $path

=item Return value: $install_base_bin_path

=back

Returns a path describing where to install the executable programs for this
local library installation. Appends the directory C<bin> to the given path.

=head2 installer_options_for

=over 4

=item Arguments: $path

=item Return value: %installer_env_vars

=back

Returns a hash of environment variables that should be set to cause
installation into the given path.

=head2 resolve_empty_path

=over 4

=item Arguments: $path

=item Return value: $base_path

=back

Builds and returns the base path into which to set up the local module
installation. Defaults to C<~/Documents/perl5>.

=head2 resolve_home_path

=over 4

=item Arguments: $path

=item Return value: $home_path

=back

Attempts to find the user's home directory. If installed, uses C<File::HomeDir>
for this purpose. If no definite answer is available, throws an exception.

=head2 resolve_relative_path

=over 4

=item Arguments: $path

=item Return value: $absolute_path

=back

Translates the given path into an absolute path.

=head2 resolve_path

=over 4

=item Arguments: $path

=item Return value: $absolute_path

=back

Calls the following in a pipeline, passing the result from the previous to the
next, in an attempt to find where to configure the environment for a local
library installation: L</resolve_empty_path>, L</resolve_home_path>,
L</resolve_relative_path>. Passes the given path argument to
L</resolve_empty_path> which then returns a result that is passed to
L</resolve_home_path>, which then has its result passed to
L</resolve_relative_path>. The result of this final call is returned from
L</resolve_path>.

=head1 OBJECT INTERFACE

=head2 new

=over 4

=item Arguments: %attributes

=item Return value: $local_lib

=back

Constructs a new C<local::lib> object, representing the current state of
C<@INC> and the relevant environment variables.

=head1 ATTRIBUTES

=head2 roots

An arrayref representing active C<local::lib> directories.

=head2 inc

An arrayref representing C<@INC>.

=head2 libs

An arrayref representing the PERL5LIB environment variable.

=head2 bins

An arrayref representing the PATH environment variable.

=head2 extra

A hashref of extra environment variables (e.g. C<PERL_MM_OPT> and
C<PERL_MB_OPT>)

=head2 no_create

If set, C<local::lib> will not try to create directories when activating them.

=head1 OBJECT METHODS

=head2 clone

=over 4

=item Arguments: %attributes

=item Return value: $local_lib

=back

Constructs a new C<local::lib> object based on the existing one, overriding the
specified attributes.

=head2 activate

=over 4

=item Arguments: $path

=item Return value: $new_local_lib

=back

Constructs a new instance with the specified path active.

=head2 deactivate

=over 4

=item Arguments: $path

=item Return value: $new_local_lib

=back

Constructs a new instance with the specified path deactivated.

=head2 deactivate_all

=over 4

=item Arguments: None

=item Return value: $new_local_lib

=back

Constructs a new instance with all C<local::lib> directories deactivated.

=head2 environment_vars_string

=over 4

=item Arguments: [ $shelltype ]

=item Return value: $shell_env_string

=back

Returns a string to set up the C<local::lib>, meant to be run by a shell.

=head2 build_environment_vars

=over 4

=item Arguments: None

=item Return value: %environment_vars

=back

Returns a hash with the variables listed above, properly set to use the
given path as the base directory.

=head2 setup_env_hash

=over 4

=item Arguments: None

=item Return value: None

=back

Constructs the C<%ENV> keys for the given path, by calling
L</build_environment_vars>.

=head2 setup_local_lib

Constructs the C<%ENV> hash using L</setup_env_hash>, and set up C<@INC>.

=head1 A WARNING ABOUT UNINST=1

Be careful about using local::lib in combination with "make install UNINST=1".
The idea of this feature is that will uninstall an old version of a module
before installing a new one. However it lacks a safety check that the old
version and the new version will go in the same directory. Used in combination
with local::lib, you can potentially delete a globally accessible version of a
module while installing the new version in a local place. Only combine "make
install UNINST=1" and local::lib if you understand these possible consequences.

=head1 LIMITATIONS

=over 4

=item * Directory names with spaces in them are not well supported by the perl
toolchain and the programs it uses.  Pure-perl distributions should support
spaces, but problems are more likely with dists that require compilation. A
workaround you can do is moving your local::lib to a directory with spaces
B<after> you installed all modules inside your local::lib bootstrap. But be
aware that you can't update or install CPAN modules after the move.

=item * Rather basic shell detection. Right now anything with csh in its name is
assumed to be a C shell or something compatible, and everything else is assumed
to be Bourne, except on Win32 systems. If the C<SHELL> environment variable is
not set, a Bourne-compatible shell is assumed.

=item * Kills any existing PERL_MM_OPT or PERL_MB_OPT.

=item * Should probably auto-fixup CPAN config if not already done.

=item * On VMS and MacOS Classic (pre-OS X), local::lib loads L<File::Spec>.
This means any L<File::Spec> version installed in the local::lib will be
ignored by scripts using local::lib.  A workaround for this is using
C<use lib "$local_lib/lib/perl5";> instead of using C<local::lib> directly.

=item * Conflicts with L<ExtUtils::MakeMaker>'s C<PREFIX> option.
C<local::lib> uses the C<INSTALL_BASE> option, as it has more predictable and
sane behavior.  If something attempts to use the C<PREFIX> option when running
a F<Makefile.PL>, L<ExtUtils::MakeMaker> will refuse to run, as the two
options conflict.  This can be worked around by temporarily unsetting the
C<PERL_MM_OPT> environment variable.

=item * Conflicts with L<Module::Build>'s C<--prefix> option.  Similar to the
previous limitation, but any C<--prefix> option specified will be ignored.
This can be worked around by temporarily unsetting the C<PERL_MB_OPT>
environment variable.

=back

Patches very much welcome for any of the above.

=over 4

=item * On Win32 systems, does not have a way to write the created environment
variables to the registry, so that they can persist through a reboot.

=back

=head1 TROUBLESHOOTING

If you've configured local::lib to install CPAN modules somewhere in to your
home directory, and at some point later you try to install a module with C<cpan
-i Foo::Bar>, but it fails with an error like: C<Warning: You do not have
permissions to install into /usr/lib64/perl5/site_perl/5.8.8/x86_64-linux at
/usr/lib64/perl5/5.8.8/Foo/Bar.pm> and buried within the install log is an
error saying C<'INSTALL_BASE' is not a known MakeMaker parameter name>, then
you've somehow lost your updated ExtUtils::MakeMaker module.

To remedy this situation, rerun the bootstrapping procedure documented above.

Then, run C<rm -r ~/.cpan/build/Foo-Bar*>

Finally, re-run C<cpan -i Foo::Bar> and it should install without problems.

=head1 ENVIRONMENT

=over 4

=item SHELL

=item COMSPEC

local::lib looks at the user's C<SHELL> environment variable when printing out
commands to add to the shell configuration file.

On Win32 systems, C<COMSPEC> is also examined.

=back

=head1 SEE ALSO

=over 4

=item * L<Perl Advent article, 2011|http://perladvent.org/2011/2011-12-01.html>

=back

=head1 SUPPORT

IRC:

    Join #toolchain on irc.perl.org.

=head1 AUTHOR

Matt S Trout <mst@shadowcat.co.uk> http://www.shadowcat.co.uk/

auto_install fixes kindly sponsored by http://www.takkle.com/

=head1 CONTRIBUTORS

Patches to correctly output commands for csh style shells, as well as some
documentation additions, contributed by Christopher Nehren <apeiron@cpan.org>.

Doc patches for a custom local::lib directory, more cleanups in the english
documentation and a L<german documentation|POD2::DE::local::lib> contributed by
Torsten Raudssus <torsten@raudssus.de>.

Hans Dieter Pearcey <hdp@cpan.org> sent in some additional tests for ensuring
things will install properly, submitted a fix for the bug causing problems with
writing Makefiles during bootstrapping, contributed an example program, and
submitted yet another fix to ensure that local::lib can install and bootstrap
properly. Many, many thanks!

pattern of Freenode IRC contributed the beginnings of the Troubleshooting
section. Many thanks!

Patch to add Win32 support contributed by Curtis Jewell <csjewell@cpan.org>.

Warnings for missing PATH/PERL5LIB (as when not running interactively) silenced
by a patch from Marco Emilio Poleggi.

Mark Stosberg <mark@summersault.com> provided the code for the now deleted
'--self-contained' option.

Documentation patches to make win32 usage clearer by
David Mertens <dcmertens.perl@gmail.com> (run4flat).

Brazilian L<portuguese translation|POD2::PT_BR::local::lib> and minor doc
patches contributed by Breno G. de Oliveira <garu@cpan.org>.

Improvements to stacking multiple local::lib dirs and removing them from the
environment later on contributed by Andrew Rodland <arodland@cpan.org>.

Patch for Carp version mismatch contributed by Hakim Cassimally
<osfameron@cpan.org>.

Rewrite of internals and numerous bug fixes and added features contributed by
Graham Knop <haarg@haarg.org>.

=head1 COPYRIGHT

Copyright (c) 2007 - 2013 the local::lib L</AUTHOR> and L</CONTRIBUTORS> as
listed above.

=head1 LICENSE

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
