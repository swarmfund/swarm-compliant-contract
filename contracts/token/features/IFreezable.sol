pragma solidity ^0.5.0;

contract IFreezable {
    event AccountFrozen(address indexed account);
    event AccountUnfrozen(address indexed account);

    function _freezeAccount(address account) internal;
    function _unfreezeAccount(address account) internal;
    function _isAccountFrozen(address account) internal view returns (bool);
}
