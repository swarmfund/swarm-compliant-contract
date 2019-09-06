pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/access/Roles.sol";


/**
 * @title DelegateRole
 * @dev Delegate is accounts allowed to do certain operations on
 * contract, apart from owner.
 */
contract DelegateRole {
    using Roles for Roles.Role;
    
    event DelegateAdded(address indexed account);
    event DelegateRemoved(address indexed account);

    Roles.Role private _delegates;

    /**
     * @dev Throws if called by any account other than the delegate.
     */
    modifier onlyDelegate() {
        require(_hasDelegate(msg.sender));
        _;
    }

    function _addDelegate(address account) internal {
        _delegates.add(account);
        emit DelegateAdded(account);
    }

    function _removeDelegate(address account) internal {
        _delegates.remove(account);
        emit DelegateRemoved(account);
    }

    function _hasDelegate(address account) internal view returns (bool) {
        return _delegates.has(account);
    }
}
