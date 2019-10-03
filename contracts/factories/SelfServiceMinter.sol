pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../interfaces/IManager.sol";
import "../interfaces/INetAssetValueUSD.sol";
import "../interfaces/IPriceUSD.sol";

/**
 * @title SelfServiceMinter
 * @dev Serves as proxy (manager) for SRC20 minting/burning.
 */
contract SelfServiceMinter {
    IManager public _registry;
    INetAssetValueUSD public _asset;
    IPriceUSD public _SWMPriceOracle;

    constructor(address registry, address asset, address SWMRate) public {
        _registry = IManager(registry);
        _asset = INetAssetValueUSD(asset);
        _SWMPriceOracle = IPriceUSD(SWMRate);
    }

    modifier onlyTokenOwner(address src20) {
        require(msg.sender == Ownable(src20).owner(), "caller not token owner");
        _;
    }

    /**
     *  Calculate how many SWM tokens need to be staked to tokenize an asset
     *  This function is custom for each Self Service Minter contract
     *  Specification: https://docs.google.com/document/d/1Z-XuTxGf5LQudO5QLmnSnD-k3nTb0tlu3QViHbOSQXo/
     *
     *  Note: The stake requirement depends only on the asset USD value and USD/SWM exchange rate (SWM price).
     *        It doesn't depend on the number of tokens to be minted!
     *
     *  @param netAssetValueUSD Tokenized Asset Value in USD
     *  @return the number of SWM tokens
     */
    function calcStake(uint256 netAssetValueUSD) public view returns (uint256) {

        uint256 NAV = netAssetValueUSD; /// Value in USD

        uint256 SWMPriceUSD = _SWMPriceOracle.getPrice(); /// Price is in cents! GUI needs to know this
        uint256 stakeUSD;

        if(NAV > 0 && NAV <= 500000) // Up to 500,000 NAV the stake is flat at 2,500 USD
            stakeUSD = 2500;

        if(NAV > 500000 && NAV <= 1000000) // From 500K up to 1M stake is 0.5%
            stakeUSD = NAV * 5 / 1000;

        if(NAV > 1000000 && NAV <= 5000000) // From 1M up to 5M stake is 0.45%
            stakeUSD = NAV * 45 / 10000;

        if(NAV > 5000000 && NAV <= 15000000) // From 5M up to 15M stake is 0.40%
            stakeUSD = NAV * 4 / 1000;

        if(NAV > 15000000 && NAV <= 50000000) // From 15M up to 50M stake is 0.25%
            stakeUSD = NAV * 25 / 10000;

        if(NAV > 50000000 && NAV <= 100000000) // From 50M up to 100M stake is 0.20%
            stakeUSD = NAV * 2 / 1000;

        if(NAV > 100000000 && NAV <= 150000000) // From 100M up to 150M stake is 0.15%
            stakeUSD = NAV * 15 / 10000;

        if(NAV > 150000000) // From 150M up stake is 0.10%
            stakeUSD = NAV * 1 / 1000;

        return (stakeUSD / SWMPriceUSD);

    } /// fn calcStake

    /**
     *  This proxy function calls calls the SRC20Registry function that will do two things
     *  Note: prior to this, the msg.sender has to call approve() on the SWM ERC20 contract
     *        and allow the Manager to withdraw SWM tokens
     *  1. Withdraw the SWM tokens that are required for staking
     *  2. Mint the SRC20 tokens
     *  Only the Owner of the SRC20 token can call this function
     *
     *  @param src20 The address of the SRC20 token to mint tokens for
     *  @param numSRC20Tokens Number of SRC20 tokens to mint
     *  @return true on success
     */
    function stakeAndMint(address src20, uint256 numSRC20Tokens)
        external
        onlyTokenOwner(src20)
        returns (bool)
    {
        uint256 numSWMTokens = calcStake(_asset.getNetAssetValueUSD(src20));

        require(_registry.mintSupply(src20, msg.sender, numSWMTokens, numSRC20Tokens), 'supply minting failed');

        return true;
    }
}