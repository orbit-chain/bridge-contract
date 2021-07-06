from iconservice import *

# ================================================
#  Exceptions
# ================================================
class SenderNotScoreOwnerError(Exception):
	pass

class SenderNotWalletOwnerError(Exception):
	pass

class NotAFunctionError(Exception):
	pass

class SenderNotMinterError(Exception):
	pass


def only_wallet(func):
	if not isfunction(func):
		raise NotAFunctionError

	@wraps(func)
	def __wrapper(self: object, *args, **kwargs):
		if self.msg.sender != self.address:
			raise SenderNotWalletOwnerError(self.address)

		return func(self, *args, **kwargs)
	return __wrapper


def only_owner(func):
	if not isfunction(func):
		raise NotAFunctionError

	@wraps(func)
	def __wrapper(self: object, *args, **kwargs):
		if self.msg.sender != self.owner:
			raise SenderNotScoreOwnerError(self.owner)

		return func(self, *args, **kwargs)
	return __wrapper


def only_minter(func):
	if not isfunction(func):
		raise NotAFunctionError

	@wraps(func)
	def __wrapper(self: object, *args, **kwargs):
		if self.msg.sender not in self._minters_list:
			raise SenderNotMinterError(self.msg.sender)

		return func(self, *args, **kwargs)
	return __wrapper


def only_burner(func):
	if not isfunction(func):
		raise NotAFunctionError

	@wraps(func)
	def __wrapper(self: object, *args, **kwargs):
		if self.msg.sender not in self._burners_list:
			raise SenderNotMinterError(self.msg.sender)

		return func(self, *args, **kwargs)
	return __wrapper


def only_pauser(func):
	if not isfunction(func):
		raise NotAFunctionError

	@wraps(func)
	def __wrapper(self: object, *args, **kwargs):
		if self.msg.sender not in self._pausers_list:
			raise SenderNotMinterError(self.msg.sender)

		return func(self, *args, **kwargs)
	return __wrapper


def catch_error(func):
	if not isfunction(func):
		raise NotAFunctionError

	@wraps(func)
	def __wrapper(self: object, *args, **kwargs):
		try:
			return func(self, *args, **kwargs)
		except Exception as e:
			Logger.error(repr(e), TAG)
			try:
				# readonly methods cannot emit eventlogs
				self.ShowException(repr(e))
			except:
				pass
			revert(repr(e))

	return __wrapper
