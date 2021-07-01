pragma solidity ^0.5.0;

import "../utils/SafeMath.sol";
import "./EthVault.sol";

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function decimals() external view returns (uint8);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract TIERC20 {
    function transfer(address to, uint value) public;
    function transferFrom(address from, address to, uint value) public;

    function balanceOf(address who) public view returns (uint);
    function allowance(address owner, address spender) public view returns (uint256);

    function decimals() external view returns (uint8);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
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

interface IFarm {
    function deposit(uint amount) external;
    function withdrawAll() external;
    function withdraw(address toAddr, uint amount) external;
}

interface OrbitBridgeReceiver {
    function onTokenBridgeReceived(address _token, uint256 _value, bytes calldata _data) external returns(uint);
	function onNFTBridgeReceived(address _token, uint256 _tokenId, bytes calldata _data) external returns(uint);
}

library LibTokenManager {
    function depositToken(address payable implAddr, address token, string memory toChain, uint amount) public returns(uint8 decimal) {
        EthVaultImpl impl = EthVaultImpl(implAddr);
        require(impl.isValidChain(impl.getChainId(toChain)));
        require(amount != 0);

        if(token == address(0)){
            decimal = 18;
        }
        else if(token == impl.tetherAddress() || impl.silentTokenList(token)){
            TIERC20(token).transferFrom(msg.sender, implAddr, amount);
            decimal = TIERC20(token).decimals();
        }
        else{
            if(!IERC20(token).transferFrom(msg.sender, implAddr, amount)) revert();
            decimal = IERC20(token).decimals();
        }
        require(decimal > 0);

        address payable farm = impl.farms(token);
        if(farm != address(0)){
            _transferToken(impl, token, farm, amount);
            IFarm(farm).deposit(amount);
        }
    }
    
    function _transferToken(EthVaultImpl impl, address token, address payable destination, uint amount) public {
        if(token == address(0)){
            (bool transfered,) = destination.call.value(amount)("");
            require(transfered);
        }
        else if(token == impl.tetherAddress() || impl.silentTokenList(token)){
            TIERC20(token).transfer(destination, amount);
        }
        else{
            if(!IERC20(token).transfer(destination, amount)) revert();
        }
    }
}

library LibCallBridgeReceiver {
    event BridgeReceiverResult(bool success, address fromAddress, address tokenAddress, bytes data);
    
    function callReceiver(bool isFungible, uint gasLimitForBridgeReceiver, address tokenAddress, uint256 _int, bytes memory data, address toAddr, address fromAddr) public {
        bool result;
        bytes memory callbytes;
        if (isFungible) {
            callbytes = abi.encodeWithSignature("onTokenBridgeReceived(address,uint256,bytes)", tokenAddress, _int, data);
        } else {
            callbytes = abi.encodeWithSignature("onNFTBridgeReceived(address,uint256,bytes)", tokenAddress, _int, data);
        }
        if (gasLimitForBridgeReceiver > 0) {
            (result, ) = toAddr.call.gas(gasLimitForBridgeReceiver)(callbytes);
        } else {
            (result, ) = toAddr.call(callbytes);
        }
        emit BridgeReceiverResult(result, fromAddr, tokenAddress, data);
    }
}

contract EthVaultImpl is EthVault, SafeMath{
    uint public bridgingFee = 0;
    address payable public feeGovernance;
    mapping(address => bool) public silentTokenList;

    mapping(address => address payable) public farms;
    uint public taxRate; // 0.01% interval
    address public taxReceiver;

    uint public gasLimitForBridgeReceiver;
    
    event Deposit(string toChain, address fromAddr, bytes toAddr, address token, uint8 decimal, uint amount, uint depositId, bytes data);
    event DepositNFT(string toChain, address fromAddr, bytes toAddr, address token, uint tokenId, uint amount, uint depositId, bytes data);

    event Withdraw(string fromChain, bytes fromAddr, bytes toAddr, bytes token, bytes32[] bytes32s, uint[] uints, bytes data);
    event WithdrawNFT(string fromChain, bytes fromAddr, bytes toAddr, bytes token, bytes32[] bytes32s, uint[] uints, bytes data);

    event BridgeReceiverResult(bool success, address fromAddress, address tokenAddress, bytes data);
    
    modifier onlyActivated {
        require(isActivated);
        _;
    }

    constructor(address[] memory _owner) public EthVault(_owner, _owner.length, address(0), address(0)) {
    }

    function getVersion() public pure returns(string memory){
        return "20210310";
    }

    function changeActivate(bool activate) public onlyWallet {
        isActivated = activate;
    }

    function setTetherAddress(address tether) public onlyWallet {
        tetherAddress = tether;
    }

    function getChainId(string memory _chain) public view returns(bytes32){
        return sha256(abi.encodePacked(address(this), _chain));
    }

    function setValidChain(string memory _chain, bool valid) public onlyWallet {
        isValidChain[getChainId(_chain)] = valid;
    }

    function setSilentToken(address token, bool valid) public onlyWallet {
        silentTokenList[token] = valid;
    }
    
    function setParams(uint _taxRate, address _taxReceiver, uint _gasLimitForBridgeReceiver) public onlyWallet {
        require(_taxRate < 10000);
        require(_taxReceiver != address(0));
        taxRate = _taxRate;
        taxReceiver = _taxReceiver;
        gasLimitForBridgeReceiver = _gasLimitForBridgeReceiver;
    }

    function addFarm(address token, address payable proxy) public onlyWallet {
        require(farms[token] == address(0));

        uint amount;
        if(token == address(0)){
            amount = address(this).balance;
        }
        else{
            amount = IERC20(token).balanceOf(address(this));
        }

        LibTokenManager._transferToken(this, token, proxy, amount);
        IFarm(proxy).deposit(amount);

        farms[token] = proxy;
    }

    function removeFarm(address token, address payable newProxy) public onlyWallet {
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

            LibTokenManager._transferToken(this, token, newProxy, amount);
            IFarm(newProxy).deposit(amount);
        }

        farms[token] = newProxy;
    }
    
    function deposit(string memory toChain, bytes memory toAddr) payable public {
        _depositToken(address(0), toChain, toAddr, msg.value, "");
    }

    function deposit(string memory toChain, bytes memory toAddr, bytes memory data) payable public {
        require(data.length != 0);
        _depositToken(address(0), toChain, toAddr, msg.value, data);
    }
    
    function depositToken(address token, string memory toChain, bytes memory toAddr, uint amount) public {
        _depositToken(token, toChain, toAddr, amount, "");
    }

    function depositToken(address token, string memory toChain, bytes memory toAddr, uint amount, bytes memory data) public {
        require(data.length != 0);
        _depositToken(token, toChain, toAddr, amount, data);
    }

    function _depositToken(address token, string memory toChain, bytes memory toAddr, uint amount, bytes memory data) private onlyActivated {
        uint8 decimal = LibTokenManager.depositToken(address(this), token, toChain, amount);

        if(taxRate > 0 && taxReceiver != address(0)){
            uint tax = _payTax(token, amount, decimal);
            amount = safeSub(amount, tax);
        }

        depositCount = depositCount + 1;
        emit Deposit(toChain, msg.sender, toAddr, token, decimal, amount, depositCount, data);
    }
    
    function depositNFT(address token, string memory toChain, bytes memory toAddr, uint tokenId) public {
        _depositNFT(token, toChain, toAddr, tokenId, "");
    }
    
    function depositNFT(address token, string memory toChain, bytes memory toAddr, uint tokenId, bytes memory data) public {
        require(data.length != 0);
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
        require(validatorCount >= required);

        address payable _toAddr = bytesToAddress(toAddr);
        address tokenAddress = bytesToAddress(token);

        if(farms[tokenAddress] != address(0)){ // farmProxy 출금
            IFarm(farms[tokenAddress]).withdraw(_toAddr, uints[0]);
        }
        else{ // 일반 출금
            LibTokenManager._transferToken(this, tokenAddress, _toAddr, uints[0]);
        }

        if(isContract(_toAddr) && data.length != 0){
            address _from = bytesToAddress(fromAddr);
            LibCallBridgeReceiver.callReceiver(true, gasLimitForBridgeReceiver, tokenAddress, uints[0], data, _toAddr, _from);
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
        require(validatorCount >= required);

        address payable _toAddr = bytesToAddress(toAddr);
        address tokenAddress = bytesToAddress(token);

        require(IERC721(tokenAddress).ownerOf(uints[1]) == address(this));
        IERC721(tokenAddress).transferFrom(address(this), _toAddr, uints[1]);
        require(IERC721(tokenAddress).ownerOf(uints[1]) == _toAddr);

        if(isContract(_toAddr) && data.length != 0){
            address _from = bytesToAddress(fromAddr);
            LibCallBridgeReceiver.callReceiver(false, gasLimitForBridgeReceiver, tokenAddress, uints[1], data, _toAddr, _from);
        }
        
        emit WithdrawNFT(fromChain, fromAddr, toAddr, token, bytes32s, uints, data);
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
        tax = safeDiv(safeMul(amount, taxRate), 10000);
        if(tax > 0){
            depositCount = depositCount + 1;
            emit Deposit("ORBIT", msg.sender, abi.encodePacked(taxReceiver), token, decimal, tax, depositCount, "");
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
