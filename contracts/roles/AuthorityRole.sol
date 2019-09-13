pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/access/Roles.sol";


/**
 * @title AuthorityRole
 * @dev Authorities that can sign transfer signatures.
 */
contract AuthorityRole {
    using Roles for Roles.Role;

    event AuthorityAdded(address indexed account);
    event AuthorityRemoved(address indexed account);

    Roles.Role private _authorities;

    /**
    * @dev Throws if called by any account other than the delegate.
    */
    modifier onlyAuthority() {
        require(_hasAuthority(msg.sender));
        _;
    }

    function _addAuthority(address account) internal {
        _authorities.add(account);
        emit AuthorityAdded(account);
    }

    function _removeAuthority(address account) internal {
        _authorities.remove(account);
        emit AuthorityRemoved(account);
    }

    function _hasAuthority(address account) internal view returns (bool) {
        return _authorities.has(account);
    }
}
