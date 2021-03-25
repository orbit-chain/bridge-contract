pragma solidity 0.5.0;

import "../multisig/MessageMultiSigWallet.sol";
import "../utils/SafeMath.sol";
import "./OrbitMinter.sol";
import "../token/standard/IKIP7.sol";
import "../token/standard/IKIP17.sol";

interface Deployer {
    function deployToken(uint8 decimals) external returns (address);
    function deployNFT() external returns (address);
}

interface OrbitBridgeReceiver {
    function onTokenBridgeReceived(address _token, uint256 _value, bytes calldata _data) external returns(uint);
	function onNFTBridgeReceived(address _token, uint256 _tokenId, bytes calldata _data) external returns(uint);
}

interface OrbitHubLike {
    function getBridgeContract(string calldata) external view returns(address);
    function getBridgeMig(string calldata, bytes32) external view returns(address);
}

contract OrbitMinterImpl is OrbitMinter, SafeMath {
    uint public bridgingFeeWithData;
    uint public gasLimitForBridgeReceiver;
    
    event Swap(string fromChain, bytes fromAddr, bytes toAddr, address tokenAddress, bytes32[] bytes32s, uint[] uints, bytes data);
    event SwapNFT(string fromChain, bytes fromAddr, bytes toAddr, address tokenAddress, bytes32[] bytes32s, uint[] uints, bytes data);

    event SwapRequest(string toChain, address fromAddr, bytes toAddr, bytes token, address tokenAddress, uint8 decimal, uint amount, uint depositId, bytes data);
    event SwapRequestNFT(string toChain, address fromAddr, bytes toAddr, bytes token, address tokenAddress, uint tokenId, uint amount, uint depositId, bytes data);

    event BridgeReceiverResult(bool success, bytes fromAddr, address tokenAddress, bytes data);
    
    event TaxPay(address fromAddr, address taxAddr, address tokenAddr, uint amount, uint tax);

    modifier onlyActivated {
        require(isActivated);
        _;
    }

    modifier onlyBridgeContract {
        require(msg.sender == OrbitHubLike(hubContract).getBridgeContract(chain));
        _;
    }

    constructor() public OrbitMinter(address(0), address(0), 0) {
    }

    function getVersion() public pure returns(string memory){
        return "20210325";
    }

    function getTokenAddress(bytes memory token) public view returns(address){
        bytes32 tokenSummary = sha256(abi.encodePacked(chain, token));
        return tokenAddr[tokenSummary];
    }

    function getChainId(string memory _chain) public view returns(bytes32){
        return sha256(abi.encodePacked(address(this), _chain));
    }

    function changeActivate(bool activate) public onlyGovernance {
        isActivated = activate;
    }

    function setValidChain(string memory _chain, bool valid) public onlyGovernance {
        isValidChain[getChainId(_chain)] = valid;
    }

    function setGovId(bytes32 _govId) public onlyGovernance {
        govId = _govId;
    }

    function setBridgingParams(uint _bridgingFee, uint _bridgingFeeWithData, uint _gasLimitForBridgeReceiver) public onlyGovernance {
        bridgingFee = _bridgingFee;
        bridgingFeeWithData = _bridgingFeeWithData;
        gasLimitForBridgeReceiver = _gasLimitForBridgeReceiver;
    }

    function setFeeTokenAddress(address _feeTokenAddress) public onlyGovernance {
        feeTokenAddress = _feeTokenAddress;
    }

    function setFeeGovernance(address payable _feeGovernance) public onlyGovernance {
        require(_feeGovernance != address(0));
        feeGovernance = _feeGovernance;
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

    function setHubContract(address _hubContract) public onlyGovernance {
        require(_hubContract != address(0));
        hubContract = _hubContract;
    }

    function addToken(bytes memory token, address tokenAddress) public onlyGovernance {
        require(tokenSummaries[tokenAddress] == 0);

        bytes32 tokenSummary = sha256(abi.encodePacked(chain, token));
        require(tokenAddr[tokenSummary] == address(0));

        tokens[tokenSummary] = token;
        tokenAddr[tokenSummary] = tokenAddress;
        tokenSummaries[tokenAddress] = tokenSummary;
    }

    // Fix Data Info
    ///@param bytes32s [0]:govId, [1]:txHash
    ///@param uints [0]:amount, [1]:decimals
    function swap(string memory fromChain, bytes memory fromAddr, bytes memory toAddr, bytes memory token, bytes32[] memory bytes32s, uint[] memory uints, bytes memory data) public onlyBridgeContract {
        require(bytes32s[0] == govId);
        require(bytes32s.length >= 1);
        require(uints.length >= 2);

        bytes32 hash = sha256(abi.encodePacked(hubContract, fromChain, chain, fromAddr, toAddr, token, bytes32s, uints, data));
        require(!isConfirmed[hash]);
        isConfirmed[hash] = true;

        (uint validatorCount, uint requireCount) = _validate(hash);
        require(validatorCount >= requireCount);

        address tokenAddress = getTokenAddress(token, uints[1]);
        if(tokenAddress == address(0)){
            revert();
        }else{
            if(!IKIP7(tokenAddress).transfer(bytesToAddress(toAddr), uints[0])) revert();
        }

        if(isContract(bytesToAddress(toAddr)) && data.length != 0){
            bool result;
            bytes memory callbytes = abi.encodeWithSignature("onTokenBridgeReceived(address,uint256,bytes)", tokenAddress, uints[0], data);
            if (gasLimitForBridgeReceiver > 0) {
                (result, ) = bytesToAddress(toAddr).call.gas(gasLimitForBridgeReceiver)(callbytes);
            } else {
                (result, ) = bytesToAddress(toAddr).call(callbytes);
            }
            emit BridgeReceiverResult(result, fromAddr, tokenAddress, data);
        }

        if(!isValidChain[getChainId(fromChain)]) _setValidChain(fromChain, true);

        emit Swap(fromChain, fromAddr, toAddr, tokenAddress, bytes32s, uints, data);
    }

    // Fix Data Info
    ///@param bytes32s [0]:govId, [1]:txHash
    ///@param uints [0]:amount, [1]:tokenId
    function swapNFT(string memory fromChain, bytes memory fromAddr, bytes memory toAddr, bytes memory token, bytes32[] memory bytes32s, uint[] memory uints, bytes memory data) public onlyBridgeContract {
        require(bytes32s.length >= 1);
        require(bytes32s[0] == govId);
        require(uints.length >= 2);

        bytes32 hash = sha256(abi.encodePacked("NFT", hubContract, fromChain, chain, fromAddr, toAddr, token, bytes32s, uints, data));
        require(!isConfirmed[hash]);
        isConfirmed[hash] = true;

        (uint validatorCount, uint requireCount) = _validate(hash);
        require(validatorCount >= requireCount);

        address nftAddress = getNFTAddress(token);
        if(nftAddress == address(0)){
            revert();
        }else{
            IKIP17(nftAddress)._mint(bytesToAddress(toAddr), uints[1]);
            require(IKIP17(nftAddress).ownerOf(uints[1]) == bytesToAddress(toAddr));
        }

        if(isContract(bytesToAddress(toAddr)) && data.length != 0){
            bool result;
            bytes memory callbytes = abi.encodeWithSignature("onNFTBridgeReceived(address,uint256,bytes)", nftAddress, uints[1], data);
            if (gasLimitForBridgeReceiver > 0) {
                (result, ) = bytesToAddress(toAddr).call.gas(gasLimitForBridgeReceiver)(callbytes);
            } else {
                (result, ) = bytesToAddress(toAddr).call(callbytes);
            }
            emit BridgeReceiverResult(result, fromAddr, nftAddress, data);
        }

        if(!isValidChain[getChainId(fromChain)]) _setValidChain(fromChain, true);

        emit SwapNFT(fromChain, fromAddr, toAddr, nftAddress, bytes32s, uints, data);
    }

    function requestSwap(address tokenAddress, string memory toChain, bytes memory toAddr, uint amount) public {
        _requestSwap(tokenAddress, toChain, toAddr, amount, "", bridgingFee);
    }

    function requestSwap(address tokenAddress, string memory toChain, bytes memory toAddr, uint amount, bytes memory data) public {
        require(data.length != 0);
        _requestSwap(tokenAddress, toChain, toAddr, amount, data, bridgingFeeWithData);
    }

    function _requestSwap(address tokenAddress, string memory toChain, bytes memory toAddr, uint amount, bytes memory data, uint feeAmount) private onlyActivated {
        require(isValidChain[getChainId(toChain)]);
        require(tokenAddress != address(0));

        _transferBridgingFee(feeAmount);

        bytes32 tokenSummary = tokenSummaries[tokenAddress];
        require(tokenSummaries[tokenAddress] != 0);

        bytes memory token = tokens[tokenSummary];
        require(token.length != 0);

        if(!IKIP7(tokenAddress).transferFrom(msg.sender, address(this), amount)) revert();

        uint8 decimal = IKIP7(tokenAddress).decimals();
        require(decimal > 0);

        if(taxRate > 0 && taxReceiver != address(0)){
            uint tax = _payTax(tokenAddress, amount);
            amount = safeSub(amount, tax);
        }

        depositCount = depositCount + 1;
        emit SwapRequest(toChain, msg.sender, toAddr, token, tokenAddress, decimal, amount, depositCount, data);
    }

    function requestSwapNFT(address nftAddress, uint tokenId, string memory toChain, bytes memory toAddr) public {
        _requestSwapNFT(nftAddress, tokenId, toChain, toAddr, "", bridgingFee);
    }
    
    function requestSwapNFT(address nftAddress, uint tokenId, string memory toChain, bytes memory toAddr, bytes memory data) public {
        require(data.length != 0);
        _requestSwapNFT(nftAddress, tokenId, toChain, toAddr, data, bridgingFeeWithData);
    }

    function _requestSwapNFT(address nftAddress, uint tokenId, string memory toChain, bytes memory toAddr, bytes memory data, uint feeAmount) private onlyActivated {
        require(isValidChain[getChainId(toChain)]);
        require(nftAddress != address(0));

        _transferBridgingFee(feeAmount);

        bytes32 tokenSummary = tokenSummaries[nftAddress];
        require(tokenSummaries[nftAddress] != 0);

        bytes memory token = tokens[tokenSummary];
        require(token.length != 0);

        require(IKIP17(nftAddress).ownerOf(tokenId) == msg.sender);
        IKIP17(nftAddress)._burn(msg.sender, tokenId);

        depositCount = depositCount + 1;
        emit SwapRequestNFT(toChain, msg.sender, toAddr, token, nftAddress, tokenId, 1, depositCount, data);
    }

    function _validate(bytes32 hash) private view returns(uint, uint) {
        MessageMultiSigWallet mig = MessageMultiSigWallet(governance);
        return (mig.validateCount(hash), mig.required());
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

    function _transferBridgingFee(uint feeAmount) private {
        if (feeTokenAddress == address(0)) {
            return;
        }
        
        if (feeGovernance == address(0)) {
            return;
        }
        
        if(!IKIP7(feeTokenAddress).transferFrom(msg.sender, feeGovernance, feeAmount)) revert();
    }

    function _payTax(address tokenAddress, uint amount) private returns (uint tax) {
        tax = safeDiv(safeMul(amount, taxRate), 10000);
        if(tax > 0){
            if(!IKIP7(tokenAddress).transfer(taxReceiver, tax)) revert();
            emit TaxPay(msg.sender, taxReceiver, tokenAddress, amount, tax);
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

    function _setValidChain(string memory _chain, bool valid) private {
        isValidChain[getChainId(_chain)] = valid;
    }

    function () payable external {
        revert();
    }
}
