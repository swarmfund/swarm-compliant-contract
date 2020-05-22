pragma solidity ^0.5.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.0/contracts/access/Roles.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.0/contracts/ownership/Ownable.sol";


/**
 * @title AuthorityRole
 * @dev Authority is roles responsible for signing/approving token transfers
 * on-chain & off-chain
 */
contract AuthorityRole {
    using Roles for Roles.Role;

    event AuthorityAdded(address indexed account);
    event AuthorityRemoved(address indexed account);

    Roles.Role private _authorities;

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
