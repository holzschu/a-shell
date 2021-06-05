package ExtUtils::CBuilder::Platform::darwin;

use warnings;
use strict;
use ExtUtils::CBuilder::Platform::Unix;

our $VERSION = '0.280234'; # VERSION
our @ISA = qw(ExtUtils::CBuilder::Platform::Unix);

sub compile {
  my $self = shift;
  my $cf = $self->{config};

  # -flat_namespace isn't a compile flag, it's a linker flag.  But
  # it's mistakenly in Config.pm as both.  Make the correction here.
  local $cf->{ccflags} = $cf->{ccflags};
  $cf->{ccflags} =~ s/-flat_namespace//;
  $self->SUPER::compile(@_);
}


1;
