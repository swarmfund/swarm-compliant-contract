pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/access/Roles.sol";


/**
 * @title RestrictionRole
 * @dev Restrictor is contract that can execute internal transfer function.
 */
contract RestrictionRole {
    using Roles for Roles.Role;

    event RestrictorAdded(address indexed account);
    event RestrictorRemoved(address indexed account);

    Roles.Role private _restrictor;

    constructor(address account) public {
        _restrictor.add(account);
    }

    /**
     * @dev Throws if called by any account other than the delegate.
     */
    modifier onlyTransferRestrictor() {
        require(_hasRestrictions(msg.sender));
        _;
    }

    function _hasRestrictions(address account) internal view returns (bool) {
        return _restrictor.has(account);
    }
}
