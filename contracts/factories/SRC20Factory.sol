pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../token/SRC20.sol";
import "./SRC20Registry.sol";


/**
 * @dev Factory that creates SRC20 token for requested token
 * properties and features.
 */
contract SRC20Factory is Ownable {
    SRC20Registry private _registry; 

    event SRC20Created(address token);

    /**
     * @dev Factory constructor expects SRC20 tokens registry.
     * Every created token will be registered in registry.
     * @param registry address of SRC20Registry contract.
     */
    constructor(SRC20Registry registry) public {
        _registry = registry;
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
        uint8 features,
        uint256 totalSupply
    ) 
        public onlyOwner returns (bool) 
    {
        address token = address(new SRC20(
            // contract parameters
            tokenOwner,
            name,
            symbol,
            decimals,
            kyaHash,
            kyaUrl,
            restrictions,
            features,
            totalSupply
        ));

        _registry.put(token, tokenOwner);

        SRC20(token).transferManagement(address(_registry));

        emit SRC20Created(token);
        return true;
    }
}
