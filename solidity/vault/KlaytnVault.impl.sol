pragma solidity 0.5.0;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(account) }
        return size > 0;
    }
}

interface IKIP7 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

library SafeKIP7 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IKIP7 token, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IKIP7 token, address from, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IKIP7 token, address spender, uint256 value) internal {
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeKIP7: approve from non-zero to non-zero allowance"
        );
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IKIP7 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IKIP7 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeKIP7: decreased allowance below zero");
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function callOptionalReturn(IKIP7 token, bytes memory data) private {
        require(address(token).isContract(), "SafeKIP7: call to non-contract");

        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeKIP7: low-level call failed");

        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeKIP7: KIP7 operation did not succeed");
        }
    }
}

interface IKIP17 {
    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address operator);
    function setApprovalForAll(address operator, bool _approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
}

interface IFarm {
    function orbitVault() external view returns (address);
    function withdrawAll() external;
}

interface OrbitBridgeReceiver {
    function onTokenBridgeReceived(address _token, uint256 _value, bytes calldata _data) external returns(uint);
	function onNFTBridgeReceived(address _token, uint256 _tokenId, bytes calldata _data) external returns(uint);
}

library LibCallBridgeReceiver {
    function callReceiver(bool isFungible, uint gasLimitForBridgeReceiver, address tokenAddress, uint256 _int, bytes memory data, address toAddr) internal returns (bool, bytes memory){
        bool result;
        bytes memory callbytes;
        bytes memory returnbytes;
        if (isFungible) {
            callbytes = abi.encodeWithSignature("onTokenBridgeReceived(address,uint256,bytes)", tokenAddress, _int, data);
        } else {
            callbytes = abi.encodeWithSignature("onNFTBridgeReceived(address,uint256,bytes)", tokenAddress, _int, data);
        }
        if (gasLimitForBridgeReceiver > 0) {
            (result, returnbytes) = toAddr.call.gas(gasLimitForBridgeReceiver)(callbytes);
        } else {
            (result, returnbytes) = toAddr.call(callbytes);
        }

        return (result, returnbytes);
    }
}

contract KlaytnVaultStorage {
    /////////////////////////////////////////////////////////////////////////
    // MultiSigWallet.sol
    uint constant public MAX_OWNER_COUNT = 50;
    mapping (uint => Transaction) public transactions;
    mapping (uint => mapping (address => bool)) public confirmations;
    mapping (address => bool) public isOwner;
    address[] public owners;
    uint public required;
    uint public transactionCount;
    struct Transaction {
        address destination;
        uint value;
        bytes data;
        bool executed;
    }
    /////////////////////////////////////////////////////////////////////////

    /////////////////////////////////////////////////////////////////////////
    // Vault
    string public constant chain = "KLAYTN";
    bool public isActivated;
    address payable public implementation;
    uint public depositCount;
    mapping(bytes32 => bool) public isUsedWithdrawal;
    mapping(bytes32 => address) public tokenAddr;
    mapping(address => bytes32) public tokenSummaries;
    mapping(bytes32 => bool) public isValidChain;

    uint public bridgingFee;
    address public feeTokenAddress;
    address payable public feeGovernance;
    mapping(address => bool) public silentTokenList;
    mapping(address => address payable) public farms;
    uint public taxRate; // 0.01% interval
    address public taxReceiver;
    uint public gasLimitForBridgeReceiver;

    address public policyAdmin;
    mapping(bytes32 => uint256) public chainFee;
    mapping(bytes32 => uint256) public chainFeeWithData;

    mapping(bytes32 => uint256) public chainUintsLength;
    mapping(bytes32 => uint256) public chainAddressLength;

    mapping(address => bool) public nonTaxable;
    /////////////////////////////////////////////////////////////////////////
}

