// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

contract VaultStorage {
    string public chain;
    bool public isActivated = true;

    uint public depositCount = 0;

    mapping(bytes32 => bool) public isUsedWithdrawal;
    mapping(bytes32 => bool) public isValidChain;

    uint public bridgingFee = 0;
    address payable public feeGovernance;

    mapping(address => address payable) public farms;
    uint public taxRate = 10; // 0.01% interval
    address public taxReceiver = 0xE9f3604B85c9672728eEecf689cf1F0cF7Dd03F2;

    uint public gasLimitForBridgeReceiver;
}
