pragma solidity ^0.5.0;

contract EthToken {
    // --- ERC20 ---
    string public name = "Orbit Bridge Ethereum Token";
    string public symbol = "OBET";
    uint8 public decimals;
    uint public totalSupply = 0;

    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;  // (holder, spender)

    // --- Owner ---
    address public owner;

    // --- Contracts & Constructor ---
    address public minter;
    address payable public implementation;

    bool public isInitialized = false;

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    constructor(address _owner, address payable _implementation, address _minter, uint8 _decimals) public {
        owner = _owner;
        implementation = _implementation;
        minter = _minter;
        decimals = _decimals;
    }

    function _setImplementation(address payable _newImp) public onlyOwner {
        require(implementation != _newImp);
        require(_newImp != address(0));
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
