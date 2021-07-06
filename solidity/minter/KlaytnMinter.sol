pragma solidity ^0.5.0;

import "../utils/Owned.sol";

contract KlaytnMinter is Owned {
    string public constant chain = "KLAYTN";

    bool public isActivated = true;

    address payable public implementation;

    uint public depositCount = 0;

    mapping(bytes32 => bool) public isConfirmed;
    mapping(bytes32 => bool) public isValidChain;

    mapping(bytes32 => bytes) public tokens;
    mapping(bytes32 => address) public tokenAddr;
    mapping(address => bytes32) public tokenSummaries;

    bytes32 public govId;

    constructor(address multisigAddr, address payable _implementation, bytes32 _govId) public {
        governance = multisigAddr;
        implementation = _implementation;
        govId = _govId;
    }

    function _setImplementation(address payable _newImp) public onlyGovernance {
        require(implementation != _newImp);
        implementation = _newImp;
    }

    function () payable external {
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
