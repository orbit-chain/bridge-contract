pragma solidity 0.5.0;

import "../standard/IKIP17.sol";
import "../standard/IERC721Receiver.sol";
import "../standard/IKIP17Receiver.sol";
import "../standard/SafeMath.sol";
import "../standard/Address.sol";
import "../standard/Counters.sol";
import "../standard/KIP13.sol";

/**
 * @title KIP17 Non-Fungible Token Standard basic implementation
 * @dev see http://kips.klaytn.com/KIPs/kip-17-non_fungible_token
 */
contract KIP17 is KIP13, IKIP17 {
    using SafeMath for uint256;
    using Address for address;
    using Counters for Counters.Counter;

    bytes4 private constant _KIP17_RECEIVED = 0x6745782b;
    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;
    bytes4 private constant _INTERFACE_ID_KIP17 = 0x80ac58cd;
    bytes4 private constant _INTERFACE_ID_KIP17_METADATA = 0x5b5e139f;

    mapping (uint256 => address) private _tokenOwner;
    mapping (uint256 => address) private _tokenApprovals;
    mapping (address => Counters.Counter) private _ownedTokensCount;
    mapping (address => mapping (address => bool)) private _operatorApprovals;
    mapping(uint256 => string) private _tokenURIs;

    address public _owner;
    address public _minter;

    string private _name;
    string private _symbol;

    bool public tokenInitialized = false;
    mapping (uint256 => bool) public tokenURIInitialized;

    constructor (address owner, address minter, string memory name, string memory symbol) public {
        // register the supported interfaces to conform to KIP17 via KIP13
        _registerInterface(_INTERFACE_ID_KIP17);
        _registerInterface(_INTERFACE_ID_KIP17_METADATA);

        _owner = owner;
        _minter = minter;
        _name = name;
        _symbol = symbol;
    }

    modifier onlyOwner {
        require(msg.sender == _owner, "Unauthorized.");
        _;
    }

    modifier onlyMinter {
        require(msg.sender == _minter, "Unauthorized.");
        _;
    }

    function _version() public view returns(string memory name, string memory version) {
        return (_name, "20210319");
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        require(_exists(tokenId), "KIP17Metadata: URI query for nonexistent token");
        return _tokenURIs[tokenId];
    }

    function balanceOf(address owner) public view returns (uint256) {
        require(owner != address(0), "KIP17: balance query for the zero address");

        return _ownedTokensCount[owner].current();
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _tokenOwner[tokenId];
        require(owner != address(0), "KIP17: owner query for nonexistent token");

        return owner;
    }

    function getApproved(uint256 tokenId) public view returns (address) {
        require(_exists(tokenId), "KIP17: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function _setTokenInfo(string memory nftName, string memory nftSymbol) public {
        require(msg.sender == _owner || !tokenInitialized);

        tokenInitialized = true;

        _name = nftName;
        _symbol = nftSymbol;
    }

    function _setTokenURI(uint256 tokenId, string memory uri) public {
        require(_exists(tokenId), "KIP17Metadata: URI set of nonexistent token");
        require(msg.sender == _owner || !tokenURIInitialized[tokenId]);

        tokenURIInitialized[tokenId] = true;

        _tokenURIs[tokenId] = uri;
    }

    function _setOwner(address owner) public onlyOwner {
        require(owner != address(0));
        _owner = owner;
    }

    function _setMinter(address minter) public onlyOwner {
        require(minter != address(0));
        _minter = minter;
    }

    function _mint(address to, uint256 tokenId) public onlyMinter {
        require(to != address(0), "KIP17: mint to the zero address");
        require(!_exists(tokenId), "KIP17: token already minted");

        _tokenOwner[tokenId] = to;
        _ownedTokensCount[to].increment();

        emit Transfer(address(0), to, tokenId);
    }

    function _burn(address owner, uint256 tokenId) public onlyMinter {
        require(_exists(tokenId), "KIP17: nonexistent token");
        require(ownerOf(tokenId) == owner, "KIP17: burn of token that is not own");

        _clearApproval(tokenId);

        _ownedTokensCount[owner].decrement();
        _tokenOwner[tokenId] = address(0);

        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
            tokenURIInitialized[tokenId] = false;
        }

        emit Transfer(owner, address(0), tokenId);
    }

    function approve(address to, uint256 tokenId) public {
        address owner = ownerOf(tokenId);
        require(to != owner, "KIP17: approval to current owner");

        require(msg.sender == owner || isApprovedForAll(owner, msg.sender),
            "KIP17: approve caller is not owner nor approved for all"
        );

        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function setApprovalForAll(address to, bool approved) public {
        require(to != msg.sender, "KIP17: approve to caller");

        _operatorApprovals[msg.sender][to] = approved;
        emit ApprovalForAll(msg.sender, to, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "KIP17: transfer caller is not owner nor approved");

        _transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public {
        transferFrom(from, to, tokenId);
        require(_checkOnKIP17Received(from, to, tokenId, _data), "KIP17: transfer to non KIP17Receiver implementer");
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        address owner = _tokenOwner[tokenId];
        return owner != address(0);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        require(_exists(tokenId), "KIP17: operator query for nonexistent token");
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    function _transferFrom(address from, address to, uint256 tokenId) internal {
        require(ownerOf(tokenId) == from, "KIP17: transfer of token that is not own");
        require(to != address(0), "KIP17: transfer to the zero address");

        _clearApproval(tokenId);

        _ownedTokensCount[from].decrement();
        _ownedTokensCount[to].increment();

        _tokenOwner[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function _checkOnKIP17Received(address from, address to, uint256 tokenId, bytes memory _data)
        internal returns (bool)
    {
        if (!to.isContract()) {
            return true;
        }

        // Logic for compatibility with ERC721.
        bytes4 retval = IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, _data);
        if (retval == _ERC721_RECEIVED) {
            return true;
        }

        retval = IKIP17Receiver(to).onKIP17Received(msg.sender, from, tokenId, _data);
        return (retval == _KIP17_RECEIVED);
    }

    function _clearApproval(uint256 tokenId) private {
        if (_tokenApprovals[tokenId] != address(0)) {
            _tokenApprovals[tokenId] = address(0);
        }
    }
}
