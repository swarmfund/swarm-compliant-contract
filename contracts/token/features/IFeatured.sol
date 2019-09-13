pragma solidity ^0.5.0;

import "./IFreezable.sol";
import "./IPausable.sol";

/**
 * @dev Support for "SRC20 feature" modifier.
 */
contract IFeatured is IPausable, IFreezable {

    function _enable(uint8 features) internal;

    function _isEnabled(uint8 feature) internal view returns (bool);
}
