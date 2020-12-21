pragma solidity ^0.5.0;

import "../multisig/MessageMultiSigWallet.sol";
import "../utils/SafeMath.sol";
import "../token/KlaytnToken.sol";
import "./KlaytnMinter.sol";

contract KlaytnMinterImpl is KlaytnMinter, SafeMath{
    event Swap(address hubContract, string fromChain, string toChain, bytes fromAddr, bytes toAddr, address tokenAddress, bytes32[] bytes32s, uint[] uints);
    event SwapRequest(string fromChain, string toChain, address fromAddr, bytes toAddr, bytes token, address tokenAddress, uint8 decimal, uint amount, uint depositId, uint block);

    modifier onlyActivated {
        require(isActivated);
        _;
    }

    constructor() public KlaytnMinter(address(0), address(0), 0) {
    }

    function getVersion() public pure returns(string memory){
        return "20201117";
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
    
    // _chain : ETH, KLAYTN, TERRA
    function setValidChain(string memory _chain, bool valid) public onlyGovernance {
        isValidChain[getChainId(_chain)] = valid;
    }

    function setGovId(bytes32 _govId) public onlyGovernance {
        govId = _govId;
    }

    function setBridgingFee(uint _bridgingFee) public onlyGovernance {
        bridgingFee = _bridgingFee;
    }

    function setFeeGovernance(address payable _feeGovernance) public onlyGovernance {
        require(_feeGovernance != address(0));
        feeGovernance = _feeGovernance;
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
    function swap(
        address hubContract,
        string memory fromChain,
        bytes memory fromAddr,
        bytes memory toAddr,
        bytes memory token,
        bytes32[] memory bytes32s,
        uint[] memory uints,
        uint8[] memory v,
        bytes32[] memory r,
        bytes32[] memory s
    ) public onlyActivated {
        require(bytes32s.length >= 1);
        require(bytes32s[0] == govId);
        require(uints.length >= 2);

        bytes32 hash = sha256(abi.encodePacked(hubContract, fromChain, chain, fromAddr, toAddr, token, bytes32s, uints));

        require(!isConfirmed[hash]);
        isConfirmed[hash] = true;

        uint validatorCount = _validate(hash, v, r, s);
        require(validatorCount >= MessageMultiSigWallet(governance).required());

        address tokenAddress = getTokenAddress(token, uints[1]); 
        if(tokenAddress == address(0)){
            revert();
        }else{
            if(!IKIP7(tokenAddress).transfer(bytesToAddress(toAddr), uints[0])) revert();
        }

        if(!isValidChain[getChainId(fromChain)]) _setValidChain(fromChain, true);

        emit Swap(hubContract, fromChain, chain, fromAddr, toAddr, tokenAddress, bytes32s, uints);
    }

    function requestSwap(address tokenAddress, string memory toChain, bytes memory toAddr, uint amount) public payable onlyActivated {
        require(isValidChain[getChainId(toChain)]);
        require(tokenAddress != address(0));
        require(amount > 0);
        require(msg.value >= bridgingFee);
        require(feeGovernance != address(0));

        _transferBridgingFee(msg.value);
        
        bytes32 tokenSummary = tokenSummaries[tokenAddress];
        require(tokenSummaries[tokenAddress] != 0);

        bytes memory token = tokens[tokenSummary];
        require(token.length != 0);

        if(!IKIP7(tokenAddress).transferFrom(msg.sender, address(this), amount)) revert();   

        uint8 decimal = IKIP7(tokenAddress).decimals();
        require(decimal > 0);

        depositCount = depositCount + 1;
        emit SwapRequest(chain, toChain, msg.sender, toAddr, token, tokenAddress, decimal, amount, depositCount, block.number);
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
            tokenAddress = deployToken(decimals);
            tokens[tokenSummary] = token;
            tokenAddr[tokenSummary] = tokenAddress;
            tokenSummaries[tokenAddress] = tokenSummary;
        }
    }

    function deployToken(uint decimals) private returns(address){
        return address(new KlaytnToken(governance, address(this), uint8(decimals)));
    }

    function _transferBridgingFee(uint amount) private {
        (bool result,) = feeGovernance.call.value(amount)("");
        if(!result){
            revert();
        }
    }

    function bytesToAddress(bytes memory bys) private pure returns (address addr) {
        assembly {
            addr := mload(add(bys,20))
        }
    }

    function _setValidChain(string memory _chain, bool valid) private {
        isValidChain[getChainId(_chain)] = valid;
    }

    function () payable external{
        revert();
    }
}
