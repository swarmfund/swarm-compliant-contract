pragma solidity ^0.5.0;

/**
 * @title Freezable contract
 * @dev Base contract providing internal methods for account
 * and to track what accounts are frozen, and if whole token is frozen.
 * Token freezing is shortcut for freezing every account.
 */
contract Freezable {
    bool private _tokenFrozen;
    mapping (address => bool) private _frozen;

    event AccountFrozen(address indexed account);
    event AccountUnfrozen(address indexed account);
    event TokenFrozen();
    event TokenUnfrozen();

    function _freezeAccount(address account) internal {
        _frozen[account] = true;
        emit AccountFrozen(account);
    }

    function _unfreezeAccount(address account) internal {
         _frozen[account] = false;
         emit AccountUnfrozen(account);
    }

    function _freezeToken() internal {
        _tokenFrozen = true;
        emit TokenFrozen();
    }

    function _unfreezeToken() internal {
        _tokenFrozen = false;
        emit TokenUnfrozen();
    }

    /**
     * @dev Check if an account is frozen. If token is frozen, all
     * of accounts are frozen also.
     * @return bool
     */
    function _isFrozen(address account) internal view returns (bool) {
         return _tokenFrozen == true || _frozen[account] == true;
    }

    /**
     * @dev Check if token frozen.
     * @return bool
     */
    function _isTokenFrozen() internal view returns (bool) {
         return _tokenFrozen == true;
    }
}
