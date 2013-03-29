#!/usr/bin/python

import sys
from pyparsing import *
import readline
import operator
import string

ParserElement.enablePackrat()
ParserElement.setDefaultWhitespaceChars(' \t') # enable whitespace

stack = []
variables = [0]*26 # fill with 0s

opTable = {
		"+": operator.add,
		"-": operator.sub,
		"*": operator.mul,
		"/": operator.truediv }

def pushStack( s, loc, toks ):
	#print toks
	if len(toks):
		stack.append( toks[0] )
def pushAssign( s, loc, toks ):
	if len(toks) > 1:
		stack.append( toks[0] )
		stack.append( toks[1] )

def evalGlobalStack( s, loc, toks ):
	#print stack
	if len(stack):
		print evalStackLinear( stack )

def evalStackLinear( s ):
	my_stack = []
	while len(s) > 0:
		op = s.pop(0)
		if op in "+-*/": # an arithmetic operation
			oper1 = getOpAsNumber(my_stack.pop())
			oper2 = getOpAsNumber(my_stack.pop())
			my_stack.append( opTable[op](oper1, oper2) )
		elif op in '=': # a variable
			var = my_stack.pop()
			if not var.isalpha():
				raise Exception( "Expected variable for assignement. Got %s " % ( var ) )
			rest = getOpAsNumber(my_stack.pop())
			variables[ ord(var) - ord('a') ] = rest # store variable
			my_stack.append( rest )
		else:
			my_stack.append( op )
	return getOpAsNumber(my_stack.pop())

def getOpAsNumber( op ):
	ret = 0
	try:
		ret = variables[ ord(op) - ord('a') ]
	except:
		try:
			ret = float(op)
		except:
			raise Exception('What are you playing at? I wanted an number or variable, but all I got was this %s' % ( op ) )
	return ret

# Lexemes
Number = Word( nums )
Variable = Word( string.lowercase, max=1 )

OpPlus = Word( "+" )
OpMinus = Word( "-" )
OpTimes = Word( "*" )
OpDivide = Word( "/" )

OpAssign = Word( "=" )
OpAdd = ( OpPlus | OpMinus )
OpMult = ( OpTimes | OpDivide )

ParenOpen = Word( "(" ).suppress()
ParenClose = Word( ")" ).suppress()

Exit = Word( 'exit' ) | Word( 'quit' )

EOL = ( LineEnd() | Word( ';' ) ).suppress() # do not put in tokens

Value = Forward() # placeholder

Product = Value + ZeroOrMore( OpMult + Value  ).setParseAction( pushStack )
Sum =  Product + ZeroOrMore( OpAdd + Product ).setParseAction( pushStack )

Expr = ( Variable + OpAssign + Sum ).setParseAction( pushAssign ) \
		| Sum
Value << ( Number \
	| ( Variable + ~OpAssign ) \
	| ( ParenOpen + Expr.suppress() + ParenClose ) ).setParseAction( pushStack ) 
	# set forwarded non-terminal
	# ( the parentheses are necessary because << has higher precedence than | )

Statement = ( Expr + EOL ).setParseAction( evalGlobalStack ) \
		| ( Exit + EOL ).setParseAction( lambda: sys.exit(0) ) \
		| EOL

Top = ZeroOrMore( Statement )

while True:
	try:
		line = raw_input('> ')
	except:
		break

	try:
		Top.parseString(line)
	except Exception, e:
		print e
		print "error"


# Bonus!
def evalStackRecursive( s ):
	op = s.pop()
	if op in "+-*/": # an arithmetic operation
		oper1 = evalStackRecursive( s )
		oper2 = evalStackRecursive( s )
		return opTable[op](oper1, oper2)
	elif op.isalpha(): # a variable
		return variables[ ord(op) - ord('a') ] # look up variable
	elif op in '=': # a variable
		var = s.pop()
		if not var.isalpha():
			raise Exception( "Expected variable for assignement. Got %s " % ( var ) )
		rest = evalStackRecursive( s )
		variables[ ord(var) - ord('a') ] = rest # store variable
		return rest
	elif op.isdigit():
		return float( op )
	else:
		return 0