contract KlaytnVaultImpl is KlaytnVaultStorage {
    using SafeKIP7 for IKIP7;
    using SafeMath for uint;

    event Deposit(string toChain, address fromAddr, bytes toAddr, address token, uint8 decimal, uint amount, uint depositId, bytes data);
    event DepositNFT(string toChain, address fromAddr, bytes toAddr, address token, uint tokenId, uint amount, uint depositId, bytes data);

    event Withdraw(string fromChain, bytes fromAddr, bytes toAddr, bytes token, bytes32[] bytes32s, uint[] uints, bytes data);
    event WithdrawNFT(string fromChain, bytes fromAddr, bytes toAddr, bytes token, bytes32[] bytes32s, uint[] uints, bytes data);

    event BridgeReceiverResult(bool success, bytes fromAddress, address tokenAddress, bytes data);
    event OnBridgeReceived(bool result, bytes returndata, bytes fromAddr, address tokenAddress, bytes data);

    modifier onlyActivated {
        require(isActivated);
        _;
    }

    modifier onlyWallet {
        require(msg.sender == address(this));
        _;
    }

    modifier onlyPolicyAdmin {
        require(msg.sender == policyAdmin);
        _;
    }

    constructor() public payable { }

    function getVersion() public pure returns(string memory){
        return "KlaytnVault20221020";
    }

    function getChainId(string memory _chain) public view returns(bytes32){
        return sha256(abi.encodePacked(address(this), _chain));
    }

    function setUsedWithdrawal(bytes32 whash, bool v) public {
        require(msg.sender == address(this) || msg.sender == policyAdmin);

        if(msg.sender == policyAdmin) v = true;
        isUsedWithdrawal[whash] = v;
    }

    function setValidChain(string memory _chain, bool valid, uint fromAddrLen, uint uintsLen) public onlyWallet {
        bytes32 chainId = getChainId(_chain);
        require(chainId != getChainId(chain));
        isValidChain[chainId] = valid;
        if(valid){
            chainAddressLength[chainId] = fromAddrLen;
            chainUintsLength[chainId] = uintsLen;
        }
        else{
            chainAddressLength[chainId] = 0;
            chainUintsLength[chainId] = 0;
        }
    }

    function setTaxParams(uint _taxRate, address _taxReceiver) public onlyWallet {
        require(_taxRate < 10000);
        require(_taxReceiver != address(0));
        taxRate = _taxRate;
        taxReceiver = _taxReceiver;
    }

    function setPolicyAdmin(address _policyAdmin) public onlyWallet {
        require(_policyAdmin != address(0));

        policyAdmin = _policyAdmin;
    }

    function changeActivate(bool activate) public onlyPolicyAdmin {
        isActivated = activate;
    }

    function setSilentToken(address token, bool v) public onlyPolicyAdmin {
        require(token != address(0));

        silentTokenList[token] = v;
    }

    function setFeeGovernance(address payable _feeGovernance) public onlyWallet {
        require(_feeGovernance != address(0));

        feeGovernance = _feeGovernance;
    }

    function setChainFee(string memory chainSymbol, uint256 _fee, uint256 _feeWithData) public onlyPolicyAdmin {
        bytes32 chainId = getChainId(chainSymbol);
        require(isValidChain[chainId]);

        chainFee[chainId] = _fee;
        chainFeeWithData[chainId] = _feeWithData;
    }

    function setGasLimitForBridgeReceiver(uint256 _gasLimitForBridgeReceiver) public onlyPolicyAdmin {
        gasLimitForBridgeReceiver = _gasLimitForBridgeReceiver;
    }

    function setNonTaxableAddress(address target, bool valid) public onlyWallet {
        nonTaxable[target] = valid;
    }

    function addFarm(address token, address payable proxy) public onlyWallet {
        require(farms[token] == address(0));
        require(IFarm(proxy).orbitVault() == address(this));
        farms[token] = proxy;
    }

    function removeFarm(address token, address payable newProxy) public onlyWallet {
        address curFarm = farms[token];
        require(curFarm != address(0));

        IFarm(curFarm).withdrawAll();

        if(newProxy != address(0)){
            require(IFarm(newProxy).orbitVault() == address(this));
        }

        farms[token] = newProxy;
    }

    function transferToFarm(address token, uint256 amount) public {
        require(farms[token] != address(0));
        require(msg.sender == farms[token]);

        _transferToken(token, msg.sender, amount);
    }

    function deposit(string memory toChain, bytes memory toAddr) payable public {
        uint256 fee = chainFee[getChainId(toChain)];
        if(fee != 0 && !nonTaxable[msg.sender]){
            require(msg.value > fee);
            _transferToken(address(0), feeGovernance, fee);
        }

        _depositToken(address(0), toChain, toAddr, !nonTaxable[msg.sender] ? (msg.value).sub(fee) : msg.value, "");
    }

    function deposit(string memory toChain, bytes memory toAddr, bytes memory data) payable public {
        require(data.length != 0);

        uint256 fee = chainFeeWithData[getChainId(toChain)];
        if(fee != 0 && !nonTaxable[msg.sender]){
            require(msg.value > fee);
            _transferToken(address(0), feeGovernance, fee);
        }

        _depositToken(address(0), toChain, toAddr, !nonTaxable[msg.sender] ? (msg.value).sub(fee) : msg.value, data);
    }

    function depositToken(address token, string memory toChain, bytes memory toAddr, uint amount) public payable {
        require(token != address(0));

        uint256 fee = chainFee[getChainId(toChain)];
        if(fee != 0 && !nonTaxable[msg.sender]){
            require(msg.value >= fee);
            _transferToken(address(0), feeGovernance, msg.value);
        }

        _depositToken(token, toChain, toAddr, amount, "");
    }

    function depositToken(address token, string memory toChain, bytes memory toAddr, uint amount, bytes memory data) public payable {
        require(token != address(0));
        require(data.length != 0);

        uint256 fee = chainFeeWithData[getChainId(toChain)];
        if(fee != 0 && !nonTaxable[msg.sender]){
            require(msg.value >= fee);
            _transferToken(address(0), feeGovernance, msg.value);
        }

        _depositToken(token, toChain, toAddr, amount, data);
    }

    function _depositToken(address token, string memory toChain, bytes memory toAddr, uint amount, bytes memory data) private onlyActivated {
        require(isValidChain[getChainId(toChain)]);
        require(amount != 0);
        require(!silentTokenList[token]);

        uint8 decimal;
        if(token == address(0)){
            decimal = 18;
        }
        else{
            IKIP7(token).safeTransferFrom(msg.sender, address(this), amount);
            decimal = IKIP7(token).decimals();
        }
        require(decimal > 0);

        if(taxRate > 0 && taxReceiver != address(0) && !nonTaxable[msg.sender]){
            uint tax = _payTax(token, amount, decimal);
            amount = amount.sub(tax);
        }

        depositCount = depositCount + 1;
        emit Deposit(toChain, msg.sender, toAddr, token, decimal, amount, depositCount, data);
    }

    function depositNFT(address token, string memory toChain, bytes memory toAddr, uint tokenId) public payable {
        uint256 fee = chainFee[getChainId(toChain)];
        if(fee != 0 && !nonTaxable[msg.sender]){
            require(msg.value >= fee);
            _transferToken(address(0), feeGovernance, msg.value);
        }

        _depositNFT(token, toChain, toAddr, tokenId, "");
    }

    function depositNFT(address token, string memory toChain, bytes memory toAddr, uint tokenId, bytes memory data) public payable {
        require(data.length != 0);

        uint256 fee = chainFeeWithData[getChainId(toChain)];
        if(fee != 0 && !nonTaxable[msg.sender]){
            require(msg.value >= fee);
            _transferToken(address(0), feeGovernance, msg.value);
        }

        _depositNFT(token, toChain, toAddr, tokenId, data);
    }

    function _depositNFT(address token, string memory toChain, bytes memory toAddr, uint tokenId, bytes memory data) private onlyActivated {
        require(isValidChain[getChainId(toChain)]);
        require(token != address(0));
        require(IKIP17(token).ownerOf(tokenId) == msg.sender);
        require(!silentTokenList[token]);

        IKIP17(token).transferFrom(msg.sender, address(this), tokenId);
        require(IKIP17(token).ownerOf(tokenId) == address(this));

        depositCount = depositCount + 1;
        emit DepositNFT(toChain, msg.sender, toAddr, token, tokenId, 1, depositCount, data);
    }

    // Fix Data Info
    ///@param bytes32s [0]:govId, [1]:txHash
    ///@param uints [0]:amount, [1]:decimal
    function withdraw(
        address hubContract,
        string memory fromChain,
        bytes memory fromAddr,
        address payable toAddr,
        address token,
        bytes32[] memory bytes32s,
        uint[] memory uints,
        bytes memory data,
        uint8[] memory v,
        bytes32[] memory r,
        bytes32[] memory s
    ) public onlyActivated {
        require(bytes32s.length == 2);
        require(uints.length == chainUintsLength[getChainId(fromChain)]);
        require(uints[1] <= 100);
        require(fromAddr.length == chainAddressLength[getChainId(fromChain)]);

        require(bytes32s[0] == sha256(abi.encodePacked(hubContract, chain, address(this))));
        require(isValidChain[getChainId(fromChain)]);

        {
        bytes32 whash = sha256(abi.encodePacked(hubContract, fromChain, chain, fromAddr, toAddr, token, bytes32s, uints, data));

        require(!isUsedWithdrawal[whash]);
        isUsedWithdrawal[whash] = true;

        uint validatorCount = _validate(whash, v, r, s);
        require(validatorCount >= required);
        }

        _transferToken(token, toAddr, uints[0]);

        if(isContract(toAddr) && data.length != 0){
            (bool result, bytes memory returndata) = LibCallBridgeReceiver.callReceiver(true, gasLimitForBridgeReceiver, token, uints[0], data, toAddr);
            emit BridgeReceiverResult(result, fromAddr, token, data);
            emit OnBridgeReceived(result, returndata, fromAddr, token, data);
        }

        emit Withdraw(fromChain, fromAddr, abi.encodePacked(toAddr), abi.encodePacked(token), bytes32s, uints, data);
    }

    // Fix Data Info
    ///@param bytes32s [0]:govId, [1]:txHash
    ///@param uints [0]:amount, [1]:tokenId
    function withdrawNFT(
        address hubContract,
        string memory fromChain,
        bytes memory fromAddr,
        address payable toAddr,
        address token,
        bytes32[] memory bytes32s,
        uint[] memory uints,
        bytes memory data,
        uint8[] memory v,
        bytes32[] memory r,
        bytes32[] memory s
    ) public onlyActivated {
        require(bytes32s.length == 2);
        require(uints.length == chainUintsLength[getChainId(fromChain)]);
        require(fromAddr.length == chainAddressLength[getChainId(fromChain)]);

        require(bytes32s[0] == sha256(abi.encodePacked(hubContract, chain, address(this))));
        require(isValidChain[getChainId(fromChain)]);

        {
        bytes32 whash = sha256(abi.encodePacked("NFT", hubContract, fromChain, chain, fromAddr, toAddr, token, bytes32s, uints, data));

        require(!isUsedWithdrawal[whash]);
        isUsedWithdrawal[whash] = true;

        uint validatorCount = _validate(whash, v, r, s);
        require(validatorCount >= required);
        }

        require(IKIP17(token).ownerOf(uints[1]) == address(this));
        IKIP17(token).transferFrom(address(this), toAddr, uints[1]);
        require(IKIP17(token).ownerOf(uints[1]) == toAddr);

        if(isContract(toAddr) && data.length != 0){
            (bool result, bytes memory returndata) = LibCallBridgeReceiver.callReceiver(false, gasLimitForBridgeReceiver, token, uints[1], data, toAddr);
            emit BridgeReceiverResult(result, fromAddr, token, data);
            emit OnBridgeReceived(result, returndata, fromAddr, token, data);
        }

        emit WithdrawNFT(fromChain, fromAddr, abi.encodePacked(toAddr), abi.encodePacked(token), bytes32s, uints, data);
    }

    function _validate(bytes32 whash, uint8[] memory v, bytes32[] memory r, bytes32[] memory s) private view returns(uint){
        uint validatorCount = 0;
        address[] memory vaList = new address[](owners.length);

        uint i=0;
        uint j=0;

        for(i; i<v.length; i++){
            address va = ecrecover(whash,v[i],r[i],s[i]);
            if(isOwner[va]){
                for(j=0; j<validatorCount; j++){
                    require(vaList[j] != va);
                }

                vaList[validatorCount] = va;
                validatorCount += 1;
            }
        }

        return validatorCount;
    }

    function _payTax(address token, uint amount, uint8 decimal) private returns (uint tax) {
        tax = amount.mul(taxRate).div(10000);
        if(tax > 0){
            depositCount = depositCount + 1;
            emit Deposit("ORBIT", msg.sender, abi.encodePacked(taxReceiver), token, decimal, tax, depositCount, "");
        }
    }

    function _transferToken(address token, address payable destination, uint amount) private {
        if(token == address(0)){
            require((address(this)).balance >= amount);
            (bool transfered,) = destination.call.value(amount)("");
            require(transfered);
        }
        else{
            require(IKIP7(token).balanceOf(address(this)) >= amount);
            IKIP7(token).safeTransfer(destination, amount);
        }
    }

    function isContract(address _addr) private view returns (bool){
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function bytesToAddress(bytes memory bys) public pure returns (address payable addr) {
        assembly {
            addr := mload(add(bys,20))
        }
    }

    function () payable external{
    }
}