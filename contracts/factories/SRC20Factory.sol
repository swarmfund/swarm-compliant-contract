pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../token/SRC20.sol";
import "../interfaces/ISRC20Registry.sol";

/**
 * @dev Factory that creates SRC20 token for requested token
 * properties and features.
 */
contract SRC20Factory is Ownable {
    ISRC20Registry private _registry;

    event SRC20Created(address token);

    /**
     * @dev Factory constructor expects SRC20 tokens registry.
     * Every created token will be registered in registry.
     * @param registry address of SRC20Registry contract.
     */
    constructor(address registry) public {
        _registry = ISRC20Registry(registry);
    }

    /**
     * @dev Creates new SRC20 contract. Expects token properties and
     * desired capabilities of the token. Only factory owner can call
     * this function.
     * Emits SRC20Created event with address of new token.
     */
    function create(
        // contract parameters
        address tokenOwner,
        string memory name,
        string memory symbol,
        uint8 decimals,
        bytes32 kyaHash,
        string memory kyaUrl,
        address restrictions,
        address rules,
        address roles,
        address featured,
        uint256 maxTotalSupply
    )
        public onlyOwner returns (bool) 
    {
        address token = address(new SRC20(
            tokenOwner,
            name,
            symbol,
            decimals,
            kyaHash,
            kyaUrl,
            restrictions,
            rules,
            roles,
            featured,
            maxTotalSupply
        ));

        _registry.put(token, roles, tokenOwner);

        emit SRC20Created(token);

        return true;
    }
}
