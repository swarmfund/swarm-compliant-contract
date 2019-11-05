pragma solidity ^0.5.0;

import "../factories/SRC20Registry.sol";

/**
 * @title SRC20RegistryMock contract
 * @dev SRC20Registry mock contract used only for tests.
 */
contract SRC20RegistryMock is SRC20Registry {
    constructor(address swmERC20)
        SRC20Registry(swmERC20)
        public
    {
    }
}
