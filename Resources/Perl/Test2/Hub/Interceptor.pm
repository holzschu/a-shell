package Test2::Hub::Interceptor;
use strict;
use warnings;

our $VERSION = '1.302175';


use Test2::Hub::Interceptor::Terminator();

BEGIN { require Test2::Hub; our @ISA = qw(Test2::Hub) }
use Test2::Util::HashBase;

sub init {
    my $self = shift;
    $self->SUPER::init();
    $self->{+NESTED} = 0;
}

sub inherit {
    my $self = shift;
    my ($from, %params) = @_;

    $self->{+NESTED} = 0;

    if ($from->{+IPC} && !$self->{+IPC} && !exists($params{ipc})) {
        my $ipc = $from->{+IPC};
        $self->{+IPC} = $ipc;
        $ipc->add_hub($self->{+HID});
    }
}

sub terminate {
    my $self = shift;
    my ($code) = @_;

    eval {
        no warnings 'exiting';
        last T2_SUBTEST_WRAPPER;
    };
    my $err = $@;

    # Fallback
    die bless(\$err, 'Test2::Hub::Interceptor::Terminator');
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Hub::Interceptor - Hub used by interceptor to grab results.

=head1 SOURCE

The source code repository for Test2 can be found at
F<http://github.com/Test-More/test-more/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2019 Chad Granum E<lt>exodist@cpan.orgE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
