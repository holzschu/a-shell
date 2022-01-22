# $Id: TLConfig.pm 59225 2021-05-16 17:41:12Z karl $
# TeXLive::TLConfig.pm - module exporting configuration values
# Copyright 2007-2021 Norbert Preining
# This file is licensed under the GNU General Public License version 2
# or any later version.

package TeXLive::TLConfig;

my $svnrev = '$Revision: 59225 $';
my $_modulerevision = ($svnrev =~ m/: ([0-9]+) /) ? $1 : "unknown";
sub module_revision { return $_modulerevision; }

BEGIN {
  use Exporter ();
  use vars qw( @ISA @EXPORT_OK @EXPORT );
  @ISA = qw(Exporter);
  @EXPORT_OK = qw(
    $ReleaseYear
    @MetaCategories
    @NormalCategories
    @Categories
    $MetaCategoriesRegexp
    $CategoriesRegexp
    $DefaultCategory
    @AcceptedFallbackDownloaders
    %FallbackDownloaderProgram
    %FallbackDownloaderArgs
    $DefaultCompressorFormat
    $CompressorExtRegexp
    %Compressors
    $InfraLocation
    $DatabaseName
    $DatabaseLocation
    $PackageBackupDir 
    $BlockSize
    $Archive
    $TeXLiveServerURL
    $TeXLiveServerURLRegexp
    $TeXLiveServerPath
    $TeXLiveURL
    @CriticalPackagesList
    $CriticalPackagesRegexp
    $WindowsMainMenuName
    $RelocPrefix
    $RelocTree
    %TLPDBOptions
    %TLPDBSettings
    %TLPDBConfigs
    $NetworkTimeout
    $MaxLWPErrors
    $MaxLWPReinitCount
    $PartialEngineSupport
    $F_OK $F_WARNING $F_ERROR $F_NOPOSTACTION
    $ChecksumLength
    $ChecksumProgram
    $ChecksumExtension
  );
  @EXPORT = @EXPORT_OK;
}

# the year of our release, will be used in the location of the
# network packages, and in menu names, and other places.
$ReleaseYear = 2021;

# users can upgrade from this year to the current year; might be the
# same as the release year, or any number of releases earlier.
# Generally not tested, but should be.
$MinRelease = 2016;

# Meta Categories do not ship files, but only call for other packages.
our @MetaCategories = qw/Collection Scheme/;
our $MetaCategoriesRegexp = '(Collection|Scheme)';
#
# Normal Categories contain actial files and do not depend on other things.
our @NormalCategories = qw/Package TLCore ConTeXt/;
#
# list of all Categories
our @Categories = (@MetaCategories, @NormalCategories);

# repeat, as a regexp.
our $CategoriesRegexp = '(Collection|Scheme|Package|TLCore|ConTeXt)';

our $DefaultCategory = "Package";

# location of various infra files (texlive.tlpdb, .tlpobj etc)
# relative to a root (e.g., the Master/, or the installation path)
our $InfraLocation = "tlpkg";
our $DatabaseName = "texlive.tlpdb";
our $DatabaseLocation = "$InfraLocation/$DatabaseName";

# location of backups in default autobackup setting (under tlpkg)
our $PackageBackupDir = "$InfraLocation/backups";

# for computing disk usage; this is most common.
our $BlockSize = 4096;

# timeout for network connections (wget, LWP) in seconds
our $NetworkTimeout = 30;
# number of errors during an LWP session until it is marked as disabled
our $MaxLWPErrors = 5;
# max number of times we reenable LWP after it was disabled
our $MaxLWPReinitCount = 10;

our $Archive = "archive";
our $TeXLiveServerURL = "https://mirror.ctan.org";
our $TeXLiveServerURLRegexp = 'https?://mirror\.ctan\.org';
# from 2009 on we try to put them all into tlnet directly without any
# release year since we hope that we can switch over to 2010 on the fly
# our $TeXLiveServerPath = "systems/texlive/tlnet/$ReleaseYear";
our $TeXLiveServerPath = "systems/texlive/tlnet";
our $TeXLiveURL = "$TeXLiveServerURL/$TeXLiveServerPath";

# Relocatable packages.
our $RelocTree = "texmf-dist";
our $RelocPrefix = "RELOC";

