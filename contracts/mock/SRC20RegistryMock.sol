pragma solidity ^0.5.0;

import "../factories/SRC20Registry.sol";


contract SRC20RegistryMock is SRC20Registry {
    constructor(address swmERC20)
        SRC20Registry(swmERC20)
        public
    {
    }

    function getStake(address src20) external view returns (uint256) {
        return _registry[src20].stake;
    }
}
