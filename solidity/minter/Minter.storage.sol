// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

contract MinterStorage {
    string public chain;
    bool public isActivated = true;

    uint public depositCount = 0;

    mapping(bytes32 => bool) public isConfirmed;
    mapping(bytes32 => bool) public isValidChain;

    mapping(bytes32 => bytes) public tokens;
    mapping(bytes32 => address) public tokenAddr;
    mapping(address => bytes32) public tokenSummaries;

    bytes32 public govId;

    uint public bridgingFee;
    uint public bridgingFeeWithData;
    uint public gasLimitForBridgeReceiver;
    address payable public feeGovernance;

    uint public taxRate = 10; // 0.01% interval
    address public taxReceiver = 0xE9f3604B85c9672728eEecf689cf1F0cF7Dd03F2;

    address public tokenDeployer;

    mapping (address => uint) public minRequestAmount;

    address public policyAdmin;
    mapping(bytes32 => uint256) public chainFee;
    mapping(bytes32 => uint256) public chainFeeWithData;
}