our @CriticalPackagesList = qw/texlive.infra/;
our $CriticalPackagesRegexp = '^(texlive\.infra)';
if ($^O =~ /^MSWin/i) {
  push (@CriticalPackagesList, "tlperl.win32");
  $CriticalPackagesRegexp = '^(texlive\.infra|tlperl\.win32$)';
}

#
our @AcceptedFallbackDownloaders = qw/curl wget/;
our %FallbackDownloaderProgram = ( 'wget' => 'wget', 'curl' => 'curl');
our %FallbackDownloaderArgs = (
  'curl' => ['--user-agent', 'texlive/curl',
             '--retry', '4', '--retry-delay', '4',
             '--connect-timeout', "$NetworkTimeout", 
             '--fail', '--location', '--silent', '--output'],
  'wget' => ['--user-agent=texlive/wget', '--tries=4',
             "--timeout=$NetworkTimeout", '-q', '-O'],
);
# the way we package things on the web
our $DefaultCompressorFormat = "xz";
# priority defines which compressor is selected for backups/rollback containers
# less is better
our %Compressors = (
  "lz4" => {
    "decompress_args" => ["-dcf"],
    "compress_args"   => ["-zfmq"],
    "extension"       => "lz4",
    "priority"        => 10,
  },
  "gzip" => {
    "decompress_args" => ["-dcf"],
    "compress_args"   => ["-f"],
    "extension"       => "gz",
    "priority"        => 20,
  },
  "xz" => {
    "decompress_args" => ["-dcf"],
    "compress_args"   => ["-zf"],
    "extension"       => "xz",
    "priority"        => 30,
  },
);
our $CompressorExtRegexp = "("
    . join("|", map { $Compressors{$_}{'extension'} } keys %Compressors)
    . ")";

# archive (not user) settings.
# these can be overridden by putting them into 00texlive.config.tlpsrc
# in the format
#   depend key/value
our %TLPDBConfigs = (
  "container_split_src_files" => 1,
  "container_split_doc_files" => 1,
  "container_format" => $DefaultCompressorFormat,
  "minrelease" => $MinRelease,
  "release" => $ReleaseYear,
  "frozen" => 0,
);

# definition of the option strings and their value types 
# possible types are:
# - u: url
# - b: boolean, saved as 0/1
# - p: path (local path)
# - n: natural number
#      it allows n:[a]..[b]
#         if a is empty start at -infty
#         if b is empty end at +infty
#      so "n:.." is equivalent to "n"

# $TLPDBOptions{"option"}->[0] --> type
#                        ->[1] --> default value
#                        ->[2] --> tlmgr name
#                        ->[3] --> tlmgr description
# the "option" is the value in the TLPDB

our %TLPDBOptions = (
  "autobackup" =>
    [ "n:-1..", 1, "autobackup",
      "Number of backups to keep" ],
  "backupdir" =>
    [ "p", $PackageBackupDir, "backupdir",
      "Directory for backups" ],
  "create_formats" =>
    [ "b", 1, "formats",  
      "Generate formats at installation or update" ],
  "desktop_integration" =>
    [ "b", 1, "desktop_integration",
      "Create Start menu shortcuts (w32)" ],
  "file_assocs" =>
    [ "n:0..2", 1, "fileassocs",
      "Change file associations (w32)" ],
  "generate_updmap" =>
    [ "b", 0, "generate_updmap",
      "Run tlmgr generate updmap after maps have changed" ],
  "install_docfiles" =>
    [ "b", 1, "docfiles",
      "Install documentation files" ],
  "install_srcfiles" =>
    [ "b", 1, "srcfiles",
      "Install source files" ],
  "location" =>
    [ "u", "__MASTER__", "repository", 
      "Default package repository" ],
  "post_code" =>
    [ "b", 1, "postcode",
      "Run postinst code blobs" ],
  "sys_bin" =>
    [ "p", "/usr/local/bin", "sys_bin",
      "Destination for symlinks for binaries" ],
  "sys_info" =>
    [ "p", "/usr/local/share/info", "sys_info",
      "Destination for symlinks for info docs" ],
  "sys_man" =>
    [ "p", "/usr/local/share/man", "sys_man",
      "Destination for symlinks for man pages" ],
  "w32_multi_user" =>
    [ "b", 1, "multiuser",
      "Install for all users (w32)" ],
);


