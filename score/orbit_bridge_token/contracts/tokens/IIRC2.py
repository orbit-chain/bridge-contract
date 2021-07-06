from iconservice import *

# An interface of ICON Token Standard, IRC-2
class TokenStandard(ABC):
	@abstractmethod
	def name(self) -> str:
		'''
		Returns the name of the token 
		'''
		pass 

	@abstractmethod
	def symbol(self) -> str:
		'''
		Returns the symbol of the token 
		'''
		pass

	@abstractmethod
	def decimals(self) -> int:
		'''
		Returns the number of decimals
		'''
		pass

	@abstractmethod
	def totalSupply(self) -> int:
		'''
		Returns the total number of tokens in existence
		'''
		pass

	@abstractmethod
	def balanceOf(self, _owner: Address) -> int:
		'''
		Returns the amount of tokens owned by the account
		'''
		pass

	@abstractmethod
	def transfer(self, _to: Address, _value: int, _data: bytes = None):
		'''
		Transfers certain amount of tokens from sender to the reciever.
		'''
		pass

