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
    @staticmethod
    def add(a: int, b: int) -> int:
        if (a < 0 or b < 0):
            raise NegativeNumbers("Numbers cannot be negative")
            return
        c = a + b
        if (c < a or c < b):
            raise AdditionOverFlowError("Addition overflow occured.")
            return
        else:
            return c

    @staticmethod
    def sub(a: int, b: int) -> int:
        if (a < 0 or b < 0):
            raise NegativeNumbers("Numbers cannot be negative.")
            return
        if b > a:
            raise SubtractionOverFlowError("First argument must be greater than the second.")
            return
        else:
            c = a - b
            return c

    @staticmethod
    def mul(a: int, b: int) -> int:
        if (a == 0):
            return 0
        if (a < 0 or b < 0):
            raise NegativeNumbers("Numbers cannot be negative")
        c = a * b
        if (c // a != b):
            raise MultiplicationOverFlowError
        else:
            return c

    @staticmethod
    def div(a: int, b: int) -> int:
        if (a < 0 or b < 0):
            raise NegativeNumbers("Numbers cannot be negative")
        if (b == 0):
            raise DivisionByZero("The divisor can not be zero")
        c = a // b
        return c

    @staticmethod
    def mod(a: int, b: int) -> int:
        if (a < 0 or b < 0):
            raise NegativeNumbers("Numbers cannot be negative")
        if (b == 0):
            raise ModuloByZeroError
        else:
            c = a % b
            return c