our %TLPDBSettings = (
  "platform" => [ "s", "Main platform for this computer" ],
  "available_architectures" => [ "l","All available/installed architectures" ],
  "usertree" => [ "b", "This tree acts as user tree" ]
);

our $WindowsMainMenuName = "TeX Live $ReleaseYear";

# Comma-separated list of engines which do not exist on all platforms.
our $PartialEngineSupport = "luajithbtex,luajittex,mfluajit";

# Flags for error handling across the scripts and modules
# all fine
our $F_OK = 0;
#
# some warnings, but we still try to run post actions
our $F_WARNING = 1;
#
# error, terminating
our $F_ERROR = 2;
#
# all fine, but no need to run post actions
our $F_NOPOSTACTION = 4;

# The length of a checksum generated by tlchecksum and contained in
# texlive.tlpdb.checksum. Needs to be in agreement with the hash
# method used in TLCrypto::tlchecksum and TLCrypto::tldigest
our $ChecksumLength = 128;

# The program generating the checksum for the file given as first
# argument
our $ChecksumProgram = "sha512sum";

# The extension of the checksum file
our $ChecksumExtension = "sha512";

1;


=head1 NAME

C<TeXLive::TLConfig> -- TeX Live configuration parameters

=head1 SYNOPSIS

  use TeXLive::TLConfig;

=head1 DESCRIPTION

The L<TeXLive::TLConfig> module contains definitions of variables 
configuring all of TeX Live.

=head2 EXPORTED VARIABLES

All of the following variables are pulled into the callers namespace,
i.e., are declared with C<EXPORT> (and C<EXPORT_OK>).

=over 4

=item C<@TeXLive::TLConfig::MetaCategories>

The list of meta categories, i.e., those categories whose packages only
depend on other packages, but don't ship any files. Currently 
C<Collection> and <Scheme>.

=item C<@TeXLive::TLConfig::NormalCategories>

The list of normal categories, i.e., those categories whose packages do
ship files. Currently C<TLCore>, C<Package>, C<ConTeXt>.

=item C<@TeXLive::TLConfig::Categories>

The list of all categories, i.e., the union of the above.

=item C<$TeXLive::TLConfig::CategoriesRegexp>

A regexp matching any category.

=item C<$TeXLive::TLConfig::DefaultCategory>

The default category used when creating new packages.

=item C<$TeXLive::TLConfig::InfraLocation>

The subdirectory with various infrastructure files (C<texlive.tlpdb>,
tlpobj files, ...) relative to the root of the installation; currently
C<tlpkg>.

=item C<$TeXLive::TLConfig::DatabaseName>

The name of our so-called database file: C<texlive.tlpdb>. It's just a
plain text file, not any kind of relational or other database.

=item C<$TeXLive::TLConfig::DatabaseLocation>

Concatenation of C<InfraLocation> "/" C<DatabaseName>, i.e.,
C<tlpkg/texlive.tlpdb>.

=item C<$TeXLive::TLConfig::BlockSize>

The assumed block size, currently 4k.

=item C<$TeXLive::TLConfig::Archive>
=item C<$TeXLive::TLConfig::TeXLiveURL>

These values specify where to find packages.

=item C<$TeXLive::TLConfig::TeXLiveServerURL>
=item C<$TeXLive::TLConfig::TeXLiveServerURLRegexp>
=item C<$TeXLive::TLConfig::TeXLiveServerPath>

C<TeXLiveURL> is concatenated from these values, with a string between.
The defaults are respectively, C<https://mirror.ctan.org> and
C<systems/texlive/tlnet/>.

=item C<@TeXLive::TLConfig::CriticalPackagesList>
=item C<@TeXLive::TLConfig::CriticalPackagesRegexp>

A list of all those packages which we do not update regularly since they
are too central, currently texlive.infra and (for Windows) tlperl.win32.

=item C<$TeXLive::TLConfig::RelocTree>

The texmf-tree name that can be relocated, defaults to C<texmf-dist>.

=item C<$TeXLive::TLConfig::RelocPrefix>

The string that replaces the C<RelocTree> in the tlpdb if a package is
relocated, defaults to C<RELOC>".

=back

=head1 SEE ALSO

All the other TeX Live modules and scripts, especially C<tlmgr> and
C<install-tl>, and the documentation in the repository:
C<Master/tlpkg/doc/>.

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
