from iconservice import *
from .IIRC3 import TokenStandard

TAG = 'IRC3'

class IRC3(IconScoreBase, TokenStandard):
    '''
    Implementation of IRC3
    '''
    _GOVERNANCE = 'governance'
    _MINTER = 'minter'
    _NAME = 'token_name'
    _SYMBOL = 'token_symbol'
    _TOTAL_SUPPLY = 'total_supply'
    _TOKENS_LIST = "tokens_list"
    _TOKEN_OWNER = "get_tokens_of_owner"
    _OWNED_TOKEN_COUNT = 'owned_token_count'  # Track token count against token owners
    _TOKEN_APPROVALS = "token_approvals"
    _TOKEN = "TOKEN"
    _ZERO_ADDRESS = Address.from_prefix_and_int(AddressPrefix.EOA, 0)

    def __init__(self, db: IconScoreDatabase) -> None:
        super().__init__(db)

        self._governance = VarDB(self._GOVERNANCE, db, value_type=Address)
        self._minter = VarDB(self._MINTER, db, value_type=Address)

        self._name = VarDB(self._NAME, db, value_type=str)
        self._symbol = VarDB(self._SYMBOL, db, value_type=str)
        self._total_supply = VarDB(self._TOTAL_SUPPLY, db, value_type=int)

        self._tokenList = DictDB(self._TOKENS_LIST, db, value_type=bool)
        self._ownedTokenCount = DictDB(self._OWNED_TOKEN_COUNT, db, value_type=int)
        self._tokenOwner = DictDB(self._TOKEN_OWNER, db, value_type=Address)
        self._tokenApprovals = DictDB(self._TOKEN_APPROVALS, db, value_type=Address)
        self._token = DictDB(self._TOKEN, db, depth=1, value_type=str)

    def on_install(self, _governance:Address, _minter:Address, _name:str, _symbol:str) -> None:
        super().on_install()

        self._total_supply.set(0)
        self._governance.set(_governance)
        self._minter.set(_minter)
        self._name.set(_name)
        self._symbol.set(_symbol)

    def on_update(self) -> None:
        super().on_update()

    @external(readonly=True)
    def name(self) -> str:
        return self._name.get()

    @external(readonly=True)
    def symbol(self) -> str:
        return self._symbol.get()

    @external(readonly=True)
    def totalSupply(self) -> int:
        return self._total_supply.get()

    @external(readonly=True)
    def balanceOf(self, _owner: Address) -> int:
        if _owner is None or self._is_zero_address(_owner):
            revert("Invalid owner")
        return self._ownedTokenCount[_owner]

    @external(readonly=True)
    def ownerOf(self, _tokenId: int) -> Address:
        self.is_valid(_tokenId)
        owner = self._tokenOwner[_tokenId]
        if owner is None:
            revert("Invalid _tokenId: Token with that id does not exist.")
        if self._is_zero_address(owner):
            revert("Invalid _tokenId: Token with that id was burned.")
        return owner

    @external(readonly=True)
    def getApproved(self, _tokenId: int) -> Address:
        self.is_valid(_tokenId)
        addr = self._tokenApprovals[_tokenId]
        if addr is None:
            return self._ZERO_ADDRESS
        return addr

    @external(readonly=True)
    def getToken(self, _tokenId:int) -> dict:
        self.is_valid(_tokenId)
        token = self._load_token(_tokenId)
        return token

    @external
    def transferOwnership(self, _governance: Address) -> None:
        if self.msg.sender != self._governance.get():
            raise InvalidMessageSender("Invalid Sender")

        self._governance.set(_governance)

    @external
    def setMinter(self, _minter: Address) -> None:
        if self.msg.sender != self._governance.get():
            raise InvalidMessageSender("Invalid Sender")

        self._minter.set(_minter)

    @eventlog(indexed=3)
    def Transfer(self, _from: Address, _to: Address, _tokenId: int):
        pass

    @eventlog(indexed=3)
    def Approval(self, _from: Address, _to: Address, _tokenId: int):
        pass

    @eventlog(indexed=1)
    def Mint(self, _tokenId:int):
        pass

    @eventlog(indexed=1)
    def Update(self, _tokenId:int):
        pass

    @eventlog(indexed=1)
    def Burn(self, _tokenId:int):
        pass

    @external
    def approve(self, _to:Address, _tokenId:int):
        owner = self.ownerOf(_tokenId)
        if _to == owner:
            revert("Cannot approve to yourself.")
        if self.msg.sender != owner:
            revert(" You do not own this token.")
        self._tokenApprovals[_tokenId] = _to
        self.Approval(owner, _to, _tokenId)

    @external
    def clear_approval(self, _tokenId:int):
        owner = self.ownerOf(_tokenId)
        if self.getApproved(_tokenId) == self._ZERO_ADDRESS:
            revert("Token has not been approved.")
        if self.msg.sender != owner:
            revert("You do not have permission to clear approval.")
        del self._tokenApprovals[_tokenId]

    @external
    def transfer(self, _to: Address, _tokenId: int):
        if self.msg.sender != self.ownerOf(_tokenId):
            revert("Only token owner can transfer tokens.")
        self._transfer(self.msg.sender, _to, _tokenId)

    @external
    def transferFrom(self, _from: Address, _to: Address, _tokenId: int):
        owner = self.ownerOf(_tokenId)
        if owner != _from:
            revert("_from does not own this token.")
        if self.msg.sender != self._tokenApprovals[_tokenId] and self.msg.sender != owner:
            revert("Only approved addresses can transfer.")
        self._transfer(_from, _to, _tokenId)

    def _transfer(self, _from: Address, _to: Address, _tokenId: int):
        self.is_valid(_tokenId)

        if _to is None or self._is_zero_address(_to):
            revert("Cannot transfer tokens to zero address.")

        del self._tokenApprovals[_tokenId]

        self._tokenOwner[_tokenId] = _to
        self._ownedTokenCount[_from] -= 1
        self._ownedTokenCount[_to] += 1

        self.Transfer(_from, _to, _tokenId)

    def _mint(self, _to: Address, _tokenId: int):
        if self.msg.sender != self._minter.get():
            revert("Invalid Sender")

        if self._tokenList[_tokenId] :
            revert(f"{_tokenId} is not valid. Token with id {_tokenId} already exists.")

        if _tokenId < 0 :
            revert(f"{_tokenId} is not valid.")

        self._total_supply.set(self._total_supply.get() + 1)
        self._ownedTokenCount[_to] += 1
        self._tokenList[_tokenId] = True
        self._tokenOwner[_tokenId] = _to

        self.Mint(_tokenId)
        self.Transfer(self._ZERO_ADDRESS, _to, _tokenId)

    def _burn(self, _from: Address, _tokenId: int):
        if self.msg.sender != self._minter.get():
            revert("Invalid Sender")

        self.is_valid(_tokenId)

        owner = self._tokenOwner[_tokenId]
        if owner != _from or _from == self._ZERO_ADDRESS:
            revert("Invalid Request")

        if _tokenId < 0 :
            revert(f"{_tokenId} is not valid.")

        self._total_supply.set(self._total_supply.get() - 1)
        self._ownedTokenCount[owner] -= 1
        self._tokenList[_tokenId] = False
        self._tokenOwner[_tokenId] = self._ZERO_ADDRESS
        del self._token[_tokenId]

        self.Burn(_tokenId)
        self.Transfer(_from, self._ZERO_ADDRESS, _tokenId)

    def _update(self, _tokenId:int, _name:str, _others:str):
        if self.msg.sender != self._tokenOwner[_tokenId] or self.msg.sender != self._minter.get():
            revert("Invalid Sender")

        self.is_valid(_tokenId)
        updated_attribs = {
            'name': _name,
            'others': _others
        }
        self._token[_tokenId] = json_dumps(updated_attribs)
        self.Update(_tokenId)

    def is_valid(self, _tokenId:int) -> bool:
        if not self._tokenList[_tokenId]:
            revert(f"{_tokenId} is not valid. Token with id {_tokenId} does not exist.")
        return True

    def _load_token(self, _tokenId:int) -> dict:
        token = {}
        token = json_loads(self._token[_tokenId])
        return token

    def _is_zero_address(self, _address: Address) -> bool:
        # Check if address is zero address
        if _address == self._ZERO_ADDRESS:
            return True
        return False
