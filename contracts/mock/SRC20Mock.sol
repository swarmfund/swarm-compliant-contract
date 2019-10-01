pragma solidity ^0.5.0;

import "../token/SRC20.sol";

/**
 * @title SRC20Mock contract
 * @dev SRC20 mock contract for tests.
 */
contract SRC20Mock is SRC20 {
    constructor(
        address owner,
        string memory name,
        string memory symbol,
        uint8 decimals,
        address restrictions,
        address rules,
        address roles,
        address featured,
        uint256 totalSupply,
        uint256 maxTotalSupply,
        address asset
    )
        SRC20(name, symbol, decimals, maxTotalSupply, owner, restrictions, rules, roles, featured, asset)
        public
    {
        _totalSupply = totalSupply;
        _balances[owner] = _totalSupply;
    }
}
