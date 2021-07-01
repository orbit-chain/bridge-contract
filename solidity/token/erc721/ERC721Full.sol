pragma solidity ^0.5.0;

import "./ERC721.sol";
import "./ERC721Enumerable.sol";
import "./ERC721Metadata.sol";

/**
 * @title Full ERC721 Token
 * @dev This implementation includes all the required and some optional functionality of the ERC721 standard
 * Moreover, it includes approve all functionality using operator terminology.
 *
 * See https://eips.ethereum.org/EIPS/eip-721
 */
contract ERC721Full is ERC721, ERC721Enumerable, ERC721Metadata {
    address private _owner;
    address private _nextOwner;
    address private _minter;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor (address owner_, address minter_, string memory name, string memory symbol) public ERC721Metadata(name, symbol) {
        // solhint-disable-previous-line no-empty-blocks
        _owner = owner_;
        _minter = minter_;
    }

    modifier onlyOwner {
        require(msg.sender == owner());
        _;
    }

    modifier onlyMinter {
        require(msg.sender == minter());
        _;
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

    function mint(address to, uint256 tokenId) external onlyMinter returns (bool) {
        _mint(to, tokenId);

        return true;
    }

    function burn(address from, uint256 tokenId) external onlyMinter returns (bool) {
        _burn(from, tokenId);

        return true;
    }
}
