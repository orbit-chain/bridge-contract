pragma solidity ^0.5.0;

import "./MultiSigWallet.sol";

contract MessageMultiSigWallet is MultiSigWallet{

    event ConfirmationMessage(address indexed sender, uint indexed messageId);
    event RevocationMessage(address indexed sender, uint indexed messageId);
    event SubmissionMessage(uint indexed messageId);

    mapping (bytes32 => bool) public validatedHashs;
    mapping (uint => bytes32) public hashs;
    uint public hashCount = 0;
    mapping (bytes32 => uint) public validateCount;
    mapping (bytes32 => mapping(uint => uint8)) public vSigs;
    mapping (bytes32 => mapping(uint => bytes32)) public rSigs;
    mapping (bytes32 => mapping(uint => bytes32)) public sSigs;
    mapping (bytes32 => mapping(uint => address)) public hashValidators;
    
    constructor(address[] memory _owners, uint _required) MultiSigWallet(_owners, _required) public {
    }

    function isValidatedHash(bytes32 hash) public view returns (bool){
        return validatedHashs[hash];
    }

    function getHashValidators(bytes32 hash) public view returns (address[] memory){
        uint vaCount = validateCount[hash];
        address[] memory vaList = new address[](vaCount);

        uint i = 0;
        for(i; i<vaCount; i++){
            vaList[i] = hashValidators[hash][i];
        }

        return vaList;
    }

    function updateValidate(bytes32 hash) public returns (bool){
        require(!validatedHashs[hash], "Validated hash.");
        uint i;
        uint cnt=0;
        for(i=0; i<validateCount[hash]; i++){
            if(isOwner[hashValidators[hash][i]]){
                cnt ++;
            }
        }
        if(cnt >= required){
            validatedHashs[hash] = true; 
        }
        return validatedHashs[hash];
    }

    function validate(address validator, bytes32 hash, uint8 v, bytes32 r, bytes32 s) public returns (bool){
        require(isOwner[validator], "Unauthorized.");
        require(!validatedHashs[hash], "Validated hash.");
        require(ecrecover(hash,v,r,s) == validator, "Validation signature mismatch.");

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
        rSigs[hash][i] = r;
        sSigs[hash][i] = s;
        hashValidators[hash][i] = validator;

        if(i+1 >= required){
            validatedHashs[hash] = true;
            return true;
        }
        return false;
    }
}
