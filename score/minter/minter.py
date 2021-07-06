from iconservice import *
from .utils.checks import *
from .utils.type_converter import params_type_converter
from .utils.SafeMath import SafeMath

class TokenInformationInterface(InterfaceScore):
	@interface
	def decimals(self) -> int:
		pass

	@interface
	def balanceOf(self, _owner: Address) -> int:
		pass

class TokenSupplyInterface(InterfaceScore):
    @interface
    def burnFrom(self, _account: Address, _amount: int) -> None:
        pass

    @interface
    def mintTo(self, _account: Address, _amount: int) -> None:
        pass

class NFTSupplyInterface(InterfaceScore):
    @interface
    def burn(self, _from: Address, _tokenId: int) -> None:
        pass

    @interface
    def mint(self, _to: Address, _tokenId: int) -> None:
        pass

class MultiSigWalletInterface(InterfaceScore):
    @interface
    def checkIfWalletOwner(self, _walletOwner: Address) -> bool:
        pass

    @interface
    def getRequirement(self) -> int:
        pass

class IconMinterContract(IconScoreBase):
    @eventlog
    def Swap(self, hubContract: bytes, fromChain: str, toChain: str, fromAddr: bytes, toAddr: bytes, tokenAddress: bytes, bytes32s: bytes, uints: bytes, data: bytes):
        pass

    @eventlog
    def SwapNFT(self, hubContract: bytes, fromChain: str, toChain: str, fromAddr: bytes, toAddr: bytes, tokenAddress: bytes, bytes32s: bytes, uints: bytes, data: bytes):
        pass

    @eventlog
    def SwapRequest(self, fromChain: str, toChain: str, fromAddr: bytes, toAddr: bytes, token: bytes, tokenAddress: bytes, decimal: int, amount: int, depositId: int, data: bytes):
        pass

    @eventlog
    def SwapNFTRequest(self, fromChain: str, toChain: str, fromAddr: bytes, toAddr: bytes, token: bytes, tokenAddress: bytes, tokenId: int, amount: int, depositId: int, data: bytes):
        pass

    def __init__(self, db: IconScoreDatabase) -> None:
        super().__init__(db)
        self._governance = VarDB("governance", db, value_type=Address)
        self._fee_governance = VarDB("fee_governance", db, value_type=Address)
        self._bridging_fee = VarDB("bridging_fee", db, value_type=int)
        self._gov_id = VarDB("gov_id", db, value_type=bytes)
        self._is_activated = VarDB("is_activated", db, value_type=bool)
        self._chain = VarDB("chain", db, value_type=str)
        self._deposit_count = VarDB("deposit_count", db, value_type=int)

        self._is_used_hash = DictDB("is_used_hash", db, value_type=bool)
        self._is_valid_chain = DictDB("is_valid_chain", db, value_type=bool)
        self._is_valid_token = DictDB("is_valid_token", db, value_type=bool)
        self._tokens = DictDB("tokens", db, value_type=bytes)
        self._token_addrs = DictDB("token_addrs", db, value_type=Address)
        self._token_summaries = DictDB("token_summaries", db, value_type=bytes)

        self._tax_rate = VarDB("tax_rate", db, value_type=int)
        self._tax_receiver = VarDB("tax_receiver", db, value_type=bytes)

    def on_install(self, _governance: Address, _fee_governance: Address, _bridging_fee: int, _gov_id: bytes) -> None:
        super().on_install()

        self._governance.set(_governance)
        self._fee_governance.set(_fee_governance)
        self._bridging_fee.set(_bridging_fee)
        self._gov_id.set(_gov_id)
        self._is_activated.set(True)
        self._chain.set("ICON")

    def on_update(self) -> None:
        super().on_update()

    def require(self, execute_result: bool, msg: str):
        if not execute_result:
            revert(msg)

    @external(readonly=True)
    def isAcitvated(self) -> bool:
        return self._is_activated.get()

    @external(readonly=True)
    def isValidChain(self, chain: str) -> bool:
        return self._is_valid_chain[self.getChainId(chain)]

    @external(readonly=True)
    def isValidToken(self, tokenAddr: Address) -> bool:
        return self._is_valid_token[tokenAddr]

    @external(readonly=True)
    def tokens(self, tokenSummary: bytes) -> bytes:
        return self._tokens[tokenSummary]

    @external(readonly=True)
    def tokenAddrs(self, tokenSummary: bytes) -> Address:
        return self._token_addrs[tokenSummary]

    @external(readonly=True)
    def governance(self) -> Address:
        return self._governance.get()

    @external(readonly=True)
    def feeGovernance(self) -> Address:
        return self._fee_governance.get()

    @external(readonly=True)
    def bridgingFee(self) -> int:
        return self._bridging_fee.get()

    @external(readonly=True)
    def govId(self) -> bytes:
        return self._gov_id.get()

    @external(readonly=True)
    def chain(self) -> str:
        return self._chain.get()

    @external(readonly=True)
    def getTaxRate(self) -> int:
        return self._tax_rate.get()

    @external(readonly=True)
    def getTaxReceiver(self) -> bytes:
        return self._tax_receiver.get()

    @external(readonly=True)
    def getChainId(self, chain: str) -> bytes:
        return sha_256(chain.encode())

    @external(readonly=True)
    def getTokenSummary(self, token: bytes) -> bytes:
        return sha_256("ICON".encode() + token)

    @external(readonly=True)
    def getTokenAddress(self, token: bytes) -> Address:
        return self._token_addrs[self.getTokenSummary(token)]

    @external(readonly=True)
    def getTokenDecimal(self, tokenAddress: Address) -> int:
        token_score = self.create_interface_score(tokenAddress, TokenInformationInterface)
        return token_score.decimals()

    @external(readonly=True)
    def getTokenBalance(self, tokenAddress: Address, owner: Address) -> int:
        token_score = self.create_interface_score(tokenAddress, TokenInformationInterface)
        return token_score.balanceOf(owner)

    @external(readonly=True)
    def convertAddressToBytes(self, account: Address) -> bytes:
        account_bytes = account.to_bytes()
        if len(account_bytes) == 20 :
            account_bytes = b'\x00' + account_bytes
        return account_bytes

    @external(readonly=True)
    def convertBytesToAddress(self, account_bytes: bytes) -> Address:
        return Address.from_bytes(account_bytes)

    @only_governance
    @external
    def transferOwnership(self, _governance: Address):
        self._governance.set(_governance)

    @only_governance
    @external
    def setFeeGovernance(self, _fee_governance: Address):
        self._fee_governance.set(_fee_governance)

    @only_governance
    @external
    def setBridgingFee(self, _bridging_fee: int):
        self._bridging_fee.set(_bridging_fee)

    @only_governance
    @external
    def setGovId(self, _gov_id: bytes):
        self.require(len(_gov_id) == 32, "Invalid GovId")
        self._gov_id.set(_gov_id)

    @only_governance
    @external
    def setActivated(self, _is_activated: bool):
        self._is_activated.set(_is_activated)

    @only_governance
    @external
    def setValidChain(self, chain: str, valid: bool):
        self._is_valid_chain[self.getChainId(chain)] = valid

    @only_governance
    @external
    def setTaxRate(self, _tax_rate: int):
        self.require(_tax_rate < 10000, "Invalid Tax Rate")
        self._tax_rate.set(_tax_rate)

    @only_governance
    @external
    def setTaxReceiver(self, _tax_receiver: bytes):
        self.require(len(_tax_receiver) == 20, "Invalid taxReceiver")
        self._tax_receiver.set(_tax_receiver)

    @only_governance
    @external
    def addToken(self, token: bytes, tokenAddress: Address):
        token_summary = self.getTokenSummary(token)
        self.require(self._token_addrs[token_summary] == None, "Already Set")
        self.require(self._token_summaries[tokenAddress] == None, "Already Set")
        self.require(tokenAddress.is_contract, "Invalid Token Address")

        self._is_valid_token[tokenAddress] = True
        self._tokens[token_summary] = token
        self._token_addrs[token_summary] = tokenAddress
        self._token_summaries[tokenAddress] = token_summary

    @payable
    @external
    def requestSwap(self, tokenAddress: Address, toChain: str, toAddr: bytes, amount: int):
        self.require(self._is_activated.get(), "Error: isActivated False")
        self.require(self._is_valid_chain[self.getChainId(toChain)], "Error: Invalid toChain")
        self.require(self._is_valid_token[tokenAddress], "Error: Invalid token address")
        self.require(self.msg.value >= self._bridging_fee.get(), "Error: Not enough bridging fee")
        self.require(amount > 0, "Error: Not enough amount")

        self.require(self._transferBridgingFee(self.msg.value), "Error: Transfer Bridging Fee Fail")

        tokenSummary = self._token_summaries[tokenAddress]
        self.require(tokenSummary != None, "Error: Invalid token address")

        token = self._tokens[tokenSummary]
        self.require(token != None, "Error: Invalid token summary")

        decimal = self.getTokenDecimal(tokenAddress)
        self.require(decimal > 0, "Error: Invalid token decimal")

        userBalance = self.getTokenBalance(tokenAddress, self.msg.sender)
        self.require(userBalance >= amount, "Error: Not enough balance")

        self.require(self._burn(tokenAddress, self.msg.sender, amount), "Error: Token Burn Fail")

        if self._tax_rate.get() != 0 and len(self._tax_receiver.get()) != 0 :
            tax = self._payTax(token, tokenAddress, amount, decimal)
            amount = SafeMath.sub(amount, tax)

        depositId = self._deposit_count.get() + 1
        self._deposit_count.set(depositId)

        self.SwapRequest(self._chain.get(), toChain, self.convertAddressToBytes(self.msg.sender), toAddr, token, self.convertAddressToBytes(tokenAddress), decimal, amount, depositId, None)

    @payable
    @external
    def requestSwapNFT(self, nftAddress: Address, toChain: str, toAddr: bytes, tokenId: int):
        self.require(self._is_activated.get(), "Error: isActivated False")
        self.require(self._is_valid_chain[self.getChainId(toChain)], "Error: Invalid toChain")
        self.require(self._is_valid_token[nftAddress], "Error: Invalid token address")
        self.require(self.msg.value >= self._bridging_fee.get(), "Error: Not enough bridging fee")
        self.require(tokenId >= 0, "Error: Not enough amount")

        self.require(self._transferBridgingFee(self.msg.value), "Error: Transfer Bridging Fee Fail")

        tokenSummary = self._token_summaries[nftAddress]
        self.require(tokenSummary != None, "Error: Invalid token address")

        token = self._tokens[tokenSummary]
        self.require(token != None, "Error: Invalid token summary")

        self.require(self._burnNFT(nftAddress, self.msg.sender, tokenId), "Error: Token Burn Fail")

        depositId = self._deposit_count.get() + 1
        self._deposit_count.set(depositId)

        self.SwapNFTRequest(self._chain.get(), toChain, self.convertAddressToBytes(self.msg.sender), toAddr, token, self.convertAddressToBytes(nftAddress), tokenId, 1, depositId, None)

    @external
    def swap(self, hubContract: bytes, fromChain: str, fromAddr: bytes, toAddr: bytes, token: bytes, bytes32s: bytes, uints: bytes, sigs: str, data: bytes = None):
        self.require(self._is_activated.get(), "Error: isActivated False")
        self.require(len(hubContract) == 20, "Error: Invaild HubContract")
        self.require(len(toAddr) == 21, "Error: Invalid toAddr length")
        self.require(len(bytes32s) >= 32, "Error: Invalid bytes32s length")
        self.require(len(bytes32s) % 32 == 0, "Error: Invalid bytes32s length")
        self.require(len(uints) >= 64, "Error: Invalid uints length")
        self.require(len(uints) % 32 == 0, "Error: Invalid bytes32s length")

        govId = bytes32s[:32]
        self.require(self._gov_id.get() == govId, "Error: Invalid govId")

        amount = int.from_bytes(uints[:32], "big")
        decimal = int.from_bytes(uints[32:64], "big")

        tokenAddress = self.getTokenAddress(token)
        self.require(tokenAddress != None, "Error: Invalid Token")

        tokenDecimal = self.getTokenDecimal(tokenAddress)
        self.require(decimal == tokenDecimal, "Error: Invalid Token Decimal")

        hash_bytes = self.encodePackedSwapHash(hubContract, fromChain, self._chain.get(), fromAddr, toAddr, token, bytes32s, uints)
        if data != None:
            hash_bytes = hash_bytes + data

        swapHash = sha_256(hash_bytes)
        self.require(not self._is_used_hash[swapHash], "Error: used swapHash")
        self._is_used_hash[swapHash] = True

        self.require(self._validate_signature(swapHash, sigs), "Error: Invalid Signature")

        self.require(self._mint(tokenAddress, self.convertBytesToAddress(toAddr), amount), "Error: Mint Token Fail")

        if not self.isValidChain(fromChain):
            self._setValidChain(fromChain)

        self.Swap(hubContract, fromChain, self._chain.get(), fromAddr, toAddr, self.convertAddressToBytes(tokenAddress), bytes32s, uints, data)

    def encodePackedSwapHash(self, hubContract: bytes, fromChain: str, toChain:str, fromAddr: bytes, toAddr: bytes, token: bytes, bytes32s: bytes, uints: bytes) -> bytes:
        fromChain_bytes = fromChain.encode()
        toChain_bytes = toChain.encode()

        return hubContract + fromChain_bytes + toChain_bytes + fromAddr + toAddr + token + bytes32s + uints

    @external
    def swapNFT(self, hubContract: bytes, fromChain: str, fromAddr: bytes, toAddr: bytes, token: bytes, bytes32s: bytes, uints: bytes, sigs: str, data: bytes = None):
        self.require(self._is_activated.get(), "Error: isActivated False")
        self.require(len(hubContract) == 20, "Error: Invaild HubContract")
        self.require(len(toAddr) == 21, "Error: Invalid toAddr length")
        self.require(len(bytes32s) >= 32, "Error: Invalid bytes32s length")
        self.require(len(bytes32s) % 32 == 0, "Error: Invalid bytes32s length")
        self.require(len(uints) >= 64, "Error: Invalid uints length")
        self.require(len(uints) % 32 == 0, "Error: Invalid bytes32s length")

        govId = bytes32s[:32]
        self.require(self._gov_id.get() == govId, "Error: Invalid govId")

        amount = int.from_bytes(uints[:32], "big")
        tokenId = int.from_bytes(uints[32:64], "big")

        tokenAddress = self.getTokenAddress(token)
        self.require(tokenAddress != None, "Error: Invalid Token")

        hash_bytes = self.encodePackedSwapNFTHash(hubContract, fromChain, self._chain.get(), fromAddr, toAddr, token, bytes32s, uints)
        if data != None:
            hash_bytes = hash_bytes + data

        swapHash = sha_256(hash_bytes)
        self.require(not self._is_used_hash[swapHash], "Error: used swapHash")
        self._is_used_hash[swapHash] = True

        self.require(self._validate_signature(swapHash, sigs), "Error: Invalid Signature")

        self.require(self._mintNFT(tokenAddress, self.convertBytesToAddress(toAddr), tokenId), "Error: Mint Token Fail")

        if not self.isValidChain(fromChain):
            self._setValidChain(fromChain)

        self.SwapNFT(hubContract, fromChain, self._chain.get(), fromAddr, toAddr, self.convertAddressToBytes(tokenAddress), bytes32s, uints, data)

    def encodePackedSwapNFTHash(self, hubContract: bytes, fromChain: str, toChain:str, fromAddr: bytes, toAddr: bytes, token: bytes, bytes32s: bytes, uints: bytes) -> bytes:
        fromChain_bytes = fromChain.encode()
        toChain_bytes = toChain.encode()
        nft_bytes = 'NFT'.encode()

        return nft_bytes + hubContract + fromChain_bytes + toChain_bytes + fromAddr + toAddr + token + bytes32s + uints

    def _setValidChain(self, chain: str):
        self._is_valid_chain[self.getChainId(chain)] = True

    def _validate_signature(self, sigHash: bytes, sigs: str) -> bool:
        mig_score = self.create_interface_score(self._governance.get(), MultiSigWalletInterface)
        mig_required = mig_score.getRequirement()
        self.require(mig_required > 0, "Invalid MultiSigWallet Required")

        sig_list = sigs.replace(" ", "").split(",")
        major_count = 0

        va_list = []

        for sig_bytes in sig_list:
            sig = params_type_converter("bytes", sig_bytes)
            self.require(len(sig) == 65, "Invalid Sig length")

            pub = recover_key(sigHash, sig, False)
            self.require(len(pub) == 65, "Invalid PubKey length")

            va = Address.from_bytes(sha3_256(pub[1:])[12:])
            if mig_score.checkIfWalletOwner(va):
                self.require(not va in va_list, "Duplicate signature")
                major_count = major_count + 1
                va_list.append(va)

        return mig_required <= major_count

    def _transferBridgingFee(self, amount: int) -> bool:
        try:
            self.icx.transfer(self._fee_governance.get(), amount)
            execute_result = True
        except:
            execute_result = False

        return execute_result

    def _payTax(self, token: bytes, tokenAddress: Address, amount: int, decimal: int) -> int:
        tax = SafeMath.div(SafeMath.mul(amount, self._tax_rate.get()), 10000)

        if tax != 0:
            depositId = self._deposit_count.get() + 1
            self._deposit_count.set(depositId)
            self.SwapRequest(self._chain.get(), "ORBIT", self.convertAddressToBytes(self.msg.sender), self._tax_receiver.get(), token, self.convertAddressToBytes(tokenAddress), decimal, tax, depositId, None)

        return tax

    def _burn(self, tokenAddress: Address, user: Address, amount: int) -> bool:
        try:
            token_score = self.create_interface_score(tokenAddress, TokenSupplyInterface)
            token_score.burnFrom(user, amount)
            execute_result = True
        except:
            execute_result = False

        return execute_result

    def _burnNFT(self, nftAddress: Address, user: Address, tokenId: int) -> bool:
        try:
            token_score = self.create_interface_score(nftAddress, NFTSupplyInterface)
            token_score.burn(user, tokenId)
            execute_result = True
        except:
            execute_result = False

        return execute_result

    def _mint(self, tokenAddress: Address, user: Address, amount: int) -> bool:
        try:
            token_score = self.create_interface_score(tokenAddress, TokenSupplyInterface)
            token_score.mintTo(user, amount)
            execute_result = True
        except:
            execute_result = False

        return execute_result

    def _mintNFT(self, nftAddress: Address, user: Address, tokenId: int) -> bool:
        try:
            token_score = self.create_interface_score(nftAddress, NFTSupplyInterface)
            token_score.mint(user, tokenId)
            execute_result = True
        except:
            execute_result = False

        return execute_result
