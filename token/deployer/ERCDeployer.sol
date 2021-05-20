pragma solidity 0.5.0;

import '../erc20/ERC20.sol';
import '../erc721/ERC721Full.sol';
import '../standard/Context.sol';

contract Deployer is Context {
    address private _owner;
    address private _nextOwner;
    address private _minter;
    string private _chain;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_, address minter_, string memory chain_) public {
        _owner = owner_;
        _minter = minter_;
        _chain = chain_;
    }

    modifier onlyOwner {
        require(_msgSender() == owner());
        _;
    }

    modifier onlyMinter {
        require(_msgSender() == minter());
        _;
    }

    function getVersion() public pure returns(string memory) {
        return "ERCTokenDeployer20210430";
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function nextOwner() public view returns (address) {
        return _nextOwner;
    }

    function minter() public view returns (address) {
        return _minter;
    }
    
    function chain() public view returns (string memory) {
        return _chain;
    }

    function setNextOwner(address nextOwner_) public onlyOwner {
        require(nextOwner_ != address(0));

        _nextOwner = nextOwner_;
    }

    function changeOwner() public {
        require(_msgSender() == nextOwner());

        emit OwnershipTransferred(owner(), nextOwner());

        _owner = nextOwner();
        _nextOwner = address(0);
    }

    function setMinter(address minter_) public onlyOwner {
        require(minter_ != address(0));

        _minter = minter_;
    }

    function deployToken(uint8 decimals) public onlyMinter returns (address){
        string memory name = string(abi.encodePacked("Orbit Bridge ", chain(), " Token"));
        return address(new ERC20(owner(), minter(), name, "OBT", decimals));
    }

    function deployNFT() public onlyMinter returns (address){
        string memory name = string(abi.encodePacked("Orbit Bridge ", chain(), " NFT"));
        return address(new ERC721Full(owner(), minter(), name, "OBN"));
    }
}
