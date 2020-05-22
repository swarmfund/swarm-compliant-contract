pragma solidity ^0.5.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.0/contracts/ownership/Ownable.sol";
import "../interfaces/IManager.sol";
import "../interfaces/INetAssetValueUSD.sol";

/**
 * @title SetRateMinter
 * @dev Serves as proxy (manager) for SRC20 minting/burning.
 */
contract SetRateMinter is Ownable {
    IManager public _registry;

    constructor(address registry) public {
        _registry = IManager(registry);
    }

    /**
     *  This proxy function calls the SRC20Registry function that will do two things
     *  Note: prior to this, the msg.sender has to call approve() on the SWM ERC20 contract
     *        and allow the Manager to withdraw SWM tokens
     *  1. Withdraw the SWM tokens that are required for staking
     *  2. Mint the SRC20 tokens
     *  Only the Owner of the SRC20 token can call this function
     *
     * @param src20 SRC20 token address.
     * @param swmAccount SWM ERC20 account holding enough SWM tokens (>= swmValue)
     * with manager contract address approved to transferFrom.
     * @param swmValue SWM stake value.
     * @param src20Value SRC20 tokens to mint
     * @return true on success
     */
    function mintSupply(address src20, address swmAccount, uint256 swmValue, uint256 src20Value)
    external
    onlyOwner
    returns (bool)
    {
        require(_registry.mintSupply(src20, swmAccount, swmValue, src20Value), 'supply minting failed');

        return true;
    }
}
