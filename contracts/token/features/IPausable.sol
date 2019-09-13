pragma solidity ^0.5.0;

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
contract IPausable{
    event Paused(address account);
    event Unpaused(address account);

    function paused() public view returns (bool);

    function _pause() internal;
    function _unpause() internal;
}
