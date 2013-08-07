use strict;
use warnings FATAL => 'all';

package MarpaX::Database::Terminfo;
use MarpaX::Database::Terminfo::Grammar;
use MarpaX::Database::Terminfo::Grammar::CharacterClasses;
use Marpa::R2;

# ABSTRACT: Parse a terminfo data base using Marpa

use Log::Any qw/$log/;
use Carp qw/croak/;

our $VERSION = '0.001'; # VERSION


our $I_CONSTANT = qr/(?:(0[xX][a-fA-F0-9]+(?:[uU](?:ll|LL|[lL])?|(?:ll|LL|[lL])[uU]?)?)             # Hexadecimal
                      |([1-9][0-9]*(?:[uU](?:ll|LL|[lL])?|(?:ll|LL|[lL])[uU]?)?)                    # Decimal
                      |(0[0-7]*(?:[uU](?:ll|LL|[lL])?|(?:ll|LL|[lL])[uU]?)?)                        # Octal
                      |([uUL]?'(?:[^'\\\n]|\\(?:[\'\"\?\\abfnrtv]|[0-7]{1..3}|x[a-fA-F0-9]+))+')    # Character
                    )/x;

#
# It is important to have LONGNAME before ALIAS because LONGNAME will do a lookahead on COMMA
# It is important to have NUMERIC and STRING before BOOLEAN because BOOLEAN is a subset of them
#
our @TOKENSRE = (
    [ 'ALIASINCOLUMNONE' , qr/\G^(\p{MarpaX::Database::Terminfo::Grammar::CharacterClasses::InAlias}+)/ ],
    [ 'PIPE'             , qr/\G(\|)/ ],
    [ 'LONGNAME'         , qr/\G(\p{MarpaX::Database::Terminfo::Grammar::CharacterClasses::InLongname}+), ?/ ],
    [ 'ALIAS'            , qr/\G(\p{MarpaX::Database::Terminfo::Grammar::CharacterClasses::InAlias}+)/ ],
    [ 'NUMERIC'          , qr/\G(\p{MarpaX::Database::Terminfo::Grammar::CharacterClasses::InName}+#$I_CONSTANT)/ ],
    [ 'STRING'           , qr/\G(\p{MarpaX::Database::Terminfo::Grammar::CharacterClasses::InName}+=\p{MarpaX::Database::Terminfo::Grammar::CharacterClasses::InIsPrintExceptComma}+)/ ],
    [ 'BOOLEAN'          , qr/\G(\p{MarpaX::Database::Terminfo::Grammar::CharacterClasses::InName}+)/ ],
    [ 'COMMA'            , qr/\G(, ?)/ ],
    [ 'WS_many'          , qr/\G( +)/ ],
    );

my %events = (
    'MAXMATCH' => sub {
        my ($recce, $bufferp, $string, $start, $length) = @_;

	my @expected = @{$recce->terminals_expected()};
	my $prev = pos(${$bufferp});
	pos(${$bufferp}) = $start;
	my $ok = 0;
	if ($log->is_debug) {
	    $log->debugf('Expected terminals: %s', \@expected);
	}
	foreach (@TOKENSRE) {
	    my ($token, $re) = @{$_};
	    if ((grep {$_ eq $token} @expected) && ${$bufferp} =~ $re) {
		$length = $+[1] - $-[1];
		$string = substr(${$bufferp}, $start, $length);
		if ($log->is_debug) {
		    $log->debugf('lexeme_read(\'%s\', %d, %d, \"%s\")', $token, $start, $length, $string);
		}
		$recce->lexeme_read($token, $start, $length, $string);
		$ok = 1;
		last;
	    }
	}
	die "Unmatched token in @expected" if (! $ok);
	pos(${$bufferp}) = $prev;
    },
);


# ----------------------------------------------------------------------------------------

sub new {
  my $class = shift;

  my $self = {};

  my $grammarObj = MarpaX::Database::Terminfo::Grammar->new(@_);
  $self->{_G} = Marpa::R2::Scanless::G->new({source => \$grammarObj->content, bless_package => __PACKAGE__});
  $self->{_R} = Marpa::R2::Scanless::R->new({grammar => $self->{_G}});

  bless($self, $class);

  return $self;
}
# ----------------------------------------------------------------------------------------

sub parse {
    my ($self, $bufferp) = @_;

    my $max = length(${$bufferp});
    for (
        my $pos = $self->{_R}->read($bufferp);
        $pos < $max;
        $pos = $self->{_R}->resume()
    ) {
        my ($start, $length) = $self->{_R}->pause_span();
        my $str = substr(${$bufferp}, $start, $length);
        for my $event_data (@{$self->{_R}->events}) {
            my ($name) = @{$event_data};
            my $code = $events{$name} // die "no code for event $name";
            $self->{_R}->$code($bufferp, $str, $start, $length);
        }
    }

    return $self;
}
# ----------------------------------------------------------------------------------------
# ----------------------------------------------------------------------------------------

sub value {
    my ($self) = @_;

    my $rc = $self->{_R}->value();

    #
    # Another parse tree value ?
    #
    if (defined($self->{_R}->value())) {
	my $msg = 'Ambigous parse tree detected';
	if ($log->is_fatal) {
	    $log->fatalf('%s', $msg);
	}
	croak $msg;
    }
    if (! defined($rc)) {
	my $msg = 'Parse tree failure';
	if ($log->is_fatal) {
	    $log->fatalf('%s', $msg);
	}
	croak $msg;
    }
    return $rc
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

MarpaX::Database::Terminfo - Parse a terminfo data base using Marpa

=head1 VERSION

version 0.001

=head1 SYNOPSIS

    use strict;
    use warnings FATAL => 'all';
    use MarpaX::Database::Terminfo;
    use Log::Log4perl qw/:easy/;
    use Log::Any::Adapter;
    use Log::Any qw/$log/;
    #
    # Init log
    #
    our $defaultLog4perlConf = '
    log4perl.rootLogger              = WARN, Screen
    log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.stderr  = 0
    log4perl.appender.Screen.layout  = PatternLayout
    log4perl.appender.Screen.layout.ConversionPattern = %d %-5p %6P %m{chomp}%n
    ';
    Log::Log4perl::init(\$defaultLog4perlConf);
    Log::Any::Adapter->set('Log4perl');
    #
    # Parse terminfo
    #
    my $terminfoSourceCode = "ansi|ansi/pc-term compatible with color,\n\tmc5i,\n";
    my $terminfoAstObject = MarpaX::Database::Terminfo->new();
    $terminfoAstObject->parse(\$terminfoSourceCode)->value;

=head1 DESCRIPTION

This module parses a terminfo database and produces an AST from it. If you want to enable logging, be aware that this module is a Log::Any thingy.

The grammar is the one found at L<http://nixdoc.net/man-pages/HP-UX/man4/terminfo.4.html#Formal%20Grammar>.

=head1 SUBROUTINES/METHODS

=head2 new($class)

Instantiate a new object. Takes no parameter.

=head2 parse($self, $bufferp)

Parses a terminfo database. Takes a pointer to a string as parameter.

=head2 value($self)

Returns Marpa's value on the parse tree. Ambiguous parse tree result is disabled and the module will croak if this happen.

=for :stopwords cpan testmatrix url annocpan anno bugtracker rt cpants kwalitee diff irc mailto metadata placeholders metacpan

=head1 SUPPORT

=head2 Bugs / Feature Requests

Please report any bugs or feature requests through the issue tracker
at L<https://rt.cpan.org/Public/Dist/Display.html?Name=MarpaX-Database-Terminfo>.
You will be notified automatically of any progress on your issue.

=head2 Source Code

This is open source software.  The code repository is available for
public review and contribution under the terms of the license.

L<https://github.com/jddurand/marpax-database-terminfo>

  git clone git://github.com/jddurand/marpax-database-terminfo.git

=head1 AUTHOR

Jean-Damien Durand <jeandamiendurand@free.fr>

=head1 CONTRIBUTOR

jddurand <jeandamiendurand@free.fr>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Jean-Damien Durand.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
