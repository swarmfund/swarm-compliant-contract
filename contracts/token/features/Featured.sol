pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../../interfaces/IFeatured.sol";
import "./Pausable.sol";
import "./Freezable.sol";

/**
 * @dev Support for "SRC20 feature" modifier.
 */
contract Featured is IFeatured, Pausable, Freezable, Ownable {
    uint8 public _enabledFeatures;

    modifier enabled(uint8 feature) {
        require(isEnabled(feature), "Token feature is not enabled");
        _;
    }

    constructor (address owner, uint8 features) public {
        _enable(features);
        _transferOwnership(owner);
    }

    /**
     * @dev Enable features. Call from SRC20 token constructor.
     * @param features ORed features to enable.
     */
    function _enable(uint8 features) internal {
        _enabledFeatures = features;
    }

    /**
     * @dev Returns if feature is enabled.
     * @param feature Feature constant to check if enabled.
     * @return True if feature is enabled.
     */
    function isEnabled(uint8 feature) public view returns (bool) {
        return _enabledFeatures & feature > 0;
    }

    /**
     * @dev Call to check if transfer will pass from feature contract stand point.
     *
     * @param from The address to transfer from.
     * @param to The address to send tokens to.
     *
     * @return True if the transfer is allowed
     */
    function checkTransfer(address from, address to) external view returns (bool) {
        return !_isAccountFrozen(from) && !_isAccountFrozen(to) && !paused();
    }

    /**
    * @dev Check if specified account is frozen. Token issuer can
    * freeze any account at any time and stop accounts making
    * transfers.
    *
    * @return True if account is frozen.
    */
    function isAccountFrozen(address account) external view returns (bool) {
        return _isAccountFrozen(account);
    }

    /**
     * @dev Freezes account.
     * Emits AccountFrozen event.
     */
    function freezeAccount(address account)
    external
    enabled(AccountFreezing)
    onlyOwner
    {
        _freezeAccount(account);
    }

    /**
     * @dev Unfreezes account.
     * Emits AccountUnfrozen event.
     */
    function unfreezeAccount(address account)
    external
    enabled(AccountFreezing)
    onlyOwner
    {
        _unfreezeAccount(account);
    }

    /**
     * @dev Check if token is frozen. Token issuer can freeze token
     * at any time and stop all accounts from making transfers. When
     * token is frozen, isFrozen(account) returns true for every
     * account.
     *
     * @return True if token is frozen.
     */
    function isTokenPaused() external view returns (bool) {
        return paused();
    }

    /**
     * @dev Pauses token.
     * Emits TokenPaused event.
     */
    function pauseToken()
    external
    enabled(Pausable)
    onlyOwner
    {
        _pause();
    }

    /**
     * @dev Unpause token.
     * Emits TokenUnPaused event.
     */
    function unPauseToken()
    external
    enabled(Pausable)
    onlyOwner
    {
        _unpause();
    }
}
