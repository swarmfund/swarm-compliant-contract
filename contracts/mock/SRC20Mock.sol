pragma solidity ^0.5.0;

import "../token/SRC20.sol";
import "../token/features/IFeatured.sol";


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
        bytes32 kyaHash,
        string memory kyaUrl,
        address restrictions,
        uint8 features,
        uint256 totalSupply
    )
        SRC20(owner, name, symbol, decimals, kyaHash, kyaUrl, restrictions, features, totalSupply)
        public
    {
    }
}
