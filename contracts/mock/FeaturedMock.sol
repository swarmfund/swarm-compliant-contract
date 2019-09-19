pragma solidity ^0.5.0;

import "../token/features/Featured.sol";

/**
 * @title SRC20Mock contract
 * @dev SRC20 mock contract for tests.
 */
contract FeaturedMock is Featured {
    constructor (address owner, uint8 features) public
    Featured(owner, features)
    {
    }

    /**
     * @dev Setting up features for test cases.
     */
    function featureEnable(uint8 features) external {
        _enable(features);
    }
}