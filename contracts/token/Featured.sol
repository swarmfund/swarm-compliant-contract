pragma solidity ^0.5.0;

/**
 * @dev Support for "SRC20 feature" modifier.
 */
contract Featured {
    uint8 public constant ForceTransfer     = 0x01;
    uint8 public constant Pausable          = 0x02;
    uint8 public constant AccountBurning    = 0x04;
    uint8 public constant AccountFreezing   = 0x08;

    uint8 private _enabledFeatures;


    constructor (uint8 features) internal {
        _enable(features);
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
    function _isEnabled(uint8 feature) internal view returns (bool) {
        return _enabledFeatures & feature > 0;
    }

    /**
     * @dev Allow only enabled features.
     * @param feature Feature to check if enabled.
     */
    modifier enabled(uint8 feature) {
        require(_isEnabled(feature), "Feature not enabled");
        _;
    }
}
