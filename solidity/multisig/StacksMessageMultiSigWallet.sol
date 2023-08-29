pragma solidity 0.5.0;
pragma experimental ABIEncoderV2;

import "./MessageMultiSigWallet.sol";

contract StacksMessageMultiSigWallet is MessageMultiSigWallet{

    mapping(address => bytes) public publicKeys;
    
    constructor(address[] memory _owners, bytes[] memory _publicKeys, uint _required) MessageMultiSigWallet(_owners, _required) public {
        require(_owners.length == _publicKeys.length, "Invalid publicKeys.");

        for(uint i=0; i<_owners.length; i++) {
            publicKeys[owners[i]] = _publicKeys[i];
        }
    }

    function addOwnerWithPublicKey(address owner, bytes memory publicKey) public onlyWallet {
        addOwner(owner);
        publicKeys[owner] = publicKey;
    }

    function removeOwnerWithPublicKey(address owner) public onlyWallet {
        removeOwner(owner);
        delete publicKeys[owner];
    }

    function getOwnersWithPublicKey() public view returns (address[] memory, bytes[] memory) {
        uint len = owners.length;
        bytes[] memory pubKeys = new bytes[](len);
        for(uint i = 0; i < len; i++){
            pubKeys[i] = publicKeys[owners[i]];
        }

        return (owners, pubKeys);
    }
}
