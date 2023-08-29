pragma solidity 0.5.0;

import "./MessageMultiSigWallet.sol";
import "../crypto/Ed25519.sol";

contract Ed25519MessageMultiSigWallet is MessageMultiSigWallet{

    mapping(address => bytes32) public publicKeys;
    mapping(bytes32 => mapping(uint => bytes32)) public edRSigs;
    mapping(bytes32 => mapping(uint => bytes32)) public edSSigs;
    
    constructor(address[] memory _owners, bytes32[] memory _publicKeys, uint _required) MessageMultiSigWallet(_owners, _required) public {
        require(_owners.length == _publicKeys.length, "Invalid publicKeys.");

        for(uint i=0; i<_owners.length; i++) {
            publicKeys[owners[i]] = _publicKeys[i];
        }
    }

    function addOwnerWithPublicKey(address owner, bytes32 publicKey) public onlyWallet {
        addOwner(owner);
        publicKeys[owner] = publicKey;
    }

    function removeOwnerWithPublicKey(address owner) public onlyWallet {
        removeOwner(owner);
        delete publicKeys[owner];
    }

    function getOwnersWithPublicKey() public view returns (address[] memory, bytes32[] memory) {
        uint len = owners.length;
        bytes32[] memory pubKeys = new bytes32[](len);
        for(uint i = 0; i < len; i++){
            pubKeys[i] = publicKeys[owners[i]];
        }

        return (owners, pubKeys);
    }

    // @param r [0]: secp256k1, [1]: ed25519
    // @param s [0]: secp256k1, [2]: ed25519
    function validateWithEd25519(address validator, bytes32 hash, uint8 v, bytes32[] memory r, bytes32[] memory s) public returns (bool){
        require(r.length == 2);
        require(s.length == 2);
        require(isOwner[validator], "Unauthorized.");
        require(!validatedHashs[hash], "Validated hash.");
        require(ecrecover(hash,v,r[0],s[0]) == validator, "Validation signature mismatch.");
        require(Ed25519.verify(publicKeys[validator], r[1], s[1], abi.encodePacked(hash)));

        uint i=0;
        for(i; i<validateCount[hash]; i++){
            if(hashValidators[hash][i] == validator){
                revert("Transaction already verified by this validator.");
            }
        }

        if(validateCount[hash] == 0){
            hashs[hashCount] = hash;
            hashCount += 1;
        }

        i=validateCount[hash];
        validateCount[hash] = i + 1;
        vSigs[hash][i] = v;
        rSigs[hash][i] = r[0];
        edRSigs[hash][i] = r[1];
        sSigs[hash][i] = s[0];
        edSSigs[hash][i] = s[1];
        hashValidators[hash][i] = validator;

        if(i+1 >= required){
            validatedHashs[hash] = true;
            return true;
        }
        return false;
    }
}
