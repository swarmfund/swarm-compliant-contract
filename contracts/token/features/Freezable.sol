pragma solidity ^0.5.0;

import "./IFreezable.sol";

/**
 * @title Freezable account
 * @dev Base contract providing internal methods for freezing,
 * unfreezing and checking accounts' status.
 */
contract Freezable is IFreezable {
    mapping (address => bool) private _frozen;

    event AccountFrozen(address indexed account);
    event AccountUnfrozen(address indexed account);

    /**
     * @dev Freeze an account
     */
    function _freezeAccount(address account) internal {
        _frozen[account] = true;
        emit AccountFrozen(account);
    }

    /**
     * @dev Unfreeze an account
     */
    function _unfreezeAccount(address account) internal {
         _frozen[account] = false;
         emit AccountUnfrozen(account);
    }

    /**
     * @dev Check if an account is frozen. If token is frozen, all
     * of accounts are frozen also.
     * @return bool
     */
    function _isAccountFrozen(address account) internal view returns (bool) {
         return _frozen[account];
    }
}
