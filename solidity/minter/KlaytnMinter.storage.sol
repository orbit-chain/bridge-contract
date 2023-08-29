// SPDX-License-Identifier: MIT
pragma solidity 0.5.0;

contract KlaytnMinterStorage {
    string public constant chain = "";

    bool public isActivated = true;

    address payable public implementation;

    uint public depositCount = 0;

    mapping(bytes32 => bool) public isConfirmed;
    mapping(bytes32 => bool) public isValidChain;

    mapping(bytes32 => bytes) public tokens;
    mapping(bytes32 => address) public tokenAddr;
    mapping(address => bytes32) public tokenSummaries;

    bytes32 public govId;
    
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

    mapping(address => bool) public nonTaxable;
    
    mapping(bytes32 => address) public tokenMinter;

    mapping(address => address) public migrationList;
    
    address public setterAddress;

    struct SwapInfo {
        bool mintable;
        address oToken;
        address adapter;
    }

    mapping (address => SwapInfo) public swapMap;
}