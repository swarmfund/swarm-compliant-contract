pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./DelegateRole.sol";
import "./AuthorityRole.sol";
import "./Managed.sol";
import "./IRoles.sol";

contract SRC20Roles is IRoles, DelegateRole, AuthorityRole, Managed, Ownable {
    constructor() public {
    }

    function addAuthority(address account) external onlyOwner {
        _addAuthority(account);
    }

    function removeAuthority(address account) external onlyOwner {
        _removeAuthority(account);
    }

    function isAuthority(address account) external view returns (bool) {
        return _hasAuthority(account);
    }

    function addDelegate(address account) external {
        _addDelegate(account);
    }

    function removeDelegate(address account) external {
        _removeDelegate(account);
    }

    function isDelegate(address account) external view returns (bool) {
        return _hasDelegate(account);
    }

    /**
    * @return the address of the manager.
    */
    function manager() external view returns (address) {
        return _manager;
    }

    function isManager(address account) public view returns (bool) {
        return _isManager(account);
    }

    function renounceManagement() external onlyManager returns (bool) {
        _renounceManagement();
        return true;
    }

    function transferManagement(address newManager) external onlyManager returns (bool) {
        _transferManagement(newManager);
        return true;
    }
}