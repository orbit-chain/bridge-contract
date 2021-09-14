from iconservice import *
from .utils.checks import only_governance
from .utils.checks import only_activated
from .utils.type_converter import params_type_converter
from .utils.SafeMath import SafeMath

EOA_ZERO = Address.from_string("hx" + "0" * 40)
ICX_ADDR = Address.from_string("cx" + "0" * 40)

class TokenInformationInterface(InterfaceScore):
	@interface
	def decimals(self) -> int:
		pass

	@interface
	def balanceOf(self, _owner: Address) -> int:
		pass

class TokenTransferInterface(InterfaceScore):
    @interface
    def transfer(self, _account: Address, _amount: int) -> None:
        pass

    @interface
    def transferFrom(self, sender: Address, recepient: Address, _amount: int) -> bool:
        pass

class NFTInformationInterface(InterfaceScore):
    @interface
    def ownerOf(self, _tokenId: int) -> Address:
        pass

class NFTTransferInterface(InterfaceScore):
    @interface
    def transferFrom(self, _from: Address, _to: Address, _tokenId: int) -> None:
        pass

    @interface
    def transfer(self, _to: Address, _tokenId: int) -> None:
        pass

class MultiSigWalletInterface(InterfaceScore):
    @interface
    def checkIfWalletOwner(self, _walletOwner: Address) -> bool:
        pass

    @interface
    def getRequirement(self) -> int:
        pass

class FarmInterface(InterfaceScore):
    @interface
    def deposit(self, amount: int) -> None:
        pass

    @interface
    def withdrawAll(self) -> None:
        pass

    @interface
    def withdraw(self, _to: Address, amount: int) -> None:
        pass

class BridgeReceiverInterface(InterfaceScore):
    @interface
    def onTokenBridgeReceived(self, token: Address, value: int, data: bytes) -> int:
        pass

    @interface
    def onNFTBridgeReceived(self, token: Address, tokenId: int, data: bytes) -> int:
        pass

