pragma solidity 0.5.0;

import '../kip7/KIP7.sol';
import '../kip17/KIP17Full.sol';

contract KIPDeployer {
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

contract DeployerImpl is KIPDeployer {
    constructor() public KIPDeployer(address(0), address(0), address(0), ""){}

    modifier onlyMinter {
        require(msg.sender == minter);
        _;
    }

    function getVersion() public pure returns(string memory) {
        return "KIPMinter20210628";
    }

    function setOwner(address _owner) public onlyOwner {
        require(_owner != address(0));
        owner = _owner;
    }

    function setMinter(address _minter) public onlyOwner {
        require(_minter != address(0));
        minter = _minter;
    }

    function deployToken(uint8 decimals) public onlyMinter returns (address){
        string memory name = string(abi.encodePacked("Orbit Bridge ", chain, " Token"));
        return address(new KIP7(owner, minter, name, "OBT", decimals, false));
    }

    function deployTokenWithInit(string memory name, string memory symbol, uint8 decimals) public onlyMinter returns (address){
        return address(new KIP7(owner, minter, name, symbol, decimals, true));
    }

    function deployNFT() public onlyMinter returns (address){
        string memory name = string(abi.encodePacked("Orbit Bridge ", chain, " NFT"));
        return address(new KIP17Full(owner, minter, name, "OBN", false));
    }

    function deployNFTWithInit(string memory name, string memory symbol) public onlyMinter returns (address){
        return address(new KIP17Full(owner, minter, name, symbol, true));
    }
}

contract OrbitDeployerImpl is KIPDeployer {
    constructor() public KIPDeployer(address(0), address(0), address(0), ""){}

    modifier onlyMinter {
        require(msg.sender == minter);
        _;
    }

    function getVersion() public pure returns(string memory) {
        return "KIPOrbitMinter20210628";
    }

    function setOwner(address _owner) public onlyOwner {
        require(_owner != address(0));
        owner = _owner;
    }

    function setMinter(address _minter) public onlyOwner {
        require(_minter != address(0));
        minter = _minter;
    }

    function deployToken(uint8 decimals) public onlyMinter returns (address){
        string memory name = "Orbit Bridge Token";
        return address(new KIP7(owner, minter, name, "OBT", decimals, false));
    }

    function deployTokenWithInit(string memory name, string memory symbol, uint8 decimals) public onlyMinter returns (address){
        return address(new KIP7(owner, minter, name, symbol, decimals, true));
    }

    function deployNFT() public onlyMinter returns (address){
        string memory name = "Orbit Bridge NFT";
        return address(new KIP17Full(owner, minter, name, "OBN", false));
    }

    function deployNFTWithInit(string memory name, string memory symbol) public onlyMinter returns (address){
        return address(new KIP17Full(owner, minter, name, symbol, true));
    }
}
