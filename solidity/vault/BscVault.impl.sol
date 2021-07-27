// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./Vault.storage.sol";

library SafeMath {
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }
    
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }
    
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}

library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(account) }
        return size > 0;
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
      return functionCall(target, data, "Address: low-level call failed");
    }

    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

interface IGovernance {
    function required() external view returns(uint);
    function getOwners() external view returns(address[] memory);
    function isOwner(address owner) external view returns(bool);
}

interface IFarm {
    function deposit(uint amount) external;
    function withdrawAll() external;
    function withdraw(address toAddr, uint amount) external;
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}


interface IERC721 {
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

interface IProxy {
    function owner() external view returns (address);
    function getChain() external view returns (string memory);
    function getAdmin() external view returns (address);
    function getImplementation() external view returns (address);
}

library LibCallBridgeReceiver {
    function callReceiver(bool isFungible, uint gasLimitForBridgeReceiver, address tokenAddress, uint256 _int, bytes memory data, address toAddr) internal returns (bool){
        bool result;
        bytes memory callbytes;
        bytes memory returnbytes;
        if (isFungible) {
            callbytes = abi.encodeWithSignature("onTokenBridgeReceived(address,uint256,bytes)", tokenAddress, _int, data);
        } else {
            callbytes = abi.encodeWithSignature("onNFTBridgeReceived(address,uint256,bytes)", tokenAddress, _int, data);
        }
        if (gasLimitForBridgeReceiver > 0) {
            (result, returnbytes) = toAddr.call{gas : gasLimitForBridgeReceiver}(callbytes);
        } else {
            (result, returnbytes) = toAddr.call(callbytes);
        }

        if(!result){
            return false;
        } else {
            (uint flag) = abi.decode(returnbytes, (uint));
            return flag > 0;
        }
    }
}

contract BscVaultImpl is VaultStorage {
    using SafeERC20 for IERC20;
    using SafeMath for uint;

    event Deposit(string toChain, address fromAddr, bytes toAddr, address token, uint8 decimal, uint amount, uint depositId, bytes data);
    event DepositNFT(string toChain, address fromAddr, bytes toAddr, address token, uint tokenId, uint amount, uint depositId, bytes data);

    event Withdraw(string fromChain, bytes fromAddr, bytes toAddr, bytes token, bytes32[] bytes32s, uint[] uints, bytes data);
    event WithdrawNFT(string fromChain, bytes fromAddr, bytes toAddr, bytes token, bytes32[] bytes32s, uint[] uints, bytes data);

    event BridgeReceiverResult(bool success, bytes fromAddress, address tokenAddress, bytes data);

    constructor() public payable {
    }

    modifier onlyGovernance {
        require(msg.sender == governance_());
        _;
    }

    modifier onlyActivated {
        require(isActivated);
        _;
    }

    modifier onlyPolicyAdmin {
        require(msg.sender == policyAdmin);
        _;
    }

    function admin_() public view returns (address) {
        return IProxy(address(this)).getAdmin();
    }

    function governance_() public view returns (address) {
        return IProxy(admin_()).owner();
    }

    function getVersion() public pure returns(string memory){
        return "BscVault20210727";
    }

    function setChainSymbol(string memory _chain) public onlyGovernance {
        chain = _chain;
    }

    function getChainId(string memory chainSymbol) public view returns(bytes32){
        return sha256(abi.encodePacked(address(this), chainSymbol));
    }

    function setValidChain(string memory chainSymbol, bool valid) public onlyGovernance {
        isValidChain[getChainId(chainSymbol)] = valid;
    }

    function setTaxParams(uint _taxRate, address _taxReceiver) public onlyGovernance {
        require(_taxRate < 10000);
        require(_taxReceiver != address(0));
        taxRate = _taxRate;
        taxReceiver = _taxReceiver;
    }

    function setPolicyAdmin(address _policyAdmin) public onlyGovernance {
        require(_policyAdmin != address(0));

        policyAdmin = _policyAdmin;
    }

    function changeActivate(bool activate) public onlyPolicyAdmin {
        isActivated = activate;
    }

    function setFeeGovernance(address payable _feeGovernance) public onlyGovernance {
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

    function addFarm(address token, address payable proxy) public onlyGovernance {
        require(farms[token] == address(0));

        uint amount;
        if(token == address(0)){
            amount = address(this).balance;
        }
        else{
            amount = IERC20(token).balanceOf(address(this));
        }

        _transferToken(token, proxy, amount);
        IFarm(proxy).deposit(amount);

        farms[token] = proxy;
    }

    function removeFarm(address token, address payable newProxy) public onlyGovernance {
        require(farms[token] != address(0));

        IFarm(farms[token]).withdrawAll();

        if(newProxy != address(0)){
            uint amount;
            if(token == address(0)){
                amount = address(this).balance;
            }
            else{
                amount = IERC20(token).balanceOf(address(this));
            }

            _transferToken(token, newProxy, amount);
            IFarm(newProxy).deposit(amount);
        }

        farms[token] = newProxy;
    }

    function deposit(string memory toChain, bytes memory toAddr) payable public {
        uint256 fee = chainFee[getChainId(toChain)];
        if(fee != 0){
            require(msg.value > fee);
            _transferToken(address(0), feeGovernance, fee);
        }

        _depositToken(address(0), toChain, toAddr, (msg.value).sub(fee), "");
    }

    function deposit(string memory toChain, bytes memory toAddr, bytes memory data) payable public {
        require(data.length != 0);

        uint256 fee = chainFeeWithData[getChainId(toChain)];
        if(fee != 0){
            require(msg.value > fee);
            _transferToken(address(0), feeGovernance, fee);
        }

        _depositToken(address(0), toChain, toAddr, (msg.value).sub(fee), data);
    }

    function depositToken(address token, string memory toChain, bytes memory toAddr, uint amount) public payable {
        require(token != address(0));

        uint256 fee = chainFee[getChainId(toChain)];
        if(fee != 0){
            require(msg.value >= fee);
            _transferToken(address(0), feeGovernance, msg.value);
        }

        _depositToken(token, toChain, toAddr, amount, "");
    }

    function depositToken(address token, string memory toChain, bytes memory toAddr, uint amount, bytes memory data) public payable {
        require(token != address(0));
        require(data.length != 0);

        uint256 fee = chainFeeWithData[getChainId(toChain)];
        if(fee != 0){
            require(msg.value >= fee);
            _transferToken(address(0), feeGovernance, msg.value);
        }

        _depositToken(token, toChain, toAddr, amount, data);
    }

    function _depositToken(address token, string memory toChain, bytes memory toAddr, uint amount, bytes memory data) private onlyActivated {
        require(isValidChain[getChainId(toChain)]);
        require(amount != 0);

        uint8 decimal;
        if(token == address(0)){
            decimal = 18;
        }
        else{
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            decimal = IERC20(token).decimals();
        }
        require(decimal > 0);

        address payable farm = farms[token];
        if(farm != address(0)){
            _transferToken(token, farm, amount);
            IFarm(farm).deposit(amount);
        }

        if(taxRate > 0 && taxReceiver != address(0)){
            uint tax = _payTax(token, amount, decimal);
            amount = amount.sub(tax);
        }

        depositCount = depositCount + 1;
        emit Deposit(toChain, msg.sender, toAddr, token, decimal, amount, depositCount, data);
    }

    function depositNFT(address token, string memory toChain, bytes memory toAddr, uint tokenId) public payable {
        uint256 fee = chainFee[getChainId(toChain)];
        if(fee != 0){
            require(msg.value >= fee);
            _transferToken(address(0), feeGovernance, msg.value);
        }

        _depositNFT(token, toChain, toAddr, tokenId, "");
    }

    function depositNFT(address token, string memory toChain, bytes memory toAddr, uint tokenId, bytes memory data) public payable {
        require(data.length != 0);

        uint256 fee = chainFeeWithData[getChainId(toChain)];
        if(fee != 0){
            require(msg.value >= fee);
            _transferToken(address(0), feeGovernance, msg.value);
        }

        _depositNFT(token, toChain, toAddr, tokenId, data);
    }

    function _depositNFT(address token, string memory toChain, bytes memory toAddr, uint tokenId, bytes memory data) private onlyActivated {
        require(isValidChain[getChainId(toChain)]);
        require(token != address(0));
        require(IERC721(token).ownerOf(tokenId) == msg.sender);

        IERC721(token).transferFrom(msg.sender, address(this), tokenId);
        require(IERC721(token).ownerOf(tokenId) == address(this));

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
        bytes memory toAddr,
        bytes memory token,
        bytes32[] memory bytes32s,
        uint[] memory uints,
        bytes memory data,
        uint8[] memory v,
        bytes32[] memory r,
        bytes32[] memory s
    ) public onlyActivated {
        require(bytes32s.length >= 1);
        require(uints.length >= 2);
        require(bytes32s[0] == sha256(abi.encodePacked(hubContract, chain, address(this))));
        require(isValidChain[getChainId(fromChain)]);

        bytes32 whash = sha256(abi.encodePacked(hubContract, fromChain, chain, fromAddr, toAddr, token, bytes32s, uints, data));

        require(!isUsedWithdrawal[whash]);
        isUsedWithdrawal[whash] = true;

        uint validatorCount = _validate(whash, v, r, s);
        require(validatorCount >= IGovernance(governance_()).required());

        address payable _toAddr = bytesToAddress(toAddr);
        address tokenAddress = bytesToAddress(token);

        if(farms[tokenAddress] != address(0)){ // farmProxy 출금
            IFarm(farms[tokenAddress]).withdraw(_toAddr, uints[0]);
        }
        else{ // 일반 출금
            _transferToken(tokenAddress, _toAddr, uints[0]);
        }

        if(isContract(_toAddr) && data.length != 0){
            bool result = LibCallBridgeReceiver.callReceiver(true, gasLimitForBridgeReceiver, tokenAddress, uints[0], data, _toAddr);
            emit BridgeReceiverResult(result, fromAddr, tokenAddress, data);
        }

        emit Withdraw(fromChain, fromAddr, toAddr, token, bytes32s, uints, data);
    }

    // Fix Data Info
    ///@param bytes32s [0]:govId, [1]:txHash
    ///@param uints [0]:amount, [1]:tokenId
    function withdrawNFT(
        address hubContract,
        string memory fromChain,
        bytes memory fromAddr,
        bytes memory toAddr,
        bytes memory token,
        bytes32[] memory bytes32s,
        uint[] memory uints,
        bytes memory data,
        uint8[] memory v,
        bytes32[] memory r,
        bytes32[] memory s
    ) public onlyActivated {
        require(bytes32s.length >= 1);
        require(uints.length >= 2);
        require(bytes32s[0] == sha256(abi.encodePacked(hubContract, chain, address(this))));
        require(isValidChain[getChainId(fromChain)]);

        bytes32 whash = sha256(abi.encodePacked("NFT", hubContract, fromChain, chain, fromAddr, toAddr, token, bytes32s, uints, data));

        require(!isUsedWithdrawal[whash]);
        isUsedWithdrawal[whash] = true;

        uint validatorCount = _validate(whash, v, r, s);
        require(validatorCount >= IGovernance(governance_()).required());

        address payable _toAddr = bytesToAddress(toAddr);
        address tokenAddress = bytesToAddress(token);

        require(IERC721(tokenAddress).ownerOf(uints[1]) == address(this));
        IERC721(tokenAddress).transferFrom(address(this), _toAddr, uints[1]);
        require(IERC721(tokenAddress).ownerOf(uints[1]) == _toAddr);

        if(isContract(_toAddr) && data.length != 0){
            bool result = LibCallBridgeReceiver.callReceiver(false, gasLimitForBridgeReceiver, tokenAddress, uints[1], data, _toAddr);
            emit BridgeReceiverResult(result, fromAddr, tokenAddress, data);
        }

        emit WithdrawNFT(fromChain, fromAddr, toAddr, token, bytes32s, uints, data);
    }

    function _validate(bytes32 whash, uint8[] memory v, bytes32[] memory r, bytes32[] memory s) private view returns(uint){
        uint validatorCount = 0;
        IGovernance mig = IGovernance(governance_());
        address[] memory vaList = new address[](mig.getOwners().length);

        uint i=0;
        uint j=0;

        for(i; i<v.length; i++){
            address va = ecrecover(whash,v[i],r[i],s[i]);
            if(mig.isOwner(va)){
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
            (bool transfered,) = destination.call{value : amount}("");
            require(transfered);
        }
        else{
            IERC20(token).safeTransfer(destination, amount);
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

    receive () external payable { }
    fallback () external payable { }
}