class IconVaultContract(IconScoreBase):
    @eventlog
    def Deposit(self, fromChain: str, toChain: str, fromAddr: bytes, toAddr: bytes, token: bytes, decimal: int, amount: int, depositId: int, data: bytes):
        pass

    @eventlog
    def DepositNFT(self, fromChain: str, toChain: str, fromAddr: bytes, toAddr: bytes, token: bytes, tokenId: int, amount: int, depositId: int, data: bytes):
        pass

    @eventlog
    def Withdraw(self, fromChain: str, fromAddr: bytes, toAddr: bytes, token: bytes, bytes32s: bytes, uints: bytes, data: bytes):
        pass

    @eventlog
    def WithdrawNFT(self, fromChain: str, fromAddr: bytes, toAddr: bytes, token: bytes, bytes32s: bytes, uints: bytes, data: bytes):
        pass

    @eventlog
    def BridgeReceiverResult(self, success: bool, fromAddr: bytes, token: Address, data: bytes):
        pass

    def __init__(self, db: IconScoreDatabase) -> None:
        super().__init__(db)
        self._governance = VarDB("governance", db, value_type=Address)
        self._fee_governance = VarDB("fee_governance", db, value_type=Address)
        self._bridging_fee = VarDB("bridging_fee", db, value_type=int)
        self._is_activated = VarDB("is_activated", db, value_type=bool)
        self._chain = VarDB("chain", db, value_type=str)
        self._deposit_count = VarDB("deposit_count", db, value_type=int)

        self._is_used_hash = DictDB("is_used_hash", db, value_type=bool)
        self._is_valid_chain = DictDB("is_valid_chain", db, value_type=bool)

        self._farms = DictDB("farms", db, value_type=Address)

        self._tax_rate = VarDB("tax_rate", db, value_type=int)
        self._tax_receiver = VarDB("tax_receiver", db, value_type=bytes)

        self._policy_admin = VarDB("policy_admin", db, value_type=Address)
        self._chain_fee = DictDB("chain_fee", db, value_type=int)
        self._chain_fee_with_data = DictDB("chain_fee_with_data", db, value_type=int)
        self._chain_uints_length = DictDB("chain_uints_length", db, value_type=int)
        self._chain_address_length = DictDB("chain_address_length", db, value_type=int)

    def on_install(self, _governance: Address, _fee_governance: Address, _bridging_fee: int) -> None:
        super().on_install()

        self._governance.set(_governance)
        self._fee_governance.set(_fee_governance)
        self._bridging_fee.set(_bridging_fee)
        self._is_activated.set(True)
        self._chain.set("ICON")

    def on_update(self) -> None:
        super().on_update()

        self._policy_admin.set(EOA_ZERO)
        self._chain_uints_length[self.getChainId("KLAYTN")] = 96
        self._chain_address_length[self.getChainId("KLAYTN")] = 20
        self._chain_uints_length[self.getChainId("ORBIT")] = 96
        self._chain_address_length[self.getChainId("ORBIT")] = 20

    def require(self, execute_result: bool, msg: str):
        if not execute_result:
            revert(msg)

    @external(readonly=True)
    def isAcitvated(self) -> bool:
        return self._is_activated.get()

    @external(readonly=True)
    def isValidChain(self, chainSymbol: str) -> bool:
        return self._is_valid_chain[self.getChainId(chainSymbol)]

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
    def getGovId(self, hubContract: bytes) -> bytes:
        hash_bytes = hubContract + self._chain.get().encode() + self.convertAddressToBytes(self.address)
        return sha_256(hash_bytes)

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
    def getFarmAddress(self, token: Address) -> Address:
        return self._farms[token]

    @external(readonly=True)
    def getChainId(self, chain: str) -> bytes:
        return sha_256(chain.encode())

    @external(readonly=True)
    def getTokenDecimal(self, tokenAddress: Address) -> int:
        token_score = self.create_interface_score(tokenAddress, TokenInformationInterface)
        return token_score.decimals()

    @external(readonly=True)
    def getTokenBalance(self, tokenAddress: Address, owner: Address) -> int:
        token_score = self.create_interface_score(tokenAddress, TokenInformationInterface)
        return token_score.balanceOf(owner)

    @external(readonly=True)
    def getNFTOwner(self, nftAddress: Address, tokenId: int) -> Address:
        token_score = self.create_interface_score(nftAddress, NFTInformationInterface)
        return token_score.ownerOf(tokenId)

    @external(readonly=True)
    def convertAddressToBytes(self, account: Address) -> bytes:
        account_bytes = account.to_bytes()
        if len(account_bytes) == 20 :
            account_bytes = b'\x00' + account_bytes
        return account_bytes

    @external(readonly=True)
    def convertBytesToAddress(self, account_bytes: bytes) -> Address:
        return Address.from_bytes(account_bytes)

    @external(readonly=True)
    def policyAdmin(self) -> Address:
        return self._policy_admin.get()

    @external(readonly=True)
    def chainFee(self, chain: str) -> int:
        return self._chain_fee[self.getChainId(chain)]

    @external(readonly=True)
    def chainFeeWithData(self, chain: str) -> int:
        return self._chain_fee_with_data[self.getChainId(chain)]

    @external(readonly=True)
    def chainUintsLength(self, chain: str) -> int:
        return self._chain_uints_length[self.getChainId(chain)]

    @external(readonly=True)
    def chainAddressLength(self, chain: str) -> int:
        return self._chain_address_length[self.getChainId(chain)]

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
    def setValidChain(self, chainSymbol: str, valid: bool, fromAddrLen: int, uintsLen: int):
        self.require(self._chain.get() != chainSymbol, "Error: invalid chain")
        self._is_valid_chain[self.getChainId(chainSymbol)] = valid
        if valid :
            self._chain_uints_length[self.getChainId(chainSymbol)] = uintsLen
            self._chain_address_length[self.getChainId(chainSymbol)] = fromAddrLen
        else:
            self._chain_uints_length[self.getChainId(chainSymbol)] = 0
            self._chain_address_length[self.getChainId(chainSymbol)] = 0

    @only_governance
    @external
    def setChainLength(self, chainSymbol: str, fromAddrLen: int, uintsLen: int):
        self.require(self._chain.get() != chainSymbol, "Error: invalid chain")
        self.require(self._is_valid_chain[self.getChainId(chainSymbol)], "Error: invalid chain")
        self._chain_uints_length[self.getChainId(chainSymbol)] = uintsLen
        self._chain_address_length[self.getChainId(chainSymbol)] = fromAddrLen

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
    def addFarm(self, token: Address, proxy: Address):
        self.require(self._farms[token] == None or self._farms[token] == EOA_ZERO, "Error: Remove Current Farm First")

        if token == ICX_ADDR:
            amount = self.icx.get_balance(self.address)
        else:
            amount = self.getTokenBalance(token, self.address)

        if amount != 0 :
            self.require(self._transferToken(token, proxy, amount), "Error: TransferToken Fail")
            self.require(self._farmDeposit(proxy, amount), "Error: Farm Deposit Fail")

        self._farms[token] = proxy

    @only_governance
    @external
    def removeFarm(self, token: Address, newProxy: Address = None):
        self.require(self._farms[token] != None and self._farms[token] != EOA_ZERO, "Error: Farm Not Initialized")

        self.require(self._farmWithdrawAll(self._farms[token]), "Error: Cannot Withdraw From Current Farm")

        if newProxy != None:
            self._farms[token] = newProxy
            if token == ICX_ADDR:
                amount = self.icx.get_balance(self.address)
            else:
                amount = self.getTokenBalance(token, self.address)

            if amount != 0:
                self.require(self._transferToken(token, newProxy, amount), "Error: TransferToken Fail")
                self.require(self._farmDeposit(newProxy, amount), "Error: Farm Deposit Fail")
        else:
            self._farms[token] = EOA_ZERO

    @only_governance
    @external
    def setPolicyAdmin(self, _policy_admin: Address):
        self._policy_admin.set(_policy_admin)

    @external
    def setActivated(self, _is_activated: bool):
        self.require(self.msg.sender == self._policy_admin.get(), "Error: Invalid Sender")
        self._is_activated.set(_is_activated)

    @external
    def setChainFee(self, chainSymbol: str, fee: int, feeWithData: int):
        self.require(self.msg.sender == self._policy_admin.get(), "Error: Invalid Sender")
        self.require(self._is_valid_chain[self.getChainId(chainSymbol)], "Error: Invalid Chain")
        self._chain_fee[self.getChainId(chainSymbol)] = fee
        self._chain_fee_with_data[self.getChainId(chainSymbol)] = feeWithData

    @payable
    @external
    def deposit(self, toChain: str, toAddr: bytes, data: bytes = None):
        fee = 0
        if data == None:
            fee = self._chain_fee[self.getChainId(toChain)]
        else:
            self.require(len(data) != 0, "Error: invalid data")
            fee = self._chain_fee_with_data[self.getChainId(toChain)]
        self.require(self.msg.value > fee, "Error: Not enough bridging fee")
        if fee != 0 :
            self.require(self._transferBridgingFee(fee), "Error: Transfer Bridging Fee Fail")
        self._depositToken(ICX_ADDR, toChain, toAddr, SafeMath.sub(self.msg.value, fee), data)

    @payable
    @external
    def depositToken(self, token: Address, toChain:str, toAddr: bytes, amount: int, data: bytes = None):
        self.require(token != ICX_ADDR, "Error: Invalid token address")

        fee = 0
        if data == None:
            fee = self._chain_fee[self.getChainId(toChain)]
        else:
            self.require(len(data) != 0, "Error: invalid data")
            fee = self._chain_fee_with_data[self.getChainId(toChain)]
        self.require(self.msg.value >= fee, "Error: Not enough bridging fee")
        if fee != 0 :
            self.require(self._transferBridgingFee(self.msg.value), "Error: Transfer Bridging Fee Fail")
        self._depositToken(token, toChain, toAddr, amount, data)

    @only_activated
    def _depositToken(self, token: Address, toChain: str, toAddr: bytes, amount: int, data: bytes):
        self.require(self._is_valid_chain[self.getChainId(toChain)], "Error: Invalid toChain")
        self.require(amount > 0, "Error: Not enough amount")

        if token == ICX_ADDR:
            decimal = 18
        else:
            decimal = self.getTokenDecimal(token)
            """NOTE
            https://github.com/icon-project/IIPs/blob/master/IIPS/iip-2.md
            IRC2 do not guarantee transferFrom method
            """
            self.require(self._transferFromToken(token, self.msg.sender, self.address, amount), "Error: TransferFrom fail")

        self.require(decimal > 0, "Error: Invalid decimal")

        farm = self._farms[token]
        if farm != None and farm != EOA_ZERO:
            self.require(self._transferToken(token, farm, amount), "Error: TransferToken Fail")
            self.require(self._farmDeposit(farm, amount), "Error: Farm Deposit Fail")

        if self._tax_rate.get() != 0 and len(self._tax_receiver.get()) != 0:
            tax = self._payTax(token, amount, decimal)
            amount = SafeMath.sub(amount, tax)

        depositId = self._deposit_count.get() + 1
        self._deposit_count.set(depositId)

        self.Deposit(self._chain.get(), toChain, self.convertAddressToBytes(self.msg.sender), toAddr, self.convertAddressToBytes(token), decimal, amount, depositId, data)

    @only_activated
    @payable
    @external
    def depositNFT(self, token: Address, toChain: str, toAddr: bytes, tokenId: int, data: bytes = None):
        self.require(self._is_valid_chain[self.getChainId(toChain)], "Error: Invalid toChain")
        self.require(token != ICX_ADDR and token != EOA_ZERO, "Error: Invalid Token Address")
        self.require(self.getNFTOwner(token, tokenId) != self.msg.sender, "Error: Owner check fail")

        fee = 0
        if data == None:
            fee = self._chain_fee[self.getChainId(toChain)]
        else:
            self.require(len(data) != 0, "Error: invalid data")
            fee = self._chain_fee_with_data[self.getChainId(toChain)]
        self.require(self.msg.value >= fee, "Error: Not enough bridging fee")
        if fee != 0 :
            self.require(self._transferBridgingFee(self.msg.value), "Error: Transfer Bridging Fee Fail")

        self.require(self._transferFromNFT(token, self.msg.sender, self.address, tokenId), "Error: deposit fail")
        self.require(self.getNFTOwner(token, tokenId) == self.address, "Error: Owner check fail")

        depositId = self._deposit_count.get() + 1
        self._deposit_count.set(depositId)

        self.DepositNFT(self._chain.get(), toChain, self.convertAddressToBytes(self.msg.sender), toAddr, self.convertAddressToBytes(token), tokenId, 1, depositId, data)

    @only_activated
    @external
    def withdraw(self, hubContract: bytes, fromChain: str, fromAddr: bytes, toAddr: bytes, token: bytes, bytes32s: bytes, uints: bytes, sigs: str, data: bytes = None):
        self.require(len(hubContract) == 20, "Error: Invaild HubContract")
        self.require(len(fromAddr) == self._chain_address_length[self.getChainId(fromChain)], "Error: Invalid fromAddr length")
        self.require(len(toAddr) == 21, "Error: Invalid toAddr length")
        self.require(len(token) == 21, "Error: Invalid token length")
        self.require(len(bytes32s) == 64, "Error: Invalid bytes32s length")
        self.require(len(bytes32s) % 32 == 0, "Error: Invalid bytes32s length")
        self.require(len(uints) == self._chain_uints_length[self.getChainId(fromChain)], "Error: Invalid uints length")
        self.require(len(uints) % 32 == 0, "Error: Invalid bytes32s length")
        self.require(self._is_valid_chain[self.getChainId(fromChain)], "Error: Invalid fromChain")

        govId = bytes32s[:32]
        self.require(govId == self.getGovId(hubContract), "Error: Invalid govId")

        hash_bytes = hubContract + fromChain.encode() + self._chain.get().encode() + fromAddr + toAddr + token + bytes32s + uints
        if data != None:
            hash_bytes += data

        whash = sha_256(hash_bytes)
        self.require(not self._is_used_hash[whash], "Error: used withdrawHash")
        self._is_used_hash[whash] = True

        self.require(self._validate_signature(whash, sigs), "Error: Invalid Signature")

        tokenAddress = self.convertBytesToAddress(token)
        amount = int.from_bytes(uints[:32], "big")
        to = self.convertBytesToAddress(toAddr)

        farm = self._farms[tokenAddress]
        if farm != None and farm != EOA_ZERO:
            self.require(self._farmWithdraw(farm, to, amount), "Error: Farm Withdraw Fail")
        else:
            self.require(self._transferToken(tokenAddress, to, amount), "Error: Withdraw fail")

        if to.is_contract and data != None:
            success = self._callBridgeReceiver(True, tokenAddress, amount, data, to)
            self.BridgeReceiverResult(success, fromAddr, tokenAddress, data)

        self.Withdraw(fromChain, fromAddr, toAddr, token, bytes32s, uints, data)

    @only_activated
    @external
    def withdrawNFT(self, hubContract: bytes, fromChain: str, fromAddr: bytes, toAddr: bytes, token: bytes, bytes32s: bytes, uints: bytes, sigs: str, data: bytes = None):
        self.require(len(hubContract) == 20, "Error: Invaild HubContract")
        self.require(len(fromAddr) == self._chain_address_length[self.getChainId(fromChain)], "Error: Invalid fromAddr length")
        self.require(len(toAddr) == 21, "Error: Invalid toAddr length")
        self.require(len(token) == 21, "Error: Invalid token length")
        self.require(len(bytes32s) == 64, "Error: Invalid bytes32s length")
        self.require(len(bytes32s) % 32 == 0, "Error: Invalid bytes32s length")
        self.require(len(uints) == self._chain_uints_length[self.getChainId(fromChain)], "Error: Invalid uints length")
        self.require(len(uints) % 32 == 0, "Error: Invalid bytes32s length")
        self.require(self._is_valid_chain[self.getChainId(fromChain)], "Error: Invalid fromChain")

        govId = bytes32s[:32]
        self.require(govId == self.getGovId(hubContract), "Error: Invalid govId")

        hash_bytes = "NFT".encode() + hubContract + fromChain.encode() + self._chain.get().encode() + fromAddr + toAddr + token + bytes32s + uints
        if data != None:
            hash_bytes += data

        whash = sha_256(hash_bytes)
        self.require(not self._is_used_hash[whash], "Error: used withdrawHash")
        self._is_used_hash[whash] = True

        self.require(self._validate_signature(whash, sigs), "Error: Invalid Signature")

        tokenAddress = self.convertBytesToAddress(token)
        tokenId = int.from_bytes(uints[32:64], "big")
        to = self.convertBytesToAddress(toAddr)

        self.require(self.getNFTOwner(tokenAddress, tokenId) == self.address, "Error: Owner check fail")
        self.require(self._transferNFT(tokenAddress, to, tokenId), "Error: Withdraw fail")

        if to.is_contract and data != None:
            success = self._callBridgeReceiver(False, tokenAddress, tokenId, data, to)
            self.BridgeReceiverResult(success, fromAddr, tokenAddress, data)

        self.WithdrawNFT(fromChain, fromAddr, toAddr, token, bytes32s, uints, data)

    @external
    def tokenFallback(self, _from: Address, _value: int, _data: bytes):
        pass

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

    def _payTax(self, token: Address, amount: int, decimal: int, data: bytes = None) -> int:
        tax = SafeMath.div(SafeMath.mul(amount, self._tax_rate.get()), 10000)

        if tax != 0:
            depositId = self._deposit_count.get() + 1
            self._deposit_count.set(depositId)
            self.Deposit(self._chain.get(), "ORBIT", self.convertAddressToBytes(self.msg.sender), self._tax_receiver.get(), self.convertAddressToBytes(token), decimal, tax, depositId, data)

        return tax

    def _transferFromToken(self, tokenAddress: Address, _from: Address, _to: Address, amount: int) -> bool:
        try:
            token_score = self.create_interface_score(tokenAddress, TokenTransferInterface)
            execute_result = token_score.transferFrom(_from, _to, amount)
        except:
            execute_result = False

        return execute_result

    def _transferToken(self, tokenAddress: Address, _to: Address, amount: int) -> bool:
        try:
            if tokenAddress == ICX_ADDR:
                self.icx.transfer(_to, amount)
            else:
                token_score = self.create_interface_score(tokenAddress, TokenTransferInterface)
                token_score.transfer(_to, amount)
            execute_result = True
        except:
            execute_result = False

        return execute_result

    def _transferFromNFT(self, nftAddress: Address, _from: Address, _to: Address, tokenId: int) -> bool:
        try:
            token_score = self.create_interface_score(nftAddress, NFTTransferInterface)
            token_score.transferFrom(_from, _to, tokenId)
            execute_result = True
        except:
            execute_result = False

        return execute_result

    def _transferNFT(self, nftAddress: Address, _to: Address, tokenId: int) -> bool:
        try:
            token_score = self.create_interface_score(nftAddress, NFTTransferInterface)
            token_score.transfer(_to, tokenId)
            execute_result = True
        except:
            execute_result = False

        return execute_result

    def _farmDeposit(self, proxy: Address, amount: int) -> bool:
        try:
            farm_score = self.create_interface_score(proxy, FarmInterface)
            farm_score.deposit(amount)
            execute_result = True
        except:
            execute_result = False

        return execute_result

    def _farmWithdraw(self, proxy: Address, _to: Address, amount: int) -> bool:
        try:
            farm_score = self.create_interface_score(proxy, FarmInterface)
            farm_score.withdraw(_to, amount)
            execute_result = True
        except:
            execute_result = False

        return execute_result


    def _farmWithdrawAll(self, proxy: Address) -> bool:
        try:
            farm_score = self.create_interface_score(proxy, FarmInterface)
            farm_score.withdrawAll()
            execute_result = True
        except:
            execute_result = False

        return execute_result

    def _callBridgeReceiver(self, isFungible: bool, token: Address, value: int, data: bytes, toAddr: Address) -> bool:
        try:
            receiver_score = self.create_interface_score(toAddr, BridgeReceiverInterface)
            if isFungible:
                execute_result = receiver_score.onTokenBridgeReceived(token, value, data) > 0
            else:
                execute_result = receiver_score.onNFTBridgeReceived(token, value, data) > 0
        except:
            execute_result = False

        return execute_result
