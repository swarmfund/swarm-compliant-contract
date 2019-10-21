pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./DelegateRole.sol";
import "./AuthorityRole.sol";
import "./Managed.sol";
import "../interfaces/ISRC20Roles.sol";

/*
 * @title SRC20Roles contract
 * @dev Roles wrapper contract around all roles needed for SRC20 contract.
 */
contract SRC20Roles is ISRC20Roles, DelegateRole, AuthorityRole, Managed, Ownable {
    constructor(address owner, address manager, address rules) public
        Managed(manager)
    {
        _transferOwnership(owner);
        if (rules != address(0)) {
            _addAuthority(rules);
        }
    }

    function addAuthority(address account) external onlyOwner returns (bool) {
        _addAuthority(account);
        return true;
    }

    function removeAuthority(address account) external onlyOwner returns (bool) {
        _removeAuthority(account);
        return true;
    }

    function isAuthority(address account) external view returns (bool) {
        return _hasAuthority(account);
    }

    function addDelegate(address account) external onlyOwner returns (bool) {
        _addDelegate(account);
        return true;
    }

    function removeDelegate(address account) external onlyOwner returns (bool) {
        _removeDelegate(account);
        return true;
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

    function isManager(address account) external view returns (bool) {
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