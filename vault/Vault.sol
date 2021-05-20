// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.4/contracts/proxy/TransparentUpgradeableProxy.sol";

contract Vault is TransparentUpgradeableProxy {
    constructor(address _logic, address admin_, bytes memory _data) public TransparentUpgradeableProxy(_logic, admin_, _data){ }

    function getAdmin() public view returns (address) {
        return _admin();
    }
    
    function getImplementation() public view returns (address) {
        return _implementation();
    }
}
