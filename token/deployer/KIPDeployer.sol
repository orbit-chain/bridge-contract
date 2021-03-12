pragma solidity 0.5.0;

import '../kip7/KIP7.sol';
import '../kip17/KIP17.sol';

contract Deployer {
    address public owner;
    address public minter;
    address public implementation;
    string public chain;

    constructor(address _owner, address _minter, address _implementation, string memory _chain) public {
        owner = _owner;
        minter = _minter;
        implementation = _implementation;
        chain = _chain;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function _setImplementation(address payable _newImp) public onlyOwner {
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

contract DeployerImpl is Deployer {
    constructor() public Deployer(address(0), address(0), address(0), ""){}

    modifier onlyMinter {
        require(msg.sender == minter);
        _;
    }

    function setMinter(address _minter) public onlyOwner {
        require(_minter != address(0));
        minter = _minter;
    }

    function deployToken(uint8 decimals) public onlyMinter returns (address){
        string memory name = string(abi.encodePacked("Orbit Bridge ", chain, " Token"));
        return address(new KIP7(owner, minter, name, "OBT", decimals));
    }

    function deployNFT() public onlyMinter returns (address){
        string memory name = string(abi.encodePacked("Orbit Bridge ", chain, " NFT"));
        return address(new KIP17(owner, minter, name, "OBN"));
    }
}
