pragma solidity ^0.5.0;

import "./MessageMultiSigWallet.sol";

contract XrpMessageMultiSigWallet is MessageMultiSigWallet{

    event ConfirmationMessage(address indexed sender, uint indexed messageId);
    event RevocationMessage(address indexed sender, uint indexed messageId);
    event SubmissionMessage(uint indexed messageId);

    mapping(address => bytes25) public xrpAddresses;
    
    constructor(address[] memory _owners, bytes25[] memory _xrpAddresses, uint _required) MessageMultiSigWallet(_owners, _required) public {
        require(_owners.length == _xrpAddresses.length, "Invalid xrpAddresses.");

        for(uint i=0; i<_owners.length; i++) {
            xrpAddresses[owners[i]] = _xrpAddresses[i];
        }
    }

    function addOwner(address owner, bytes25 xrpAddress) public onlyWallet{
        addOwner(owner);
        xrpAddresses[owner] = xrpAddress;
    }

    function removeOwnerWithXrpAddress(address owner) public onlyWallet {
        removeOwner(owner);
        delete xrpAddresses[owner];
    }
}