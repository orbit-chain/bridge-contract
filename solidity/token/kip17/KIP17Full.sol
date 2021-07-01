pragma solidity ^0.5.0;

import "./KIP17.sol";
import "./KIP17Enumerable.sol";
import "./KIP17Metadata.sol";

/**
 * @title Full KIP-17 Token
 * This implementation includes all the required and some optional functionality of the KIP-17 standard
 * Moreover, it includes approve all functionality using operator terminology
 * @dev see http://kips.klaytn.com/KIPs/kip-17-non_fungible_token
 */
contract KIP17Full is KIP17, KIP17Enumerable, KIP17Metadata {
    address public _owner;
    address public _minter;

    bool public tokenInitialized;
    mapping (uint256 => bool) public tokenURIInitialized;

    constructor (address owner_, address minter_, string memory name, string memory symbol, bool init) public KIP17Metadata(name, symbol) {
        // solhint-disable-previous-line no-empty-blocks
        _owner = owner_;
        _minter = minter_;

        tokenInitialized = init;
    }

    modifier onlyOwner {
        require(msg.sender == _owner, "Unauthorized.");
        _;
    }

    modifier onlyMinter {
        require(msg.sender == _minter, "Unauthorized.");
        _;
    }

    function version() public pure returns(string memory) {
        return "20210628";
    }

    function setOwner(address owner) public onlyOwner {
        require(owner != address(0));
        _owner = owner;
    }

    function setMinter(address minter) public onlyOwner {
        require(minter != address(0));
        _minter = minter;
    }

    function setTokenInfo(string memory nftName, string memory nftSymbol) public {
        require(msg.sender == _owner || !tokenInitialized);
        tokenInitialized = true;

        _setTokenInfo(nftName, nftSymbol);
    }

    function setTokenURI(uint256 tokenId, string memory uri) public {
        require(msg.sender == _owner || !tokenURIInitialized[tokenId]);
        tokenURIInitialized[tokenId] = true;

        _setTokenURI(tokenId, uri);
    }

    function _mint(address owner, uint256 tokenId) public onlyMinter {
        mint(owner, tokenId);
    }

    function _burn(address owner, uint256 tokenId) public onlyMinter {
        burn(owner, tokenId);
        tokenURIInitialized[tokenId] = false;
    }
}
