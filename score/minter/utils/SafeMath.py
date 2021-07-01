class AdditionOverFlowError(Exception):
	pass

class SubtractionOverFlowError(Exception):
	pass

class MultiplicationOverFlowError(Exception):
	pass

class DivisionByZero(Exception):
	pass

class ModuloByZeroError(Exception):
	pass

class NegativeNumbers(Exception):
	pass


class SafeMath:
	'''
	Wrapper over arithmetic operations in python with added overflow checks.
	'''

	def add(a: int, b: int) -> int:
		'''
		Returns the sum of two unsigned integers after overflow check.

		Counterpart to default `+` operator in python.
		
		:param a: The first number. 
		:param b: The second number.
		:return Sum of `a` and `b`

		Raise
		NegativeNumbers
			If `a` or `b` is negative.
		AdditionOverFlowError
			In case of overflow.
			It occurs for extremely large values.

		>>> add(2,3)
		5
		'''
		if (a < 0 or b < 0):
			raise NegativeNumbers("Numbers cannot be negative")
			return
		c = a + b
		if (c < a or c < b):
			raise AdditionOverFlowError("Addition overflow occured.")
			return
		else:
			return c

	def sub(a: int, b: int) -> int:
		'''
		Returns the difference of two unsigned integers, reverting when the result is neagtive.

		Counterpart to default `-` operator in python.
		
		:param a: The first number. 
		:param b: The second number.
		:return Difference of `a` and `b` if `a` > `b`

		Raise
		NegativeNumbers
			If `a` or `b` is negative.
		SubtractionOverFlowError
			If `a`+`b` greater than `a`.

		>>> sub(3,2)
		1
		>>> sub(3,4)
		SubtractionOverFlowError: First argument must be greater than the second.
		'''
		if (a < 0 or b < 0):
			raise NegativeNumbers("Numbers cannot be negative.")
			return
		if b > a:
			raise SubtractionOverFlowError("First argument must be greater than the second.")
			return
		else:
			c = a - b
			return c

	def mul(a: int, b: int) -> int:
		'''
		Returns the product of two unsigned integers, reverting in case of overflow.

		Counterpart to default `*` operator in python.
		
		:param a: The first number, multiplicand. 
		:param b: The second number, multiplier.
		:return Product of `a` and `b` after checks.

		Raise
		NegativeNumbers
			If `a` or `b` is negative.
		MultiplicationOverFlowError
			In case of overflow.
			It occurs for extremely large values.

		>>> mul(3,2)
		6
		'''
		if (a == 0):
			return 0
		if (a < 0 or b < 0):
			raise NegativeNumbers("Numbers cannot be negative")
		c = a * b
		if (c // a != b):
			raise MultiplicationOverFlowError
		else:
			return c

	def div(a: int, b: int) -> int:
		'''
		Returns the integer division of two unsigned integers,
		reverting if the divisor is zero.
		The result is rounded towards zero.

		Counterpart to default `/` operator in python.
		
		:param a: The dividend. 
		:param b: The divisor.
		:return Floor division (quotient) of `a` and `b` after checks.

		Raise
		NegativeNumbers
			If `a` or `b` is negative.
		DivisionByZero
			If the divisor i.e. `b` is zero.

		>>> div(4,2)
		2
		'''
		if (a < 0 or b < 0):
			raise NegativeNumbers("Numbers cannot be negative")
		if (b == 0):
			raise DivisionByZero("The divisor can not be zero")
		c = a // b
		return c

	def mod(a: int, b: int) -> int:
		'''
		Returns the remainder of two unsigned integers,
		reverting if the divisor is zero.

		Counterpart to default `%` operator in python.
		
		:param a: The first unsigned integer. 
		:param b: The second unsigned integer.
		:return Modulo of `a` and `b`.

		Raise
		NegativeNumbers
			If `a` or `b` is negative.
		ModuloByZeroError
			If `b` is zero.

		>>> mod(3,2)
		1
		'''
		if (a < 0 or b < 0):
			raise NegativeNumbers("Numbers cannot be negative")
		if (b == 0):
			raise ModuloByZeroError
		else:
			c = a % b
			return c