pragma solidity ^0.5.0;

contract Owned {
    address public governance;

    constructor() public {
        governance = msg.sender;
    }

    modifier onlyGovernance {
        require(msg.sender == governance, "Unauthorized.");
        _;
    }

    function transferOwnership(address _governance) onlyGovernance public {
        governance = _governance;
    }
}
