pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../token/SRC20.sol";
import "../interfaces/ISRC20Registry.sol";
import "../interfaces/IAssetRegistry.sol";

/**
 * @dev Factory that creates SRC20 token with requested token
 * properties and features.
 */
contract SRC20Factory is Ownable {
    ISRC20Registry private _registry;

    event SRC20Created(address token);

    /**
     * @dev Factory constructor expects SRC20 tokens registry.
     * Each created token will be registered in registry.
     * @param registry address of SRC20Registry contract.
     */
    constructor(address registry) public {
        _registry = ISRC20Registry(registry);
    }

    /**
     * Creates new SRC20 contract. Expects token properties and
     * desired capabilities of the token. Only SRC20Factory owner can call
     * this function.
     * Emits SRC20Created event with address of new token.
     * @dev The address list has to be constructed according to the 
     * definition provided in the comments.
     * @dev Array is used to avoid "stack too deep" error
     */
    function create(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 maxTotalSupply,
        bytes32 kyaHash,
        string memory kyaUrl,
        uint256 netAssetValueUSD,
        address[] memory addressList
                     //  addressList[0] tokenOwner,
                     //  addressList[1] restrictions,
                     //  addressList[2] rules,
                     //  addressList[3] roles,
                     //  addressList[4] featured,
                     //  addressList[5] asset,
                     //  addressList[6] minter
    )
        public onlyOwner returns (bool) 
    {
        address token = address(new SRC20(
            name,
            symbol,
            decimals,
            maxTotalSupply,
            addressList
        ));

        _registry.put(
            token, 
            addressList[3], // roles
            addressList[0], // tokenOwner
            addressList[6]  // minter
        );

        IAssetRegistry(addressList[5]).addAsset(token, kyaHash, kyaUrl, netAssetValueUSD);

        emit SRC20Created(token);

        return true;
    }
}
