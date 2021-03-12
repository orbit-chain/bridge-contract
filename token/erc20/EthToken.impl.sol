pragma solidity ^0.5.0;

import "./EthToken.sol";

contract EthTokenImpl is EthToken {
    event SetOwner(address owner);
    event SetMinter(address minter);
    event SetTokenInfo(string name, string symbol);
    event Transfer(address indexed from, address indexed to, uint amount);
    event Approval(address indexed holder, address indexed spender, uint amount);

    modifier onlyOwnerOrBeforeInit {
        require(msg.sender == owner || isInitialized == false);
        _;
    }

    constructor() public EthToken(address(0), address(0), address(0), 0) {}

    function _version() public pure returns(string memory name, string memory version) {
        return (name, "1103");
    }

    function setOwner(address _owner) public onlyOwner {
        require(_owner != address(0));
        owner = _owner;
        emit SetOwner(_owner);
    }

    function setMinter(address _minter) public onlyOwner {
        require(_minter != address(0));
        minter = _minter;
        emit SetMinter(_minter);
    }

    function setTokenInfo(string memory _name, string memory _symbol) public onlyOwnerOrBeforeInit {
        name = _name;
        symbol = _symbol;

        if(isInitialized == false) isInitialized = true;

        emit SetTokenInfo(_name, _symbol);
    }

    // --- Math ---
    function add(uint a, uint b) private pure returns (uint) {
        require(a <= uint(-1) - b);
        return a + b;
    }

    function sub(uint a, uint b) private pure returns (uint) {
        require(a >= b);
        return a - b;
    }

    function transferFrom(address from, address to, uint amount) public returns (bool) {
        if (to == minter && msg.sender == minter) {
            burn(from, amount);
            return true;
        }

        if (from != msg.sender && allowance[from][msg.sender] != uint(-1)) {
            allowance[from][msg.sender] = sub(allowance[from][msg.sender], amount);
        }

        balanceOf[from] = sub(balanceOf[from], amount);
        balanceOf[to] = add(balanceOf[to], amount);

        emit Transfer(from, to, amount);

        return true;
    }

    function increaseApproval(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, add(allowance[msg.sender][spender], value));
        return true;
    }

    function decreaseApproval(address spender, uint256 value) public returns (bool) {
        if(value > allowance[msg.sender][spender]){
            value = 0;
        }
        else{
            value = sub(allowance[msg.sender][spender], value);
        }

        _approve(msg.sender, spender, value);
        return true;
    }

    function approve(address spender, uint amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function _approve(address owner, address spender, uint256 value) private {
        require(owner != address(0));
        require(spender != address(0));

        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function mint(address user, uint amount) private {
        balanceOf[user] = add(balanceOf[user], amount);
        totalSupply = add(totalSupply, amount);

        emit Transfer(address(0), user, amount);
    }

    function burn(address user, uint amount) private {
        balanceOf[user] = sub(balanceOf[user], amount);
        totalSupply = sub(totalSupply, amount);

        emit Transfer(user, address(0), amount);
    }

    function transfer(address to, uint amount) public returns (bool) {
        if (msg.sender == minter) {
            mint(to, amount);
            return true;
        }

        return transferFrom(msg.sender, to, amount);
    }
}


