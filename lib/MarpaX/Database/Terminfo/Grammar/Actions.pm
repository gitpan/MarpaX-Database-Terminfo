use strict;
use warnings FATAL => 'all';

package MarpaX::Database::Terminfo::Grammar::Actions;
use MarpaX::Database::Terminfo::Grammar::Regexp qw/%TOKENSRE/;
use Carp qw/carp/;
use Log::Any qw/$log/;

# ABSTRACT: Terminfo grammar actions

our $VERSION = '0.005'; # VERSION



sub new {
    my $class = shift;
    my $self = {_terminfo => [undef]};
    bless($self, $class);
    return $self;
}


sub value {
    my ($self) = @_;
    #
    # Remove the last that was undef
    #
    pop(@{$self->{_terminfo}});

    return $self->{_terminfo};
}


sub endTerminfo {
    my ($self) = @_;
    push(@{$self->{_terminfo}}, undef);
}

sub _getTerminfo {
    my ($self) = @_;

    if (! defined($self->{_terminfo}->[-1])) {
	$self->{_terminfo}->[-1] = {alias => [], longname => '', feature => {}};
    }
    return $self->{_terminfo}->[-1];
}

sub _pushFeature {
    my ($self, $type, $feature, $value) = @_;

    my $terminfo = $self->_getTerminfo;

    if (exists($terminfo->{feature}->{$feature})) {
	$log->warnf('%s %s: feature %s overwriten', $terminfo->{alias} || [], $terminfo->{longname} || '', $feature);
    }
    $terminfo->{feature}->{$feature} = {type => $type, value => $value};
}


sub longname {
    my ($self, $longname) = @_;
    $self->_getTerminfo->{longname} = $longname;
}


sub alias {
    my ($self, $alias) = @_;
    push(@{$self->_getTerminfo->{alias}}, $alias);
}


sub boolean {
    my ($self, $boolean) = @_;
    return $self->_pushFeature(0, $boolean, undef);
}


sub numeric {
    my ($self, $numeric) = @_;

    $numeric =~ /$TOKENSRE{NUMERIC}/;
    return $self->_pushFeature(1, substr($numeric, $-[2], $+[2] - $-[2]), substr($numeric, $-[3], $+[3] - $-[3]));
}


sub string {
    my ($self, $string) = @_;

    $string =~ /$TOKENSRE{STRING}/;
    return $self->_pushFeature(3, substr($string, $-[2], $+[2] - $-[2]), substr($string, $-[3], $+[3] - $-[3]));
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

MarpaX::Database::Terminfo::Grammar::Actions - Terminfo grammar actions

=head1 VERSION

version 0.005

=head1 DESCRIPTION

This modules give the actions associated to terminfo grammar.

=head2 new($class)

Instance a new object.

=head2 value($self)

Return a parse-tree value.

=head2 endTerminfo($self)

Push a new terminfo placeholder.

=head2 longname($self, $longname)

"longname" action.

=head2 alias($self, $alias)

"alias" action.

=head2 boolean($self, $boolean)

"boolean" action.

=head2 numeric($self, $numeric)

"numeric" action.

=head2 string($self, $string)

"string" action.

=head1 AUTHOR

Jean-Damien Durand <jeandamiendurand@free.fr>

=head1 CONTRIBUTOR

jddurand <jeandamiendurand@free.fr>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Jean-Damien Durand.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
