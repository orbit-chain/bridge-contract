pragma solidity ^0.5.0;

import "../multisig/MessageMultiSigWallet.sol";
import "../utils/SafeMath.sol";
import "./KlaytnMinter.sol";
import "../token/standard/IKIP7.sol";
import "../token/standard/IKIP17.sol";

interface Deployer {
    function deployToken(uint8 decimals) external returns (address);
    function deployNFT() external returns (address);
    function deployTokenWithInit(string calldata name, string calldata symbol, uint8 decimals) external returns (address);
    function deployNFTWithInit(string calldata name, string calldata symbol) external returns (address);
}

interface OrbitBridgeReceiver {
    function onTokenBridgeReceived(address _token, uint256 _value, bytes calldata _data) external returns(uint);
	function onNFTBridgeReceived(address _token, uint256 _tokenId, bytes calldata _data) external returns(uint);
}

contract KlaytnMinterImpl is KlaytnMinter, SafeMath {
    uint public bridgingFee = 0;
    address payable public feeGovernance;

    uint public taxRate;
    address public taxReceiver;
    address public tokenDeployer;

    uint public bridgingFeeWithData;
    uint public gasLimitForBridgeReceiver;

    mapping (address => uint) public minRequestAmount;

    address public policyAdmin;
    mapping(bytes32 => uint256) public chainFee;
    mapping(bytes32 => uint256) public chainFeeWithData;

    mapping(bytes32 => uint256) public chainUintsLength;
    mapping(bytes32 => uint256) public chainAddressLength;
    uint public chainTokenLength;

    mapping(address => bool) public silentTokenList;

    event Swap(string fromChain, bytes fromAddr, bytes toAddr, address tokenAddress, bytes32[] bytes32s, uint[] uints, bytes data);
    event SwapNFT(string fromChain, bytes fromAddr, bytes toAddr, address tokenAddress, bytes32[] bytes32s, uint[] uints, bytes data);

    event SwapRequest(string toChain, address fromAddr, bytes toAddr, bytes token, address tokenAddress, uint8 decimal, uint amount, uint depositId, bytes data);
    event SwapRequestNFT(string toChain, address fromAddr, bytes toAddr, bytes token, address tokenAddress, uint tokenId, uint amount, uint depositId, bytes data);
    event BridgeReceiverResult(bool success, bytes fromAddr, address tokenAddress, bytes data);

    modifier onlyActivated {
        require(isActivated);
        _;
    }

    modifier onlyPolicyAdmin {
        require(msg.sender == policyAdmin);
        _;
    }

    constructor() public KlaytnMinter(address(0), address(0), 0) {
    }

    function getVersion() public pure returns(string memory){
        return "KlaytnMinter20210817A";
    }

    function getTokenAddress(bytes memory token) public view returns(address){
        bytes32 tokenSummary = sha256(abi.encodePacked(chain, token));
        return tokenAddr[tokenSummary];
    }

    function getChainId(string memory _chain) public view returns(bytes32){
        return sha256(abi.encodePacked(address(this), _chain));
    }

    function setValidChain(string memory _chain, bool valid, uint fromAddrLen, uint uintsLen) public onlyGovernance {
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

    function setGovId(bytes32 _govId) public onlyGovernance {
        govId = _govId;
    }

    function setTaxRate(uint _taxRate) public onlyGovernance {
        require(_taxRate < 10000);
        taxRate = _taxRate;
    }

    function setTaxReceiver(address _taxReceiver) public onlyGovernance {
        require(_taxReceiver != address(0));
        taxReceiver = _taxReceiver;
    }

    function setTokenDeployer(address _deployer) public onlyGovernance {
        require(_deployer != address(0));
        tokenDeployer = _deployer;
    }

    function setPolicyAdmin(address _policyAdmin) public onlyGovernance {
        require(_policyAdmin != address(0));
        policyAdmin = _policyAdmin;
    }

    function changeActivate(bool activate) public onlyPolicyAdmin {
        isActivated = activate;
    }

    function setMinRequestSwapAmount(address _token, uint amount) public onlyPolicyAdmin {
        require(_token != address(0));
        require(tokenSummaries[_token] != 0);
        minRequestAmount[_token] = amount;
    }

    function setChainFee(string memory chainSymbol, uint256 _fee, uint256 _feeWithData) public onlyPolicyAdmin {
        bytes32 chainId = getChainId(chainSymbol);
        require(isValidChain[chainId]);

        chainFee[chainId] = _fee;
        chainFeeWithData[chainId] = _feeWithData;
    }

    function setFeeGovernance(address payable _feeGovernance) public onlyGovernance {
        require(_feeGovernance != address(0));
        feeGovernance = _feeGovernance;
    }

    function setGasLimitForBridgeReceiver(uint256 _gasLimitForBridgeReceiver) public onlyPolicyAdmin {
        gasLimitForBridgeReceiver = _gasLimitForBridgeReceiver;
    }

    function setSilentToken(address token, bool v) public onlyPolicyAdmin {
        require(token != address(0));

        silentTokenList[token] = v;
    }

    function setTokenLength(uint256 tokenLen) public onlyGovernance {
        require(tokenLen != 0);
        chainTokenLength = tokenLen;
    }

    function addToken(bytes memory token, address tokenAddress) public onlyGovernance {
        require(tokenSummaries[tokenAddress] == 0);

        bytes32 tokenSummary = sha256(abi.encodePacked(chain, token));
        require(tokenAddr[tokenSummary] == address(0));

        tokens[tokenSummary] = token;
        tokenAddr[tokenSummary] = tokenAddress;
        tokenSummaries[tokenAddress] = tokenSummary;
    }

    function addTokenWithDeploy(bool isFungible, bytes memory token, string memory name, string memory symbol, uint8 decimals) public onlyPolicyAdmin {
        bytes32 tokenSummary = sha256(abi.encodePacked(chain, token));
        require(tokenAddr[tokenSummary] == address(0));

        address tokenAddress;
        if(isFungible)
            tokenAddress = Deployer(tokenDeployer).deployTokenWithInit(name, symbol, decimals);
        else
            tokenAddress = Deployer(tokenDeployer).deployNFTWithInit(name, symbol);
        require(tokenAddress != address(0));

        tokens[tokenSummary] = token;
        tokenAddr[tokenSummary] = tokenAddress;
        tokenSummaries[tokenAddress] = tokenSummary;
    }

    // Fix Data Info
    ///@param bytes32s [0]:govId, [1]:txHash
    ///@param uints [0]:amount, [1]:decimals
    function swap(
        address hubContract,
        string memory fromChain,
        bytes memory fromAddr,
        address toAddr,
        bytes memory token,
        bytes32[] memory bytes32s,
        uint[] memory uints,
        bytes memory data,
        uint8[] memory v,
        bytes32[] memory r,
        bytes32[] memory s
    ) public onlyActivated {
        require(bytes32s.length == 2);
        require(bytes32s[0] == govId);
        require(uints.length == chainUintsLength[getChainId(fromChain)]);
        require(uints[1] <= 100);
        require(fromAddr.length == chainAddressLength[getChainId(fromChain)]);
        require(token.length == chainTokenLength);

        bytes32 hash = sha256(abi.encodePacked(hubContract, fromChain, chain, fromAddr, toAddr, token, bytes32s, uints, data));

        require(!isConfirmed[hash]);
        isConfirmed[hash] = true;

        uint validatorCount = _validate(hash, v, r, s);
        require(validatorCount >= MessageMultiSigWallet(governance).required());

        address tokenAddress = getTokenAddress(token, uints[1]);
        if(tokenAddress == address(0)){
            revert();
        }else{
            if(!IKIP7(tokenAddress).transfer(toAddr, uints[0])) revert();
        }

        if(isContract(toAddr) && data.length != 0){
            bool result;
            bytes memory callbytes = abi.encodeWithSignature("onTokenBridgeReceived(address,uint256,bytes)", tokenAddress, uints[0], data);
            if (gasLimitForBridgeReceiver > 0) {
                (result, ) = toAddr.call.gas(gasLimitForBridgeReceiver)(callbytes);
            } else {
                (result, ) = toAddr.call(callbytes);
            }
            emit BridgeReceiverResult(result, fromAddr, tokenAddress, data);
        }

        emit Swap(fromChain, fromAddr, abi.encodePacked(toAddr), tokenAddress, bytes32s, uints, data);
    }

    // Fix Data Info
    ///@param bytes32s [0]:govId, [1]:txHash
    ///@param uints [0]:amount, [1]:tokenId
    function swapNFT(
        address hubContract,
        string memory fromChain,
        bytes memory fromAddr,
        address toAddr,
        bytes memory token,
        bytes32[] memory bytes32s,
        uint[] memory uints,
        bytes memory data,
        uint8[] memory v,
        bytes32[] memory r,
        bytes32[] memory s
    ) public onlyActivated {
        require(bytes32s.length == 2);
        require(bytes32s[0] == govId);
        require(uints.length == chainUintsLength[getChainId(fromChain)]);
        require(fromAddr.length == chainAddressLength[getChainId(fromChain)]);
        require(token.length == chainTokenLength);

        bytes32 hash = sha256(abi.encodePacked("NFT", hubContract, fromChain, chain, fromAddr, toAddr, token, bytes32s, uints, data));

        require(!isConfirmed[hash]);
        isConfirmed[hash] = true;

        uint validatorCount = _validate(hash, v, r, s);
        require(validatorCount >= MessageMultiSigWallet(governance).required());

        address nftAddress = getNFTAddress(token);
        if(nftAddress == address(0)){
            revert();
        }else{
            IKIP17(nftAddress)._mint(toAddr, uints[1]);
            require(IKIP17(nftAddress).ownerOf(uints[1]) == toAddr);
        }

        if(isContract(toAddr) && data.length != 0){
            bool result;
            bytes memory callbytes = abi.encodeWithSignature("onNFTBridgeReceived(address,uint256,bytes)", nftAddress, uints[1], data);
            if (gasLimitForBridgeReceiver > 0) {
                (result, ) = toAddr.call.gas(gasLimitForBridgeReceiver)(callbytes);
            } else {
                (result, ) = toAddr.call(callbytes);
            }
            emit BridgeReceiverResult(result, fromAddr, nftAddress, data);
        }

        emit SwapNFT(fromChain, fromAddr, abi.encodePacked(toAddr), nftAddress, bytes32s, uints, data);
    }

    function requestSwap(address tokenAddress, string memory toChain, bytes memory toAddr, uint amount) public payable onlyActivated {
        require(msg.value >= chainFee[getChainId(toChain)]);
        _requestSwap(tokenAddress, toChain, toAddr, amount, "");
    }

    function requestSwap(address tokenAddress, string memory toChain, bytes memory toAddr, uint amount, bytes memory data) public payable onlyActivated {
        require(msg.value >= chainFeeWithData[getChainId(toChain)]);
        require(data.length != 0);
        _requestSwap(tokenAddress, toChain, toAddr, amount, data);
    }

    function _requestSwap(address tokenAddress, string memory toChain, bytes memory toAddr, uint amount, bytes memory data) private {
        require(isValidChain[getChainId(toChain)]);
        require(tokenAddress != address(0));
        require(amount > 0);
        require(!silentTokenList[tokenAddress]);

        _transferBridgingFee(msg.value);

        bytes32 tokenSummary = tokenSummaries[tokenAddress];
        require(tokenSummaries[tokenAddress] != 0);

        bytes memory token = tokens[tokenSummary];
        require(token.length != 0);

        if(!IKIP7(tokenAddress).transferFrom(msg.sender, address(this), amount)) revert();

        uint8 decimal = IKIP7(tokenAddress).decimals();
        require(decimal > 0);

        if(taxRate > 0 && taxReceiver != address(0)){
            uint tax = _payTax(token, tokenAddress, amount, decimal);
            amount = safeSub(amount, tax);
        }
        require(minRequestAmount[tokenAddress] <= amount);

        depositCount = depositCount + 1;
        emit SwapRequest(toChain, msg.sender, toAddr, token, tokenAddress, decimal, amount, depositCount, data);
    }

    function requestSwapNFT(address nftAddress, uint tokenId, string memory toChain, bytes memory toAddr) public payable onlyActivated {
        require(msg.value >= chainFee[getChainId(toChain)]);
        _requestSwapNFT(nftAddress, tokenId, toChain, toAddr, "");
    }

    function requestSwapNFT(address nftAddress, uint tokenId, string memory toChain, bytes memory toAddr, bytes memory data) public payable onlyActivated {
        require(msg.value >= chainFeeWithData[getChainId(toChain)]);
        require(data.length != 0);
        _requestSwapNFT(nftAddress, tokenId, toChain, toAddr, data);
    }

    function _requestSwapNFT(address nftAddress, uint tokenId, string memory toChain, bytes memory toAddr, bytes memory data) private {
        require(isValidChain[getChainId(toChain)]);
        require(nftAddress != address(0));
        require(!silentTokenList[nftAddress]);

        _transferBridgingFee(msg.value);

        bytes32 tokenSummary = tokenSummaries[nftAddress];
        require(tokenSummaries[nftAddress] != 0);

        bytes memory token = tokens[tokenSummary];
        require(token.length != 0);

        require(IKIP17(nftAddress).ownerOf(tokenId) == msg.sender);
        IKIP17(nftAddress)._burn(msg.sender, tokenId);

        depositCount = depositCount + 1;
        emit SwapRequestNFT(toChain, msg.sender, toAddr, token, nftAddress, tokenId, 1, depositCount, data);
    }

    function _validate(bytes32 whash, uint8[] memory v, bytes32[] memory r, bytes32[] memory s) private view returns(uint){
        uint validatorCount = 0;
        address[] memory vaList = new address[](MessageMultiSigWallet(governance).getOwners().length);

        uint i=0;
        uint j=0;

        for(i; i<v.length; i++){
            address va = ecrecover(whash,v[i],r[i],s[i]);
            if(MessageMultiSigWallet(governance).isOwner(va)){
                for(j=0; j<validatorCount; j++){
                    require(vaList[j] != va);
                }

                vaList[validatorCount] = va;
                validatorCount += 1;
            }
        }

        return validatorCount;
    }

    function getTokenAddress(bytes memory token, uint decimals) private returns(address tokenAddress){
        bytes32 tokenSummary = sha256(abi.encodePacked(chain, token));

        tokenAddress = tokenAddr[tokenSummary];
        if(tokenAddress == address(0)){
            require(tokenDeployer != address(0));
            tokenAddress = Deployer(tokenDeployer).deployToken(uint8(decimals));
            tokens[tokenSummary] = token;
            tokenAddr[tokenSummary] = tokenAddress;
            tokenSummaries[tokenAddress] = tokenSummary;
        }
    }

    function getNFTAddress(bytes memory token) private returns(address nftAddress){
        bytes32 tokenSummary = sha256(abi.encodePacked(chain, token));

        nftAddress = tokenAddr[tokenSummary];
        if(nftAddress == address(0)){
            require(tokenDeployer != address(0));
            nftAddress = Deployer(tokenDeployer).deployNFT();
            tokens[tokenSummary] = token;
            tokenAddr[tokenSummary] = nftAddress;
            tokenSummaries[nftAddress] = tokenSummary;
        }
    }

    function _transferBridgingFee(uint amount) private {
        require(feeGovernance != address(0));

        (bool result,) = feeGovernance.call.value(amount)("");
        if(!result){
            revert();
        }
    }

    function _payTax(bytes memory token, address tokenAddress, uint amount, uint8 decimal) private returns (uint tax) {
        tax = safeDiv(safeMul(amount, taxRate), 10000);
        if(tax > 0){
            depositCount = depositCount + 1;
            emit SwapRequest("ORBIT", msg.sender, abi.encodePacked(taxReceiver), token, tokenAddress, decimal, tax, depositCount, "");
        }
    }

    function isContract(address _addr) private view returns (bool){
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function bytesToAddress(bytes memory bys) private pure returns (address addr) {
        assembly {
            addr := mload(add(bys,20))
        }
    }

    function () payable external{
        revert();
    }
}
