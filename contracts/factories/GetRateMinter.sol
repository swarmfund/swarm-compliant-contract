pragma solidity ^0.5.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.0/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.0/contracts/ownership/Ownable.sol";
import "../interfaces/IManager.sol";
import "../interfaces/INetAssetValueUSD.sol";
import "../interfaces/IPriceUSD.sol";
import "../interfaces/ISRC20.sol";

/**
 * @title GetRateMinter
 * @dev Serves as proxy (manager) for SRC20 minting/burning.
 */
contract GetRateMinter {
    IManager public _registry;
    INetAssetValueUSD public _asset;
    IPriceUSD public _SWMPriceOracle;

    using SafeMath for uint256;

    constructor(address registry, address asset, address SWMRate) public {
        _registry = IManager(registry);
        _asset = INetAssetValueUSD(asset);
        _SWMPriceOracle = IPriceUSD(SWMRate);
    }

    modifier onlyTokenOwner(address src20) {
	
        require(msg.sender == Ownable(src20).owner() ||
                msg.sender == ISRC20(src20).fundRaiserAddr(), "caller not token owner");
        _;
    }

    /**
     *  Calculate how many SWM tokens need to be staked to tokenize an asset
     *  This function is custom for each GetRateMinter contract
     *  Specification: https://docs.google.com/document/d/1Z-XuTxGf5LQudO5QLmnSnD-k3nTb0tlu3QViHbOSQXo/
     *
     *  Note: The stake requirement depends only on the asset USD value and USD/SWM exchange rate (SWM price).
     *        It doesn't depend on the number of tokens to be minted!
     *
     *  @param netAssetValueUSD Tokenized Asset Value in USD
     *  @return the number of SWM tokens
     */
    function calcStake(uint256 netAssetValueUSD) public view returns (uint256) {

        uint256 NAV = netAssetValueUSD; // Value in USD, an integer
        uint256 stakeUSD;

        if(NAV >= 0 && NAV <= 500000) // Up to 500,000 NAV the stake is flat at 2,500 USD
            stakeUSD = 2500;

        if(NAV > 500000 && NAV <= 1000000) // From 500K up to 1M stake is 0.5%
            stakeUSD = NAV.mul(5).div(1000);

        if(NAV > 1000000 && NAV <= 5000000) // From 1M up to 5M stake is 0.45%
            stakeUSD = NAV.mul(45).div(10000);

        if(NAV > 5000000 && NAV <= 15000000) // From 5M up to 15M stake is 0.40%
            stakeUSD = NAV.mul(4).div(1000);

        if(NAV > 15000000 && NAV <= 50000000) // From 15M up to 50M stake is 0.25%
            stakeUSD = NAV.mul(25).div(10000);

        if(NAV > 50000000 && NAV <= 100000000) // From 50M up to 100M stake is 0.20%
            stakeUSD = NAV.mul(2).div(1000);

        if(NAV > 100000000 && NAV <= 150000000) // From 100M up to 150M stake is 0.15%
            stakeUSD = NAV.mul(15).div(10000);

        if(NAV > 150000000) // From 150M up stake is 0.10%
            stakeUSD = NAV.mul(1).div(1000);

        (uint256 numerator, uint denominator) = _SWMPriceOracle.getPrice(); // 0.04 is returned as (4, 100)

        return stakeUSD.mul(denominator).div(numerator).mul(10**18); // 10**18 because we return Wei

    } /// fn calcStake

    /**
     *  This proxy function calls the SRC20Registry function that will do two things
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
	
	if (msg.sender == ISRC20(src20).fundRaiserAddr())
       		require(_registry.mintSupply(src20, Ownable(src20).owner(), numSWMTokens, numSRC20Tokens), 'supply minting failed');
	else
       		require(_registry.mintSupply(src20, msg.sender, numSWMTokens, numSRC20Tokens), 'supply minting failed');

        return true;
    }
}
