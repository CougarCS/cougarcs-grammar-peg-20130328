#!/usr/bin/env perl

use strict;
use warnings;
use Pegex;
use Term::ReadLine;
use Data::Printer { max_depth => 0 };
# Pegex::Grammar::Atoms
# Pegex::Grammar
# Pegex::Syntax
use Forest::Tree::Writer::ASCIIWithBranches;
use Forest::Tree::Writer::SimpleASCII;

my $grammar = <<'END'

top: stmt*
stmt: expr endstmt
expr: add_sub | assign
assign: variable opassign add_sub
add_sub: mul_div+ % opadd
mul_div: token+ % opmult
token: /~<LPAREN>~/ expr /~<RPAREN>~/ | number | variable !opassign

# Lexemes
number: w /(<DASH>?<DIGIT>+)/ w
variable: w /([a-z])/ w
opadd: w /([<PLUS><DASH>])/ w
opmult: w /([<STAR><SLASH>])/ w
opassign: w /([<EQUAL>])/ w
endstmt: w /<EOL>|[<SEMI>]|<EOS>/ w
w: /[<SPACE><TAB>]*/

END
;

my $variables = [ (0) x 26 ]; # used in get_op_as_number and actions
{
	package Calculator;
	use base 'Pegex::Tree';

	sub got_add_sub {
		my ($self, $list) = @_;
		$self->flatten($list);
		while (@$list > 1) {
			my ($a, $op, $b) = splice(@$list, 0, 3);
			unshift @$list, ($op eq '+') ?
				($self->get_op_as_number($a) + $self->get_op_as_number($b))
				: ($self->get_op_as_number($a) - $self->get_op_as_number($b));
		}
		@$list;
	}

	sub got_mul_div {
		my ($self, $list) = @_;
		$self->flatten($list);
		while (@$list > 1) {
			my ($a, $op, $b) = splice(@$list, 0, 3);
			unshift @$list, ($op eq '*') ?
				($self->get_op_as_number($a) * $self->get_op_as_number($b))
				: ($self->get_op_as_number($a) / $self->get_op_as_number($b));
		}
		if(@$list == 1 and $list->[0] =~ /[a-z]/) { # if the list was just a single variable
			$list->[0] = $self->get_op_as_number($list->[0])
		}
		@$list;
	}

	sub get_op_as_number {
			my ($self, $op) = @_;
			if( $op =~ /[a-z]/) {
					return $variables->[ord($op) - ord('a')];
			}
			return $op;
	}

	sub got_assign {
		my ($self, $list) = @_;
		$self->flatten($list);
		my ($a, $eq, $b) = splice(@$list, 0, 3);
		$variables->[ord($a) - ord('a')] = $self->get_op_as_number($b);
		push $list, $variables->[ord($a) - ord('a')];
		@$list;
	}
}
{
	package CalculatorTree;
	use base 'Pegex::Tree';
	use Scalar::Util qw/blessed/;
	use Forest::Tree;

	sub build_nodes {
		my ($self, $list) = @_;
		[ map { Forest::Tree->new( node => $_ ) } @$list ];
	}

	sub got_number {
		my ($self, $list) = @_;
		$self->build_nodes($list);
	}
	sub got_variable {
		my ($self, $list) = @_;
		$self->build_nodes($list);
	}
	sub got_opadd {
		my ($self, $list) = @_;
		$self->build_nodes($list);
	}
	sub got_opassign {
		my ($self, $list) = @_;
		$self->build_nodes($list);
	}
	sub got_opmult {
		my ($self, $list) = @_;
		$self->build_nodes($list);
	}


	sub op_tree {
		my ($self, $list) = @_;
		$self->flatten($list);
		my $root = shift @$list;
		while (@$list > 1) {
			my ($op, $b) = splice(@$list, 0, 2);
			$op->add_children($root);
			$op->add_children($b);
			$root = $op;
		}
		$root;
	}

	sub got_add_sub {
		my ($self, $list) = @_;
		$self->op_tree($list);
	}

	sub got_mul_div {
		my ($self, $list) = @_;
		$self->op_tree($list);
	}

	sub got_assign {
		my ($self, $list) = @_;
		$self->op_tree($list);
	}
}


my $calculator = pegex($grammar, receiver => 'Calculator');
my $pegex_tree = pegex($grammar, receiver => 'Pegex::Tree');
my $calc_tree = pegex($grammar, receiver => 'CalculatorTree');

my $term = Term::ReadLine->new('Calculator', \*STDIN, \*STDOUT); # we want stdin to be redirectable
$term->ornaments(0); # no underline

while ( defined ($_ = $term->readline('> ')) ) {
	chomp(my $expr = $_);
	my $result = eval { [ $calculator->parse($expr), $pegex_tree->parse($expr), $calc_tree->parse($expr) ] };
	if($@) {
		print $@
	} else {
		for my $statement (0..@{$result->[0]}) {
			my $calc = Pegex::Tree->flatten($result->[0])->[$statement];
			next unless defined $calc;
			my $ptree = $result->[1]->[$statement]->[0];
			my $comment_ptree = p( $ptree ) =~ s/^/#/gmr;
			my $ctree = $result->[2]->[$statement]->[0];
			#my $ctree_write = Forest::Tree::Writer::ASCIIWithBranches->new(tree => $ctree);
			my $ctree_write = Forest::Tree::Writer::SimpleASCII->new(tree => $ctree);
			print "$calc\n";
			print $ctree_write->as_string =~ s/^/# /gmr;
		}
	}
}
