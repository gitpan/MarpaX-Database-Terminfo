use strict;
use warnings FATAL => 'all';

package MarpaX::Database::Terminfo::Grammar;

# ABSTRACT: Terminfo grammar in Marpa BNF

our $VERSION = '0.003'; # VERSION


sub new {
  my $class = shift;

  my $self = {};

  $self->{_content} = do {local $/; <DATA>};

  bless($self, $class);

  return $self;
}


sub content {
    my ($self) = @_;
    return $self->{_content};
}


1;

=pod

=encoding utf-8

=head1 NAME

MarpaX::Database::Terminfo::Grammar - Terminfo grammar in Marpa BNF

=head1 VERSION

version 0.003

=head1 SYNOPSIS

    use MarpaX::Database::Terminfo::Grammar;

    my $grammar = MarpaX::Database::Terminfo::Grammar->new();
    my $grammar_content = $grammar->content();

=head1 DESCRIPTION

This modules returns Terminfo grammar written in Marpa BNF.

=head1 SUBROUTINES/METHODS

=head2 new($class)

Instance a new object.

=head2 content($self)

Returns the content of the grammar.

=head1 SEE ALSO

L<Marpa::R2>

=head1 AUTHOR

Jean-Damien Durand <jeandamiendurand@free.fr>

=head1 CONTRIBUTOR

jddurand <jeandamiendurand@free.fr>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Jean-Damien Durand.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

__DATA__
# -------------------------------------------------------------------------
# G1 As per:
# - http://nixdoc.net/man-pages/HP-UX/man4/terminfo.4.html#Formal%20Grammar
# - annotated modifications as per ncurses-5.9 documentation
# -------------------------------------------------------------------------
:default ::= action => [values] bless => ::lhs

:start ::= terminfoList

terminfoList ::= terminfo+

#
# Ncurses: restOfHeaderLine is optional
#
terminfo ::= startOfHeaderLine restOfHeaderLine featureLines
           | startOfHeaderLine (comma newline) featureLines
           | (blankline)
           | (comment)

restOfHeaderLine ::= (pipe) longname (comma newline)
                   | aliases (pipe) longname (comma newline)

featureLines ::= featureLine+

featureLine ::= startFeatureLine features (comma newline)
              | startFeatureLine (comma newline)

startFeatureLine ::= startFeatureLineBoolean
                   | startFeatureLineNumeric
                   | startFeatureLineString

features ::= feature+

aliases ::= (pipe) alias
          | aliases (pipe) alias

feature ::= (comma) boolean
          | (comma) numeric
          | (comma) string

#
# Special cases
#
startOfHeaderLine       ::= aliasInColumnOne
startFeatureLineBoolean ::= (spaces) boolean
startFeatureLineNumeric ::= (spaces) numeric
startFeatureLineString  ::= (spaces) string

#
# G0
# --
PIPE                  ~ '|'
WS                    ~ [ \t]
WS_maybe              ~ WS
WS_maybe              ~
WS_any                ~ WS*
_WS_many               ~ WS+
WS_many               ~ _WS_many
COMMA                 ~ ',' WS_maybe
POUND                 ~ '#'
EQUAL                 ~ '='
_NEWLINE              ~ [\n]
#_NEWLINES             ~ _NEWLINE+
NEWLINE               ~ _NEWLINE
NOT_NEWLINE_any       ~ [^\n]*

_NAME                 ~ [\p{MarpaX::Database::Terminfo::Grammar::CharacterClasses::InName}]+
_ALIAS                ~ [\p{MarpaX::Database::Terminfo::Grammar::CharacterClasses::InAlias}]+
#
# Ncurses: , is allowed in the longname
#
_LONGNAME             ~ [\p{MarpaX::Database::Terminfo::Grammar::CharacterClasses::InNcursesLongname}]+
_INISPRINTEXCEPTCOMMA ~ [\p{MarpaX::Database::Terminfo::Grammar::CharacterClasses::InIsPrintExceptComma}]+

ALIAS                 ~ _ALIAS
ALIASINCOLUMNONE      ~ _ALIAS
LONGNAME              ~ _LONGNAME
BOOLEAN               ~ _NAME
NUMERIC               ~ _NAME POUND I_CONSTANT
STRING                ~ _NAME EQUAL _INISPRINTEXCEPTCOMMA
#
# Ncurses: STRING capability can be empty
#
STRING                ~ _NAME EQUAL
BLANKLINE             ~ WS_any _NEWLINE
COMMENT               ~ WS_any POUND NOT_NEWLINE_any _NEWLINE

alias                 ::= MAXMATCH | ALIAS
aliasInColumnOne      ::= MAXMATCH | ALIASINCOLUMNONE
longname              ::= MAXMATCH | LONGNAME
boolean               ::= MAXMATCH | BOOLEAN
numeric               ::= MAXMATCH | NUMERIC
string                ::= MAXMATCH | STRING
pipe                  ::= MAXMATCH | PIPE
comma                 ::= MAXMATCH | COMMA
newline               ::= MAXMATCH | NEWLINE
spaces                ::= MAXMATCH | WS_many
blankline             ::= MAXMATCH | BLANKLINE
comment               ::= MAXMATCH | COMMENT

#
# I_CONSTANT from C point of view
#
I_CONSTANT ~ HP H_many IS_maybe
           | NZ D_any IS_maybe
           | '0' O_any IS_maybe
           | CP_maybe QUOTE I_CONSTANT_INSIDE_many QUOTE
HP         ~ '0' [xX]
H          ~ [a-fA-F0-9]
H_many     ~ H+
LL         ~ 'll' | 'LL' | [lL]
LL_maybe   ~ LL
LL_maybe   ~
U          ~ [uU]
U_maybe    ~ U
U_maybe    ~
IS         ~ U LL_maybe | LL U_maybe
IS_maybe   ~ IS
IS_maybe   ~
NZ         ~ [1-9]
D          ~ [0-9]
D_any      ~ D*
O          ~ [0-7]
O_any      ~ O*
CP         ~ [uUL]
CP_maybe   ~ CP
CP_maybe   ~
QUOTE     ~ [']
I_CONSTANT_INSIDE ~ [^'\\\n]
I_CONSTANT_INSIDE ~ ES
I_CONSTANT_INSIDE_many ~ I_CONSTANT_INSIDE+
BS         ~ '\'
ES_AFTERBS ~ [\'\"\?\\abfnrtv]
           | O
           | O O
           | O O O
           | 'x' H_many
ES         ~ BS ES_AFTERBS
#
# Following http://stackoverflow.com/questions/17773976/prevent-naive-longest-token-matching-in-marpar2scanless we
# will always match a longer substring than the one originally wanted.
#
:lexeme ~ MAXMATCH pause => before event => MAXMATCH
MAXMATCH   ~ [\p{MarpaX::Database::Terminfo::Grammar::CharacterClasses::InIsPrintAndIsGraph}]+