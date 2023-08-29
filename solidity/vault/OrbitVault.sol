pragma solidity ^0.5.0;

import "../multisig/MessageMultiSigWallet.sol";

contract OrbitVault is MessageMultiSigWallet{
    string public constant chain = "ORBIT";
    bool public isActivated = true;
    address payable public implementation;
    uint public depositCount;
    mapping(bytes32 => bool) public isUsedWithdrawal;
    mapping(bytes32 => address) public tokenAddr;
    mapping(address => bytes32) public tokenSummaries;
    mapping(bytes32 => bool) public isValidChain;

    uint public bridgingFee = 0;
    address public feeTokenAddress;
    address payable public feeGovernance;
    mapping(address => bool) public silentTokenList;
    mapping(address => address payable) public farms;
    uint public taxRate;
    address public taxReceiver;
    uint public gasLimitForBridgeReceiver;

    address public policyAdmin;
    mapping(bytes32 => uint256) public chainFee;
    mapping(bytes32 => uint256) public chainFeeWithData;
    mapping(bytes32 => uint256) public chainUintsLength;
    mapping(bytes32 => uint256) public chainAddressLength;

    constructor(address[] memory _owners, uint _required, address payable _implementation) MessageMultiSigWallet(_owners, _required) public {
        implementation = _implementation;

        // valid chain default setting
        bytes32 chainId = sha256(abi.encodePacked(address(this), "BSC"));
        isValidChain[chainId] = true;
        chainUintsLength[chainId] = 3;
        chainAddressLength[chainId] = 20;

        chainId = sha256(abi.encodePacked(address(this), "HECO"));
        isValidChain[chainId] = true;
        chainUintsLength[chainId] = 3;
        chainAddressLength[chainId] = 20;

        chainId = sha256(abi.encodePacked(address(this), "KLAYTN"));
        isValidChain[chainId] = true;
        chainUintsLength[chainId] = 3;
        chainAddressLength[chainId] = 20;
    }

    function _setImplementation(address payable _newImp) public onlyWallet {
        require(implementation != _newImp);
        implementation = _newImp;
    }

    function () external {
        address impl = implementation;
        require(impl != address(0));
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize)
            let result := delegatecall(gas, impl, ptr, calldatasize, 0, 0)
            let size := returndatasize
            returndatacopy(ptr, 0, size)

            switch result
            case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }
}
