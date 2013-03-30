#!/usr/bin/env perl

use strict;
use warnings;
use Pegex;
use Term::ReadLine;
use Data::Printer { max_depth => 0 };
# Pegex::Grammar::Atoms
# Pegex::Grammar
# Pegex::Syntax

my $grammar = <<'END'

top: stmt*
stmt: expr endstmt
expr: add_sub | assign
assign: variable opassign add_sub
add_sub: mul_div+ % /~([<PLUS><DASH>])~/
mul_div: token+ % /~([<STAR><SLASH>])~/
token: /~<LPAREN>~/ expr /~<RPAREN>~/ | number | variable !opassign

# Lexemes
number: w /(<DASH>?<DIGIT>+)/ w
variable: w /([a-z])/ w
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


my $calculator = pegex($grammar, receiver => 'Calculator');
my $pegex_tree = pegex($grammar, receiver => 'Pegex::Tree');

my $term = Term::ReadLine->new('Calculator', \*STDIN, \*STDOUT);
$term->ornaments(0);

while ( defined ($_ = $term->readline('> ')) ) {
	chomp(my $expr = $_);
	my $result = eval { [ $calculator->parse($expr), $pegex_tree->parse($expr) ] };
	if($@) {
		print $@
	} else {
		for my $statement (0..@{$result->[0]}) {
			my $calc = Pegex::Tree->flatten($result->[0])->[$statement];
			next unless defined $calc;
			my $tree_str = $result->[1]->[$statement]->[0];
			my $comment_tree = p( $tree_str ) =~ s/^/#/gmr;
			print "$calc\n";
			#print "$comment_tree\n";
		}
	}
}

__END__
use Scalar::Util qw/blessed/;
use Forest::Tree::Writer::ASCIIWithBranches;
use Forest::Tree::Writer::SimpleASCII;
{
	package CalculatorTree;
	use base 'Pegex::Tree';
	use Forest::Tree;

	sub got_add_sub {
		my ($self, $list) = @_;
		$self->flatten($list);
		my $right = Forest::Tree->new( node => pop @$list );
		push @$list, $right;
		while (@$list > 1) {
			my ($a, $op, $t_b) = splice(@$list, -3);
			my $new_root = Forest::Tree->new( node => $op );
			my $t_a = Forest::Tree->new( node => $a );
			$new_root->add_children($t_a, $t_b);
			push @$list, $new_root;
		}
		pop @$list;
	}

	sub got_mul_div {
		my ($self, $list) = @_;
		$self->flatten($list);
		my $right = Forest::Tree->new( node => pop @$list );
		push @$list, $right;
		while (@$list > 1) {
			my ($a, $op, $t_b) = splice(@$list, -3);
			my $new_root = Forest::Tree->new( node => $op );
			my $t_a = Forest::Tree->new( node => $a );
			$new_root->add_children($t_a, $t_b);
			push @$list, $new_root;
		}
		pop @$list;
	}

	sub got_assign {
	}
}
		for my $tree (@{$result->[0]}) {
			next unless blessed $tree;
			use DDP; p $tree;
			use DDP; p $tree->get_child_at(0)->node;
			my $w = Forest::Tree::Writer::ASCIIWithBranches->new(tree => $tree);
			#my $w = Forest::Tree::Writer::SimpleASCII->new(tree => $tree);
			print $w;
			print $w->as_string;
			$tree->visit(sub {
				my $t = shift;
				print $t->depth, "\n";
				print(('    ' x ($t->depth + 1)) . ($t->node || '\undef') . "\n");
			});
		}
# vim: ts=4
