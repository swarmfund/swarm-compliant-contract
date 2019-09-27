pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../interfaces/IManager.sol";
import "../interfaces/IBookValueUSD.sol";
import "../interfaces/IPriceUSD.sol";

/**
 * @title SelfServiceManager
 * @dev Serves as proxy (manager) for SRC20 minting/burning.
 */
contract SelfServiceManager {

    IManager public _registry;
    IBookValueUSD public _asset;
    IPriceUSD public _SWMPriceOracle;

    constructor(address registry, address asset, address SWMRate) public {
        _registry = IManager(registry);
        _asset = IBookValueUSD(asset);
        _SWMPriceOracle = IPriceUSD(SWMRate);
    }

    modifier onlyTokenOwner(address src20) {
        require(msg.sender == Ownable(src20).owner(), "caller not token owner");
        _;
    }

    /**
     *  Calculate how many SWM tokens need to be staked to tokenize an asset
     *  This function is custom for each Self Service Manager contract
     *  Specification: https://docs.google.com/document/d/1Z-XuTxGf5LQudO5QLmnSnD-k3nTb0tlu3QViHbOSQXo/edit
     *
     *  Note: The stake requirement depends only on the asset USD value and USD/SWM exchange rate (SWM price).
     *        It doesn't depend on the number of tokens to be minted!
     *
     *  Note: Dollar values are rounded down to the nearest full dollar
     *
     *  @dev We convert to cents and back to dollars because Solidity doesn't have decimal point support yet
     *
     *  @param tokenizedAssetValueUSD Tokenized Asset Value in USD
     *  @return the number of SWM tokens
     */
    function calcStake(uint256 tokenizedAssetValueUSD) public view returns (uint256) {

        uint256 TAV = tokenizedAssetValueUSD; /// TAV = Tokenized Asset Value in USD

        uint256 SWMPrice = _SWMPriceOracle.getPrice(); /// Price is in cents! GUI needs to know this

        uint256 stakeUSD;

        if(TAV > 0 && TAV <= 1000000)
            stakeUSD = 2500 + (TAV - 0) * 0;

        if(TAV > 1000000 && TAV <= 5000000)
            stakeUSD = 5000 + (TAV - 1000000) * 5 / 1000;

        if(TAV > 5000000 && TAV <= 15000000)
            stakeUSD = 22500 + (TAV - 5000000) * 4375 / 1000000;

        if(TAV > 15000000 && TAV <= 50000000)
            stakeUSD = 60000 + (TAV - 15000000) * 375 / 100000;

        if(TAV > 50000000 && TAV <= 100000000)
            stakeUSD = 125000 + (TAV - 50000000) * 1857 / 1000000;

        if(TAV > 100000000 && TAV <= 150000000)
            stakeUSD = 200000 + (TAV - 100000000) * 15 / 10000;

        if(TAV > 150000000 && TAV <= 250000000)
            stakeUSD = 225000 + (TAV - 150000000) * 5 / 10000;

        if(TAV > 250000000)
            stakeUSD = 250000 + (TAV - 250000000) * 25 / 100000;

        return ((stakeUSD * 100) * SWMPrice) / 100; /// Divide to get from cents to dollars

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
        uint256 numSWMTokens = calcStake(_asset.getBookValueUSD(src20));

        _registry.mintSupply(src20, msg.sender, numSWMTokens, numSRC20Tokens);

        return true;
    }

    /// burn src20 token and get back stake based on price.
    /// Phase II!
    function burnTokens(uint256 _value) external pure returns (bool) {

        return true;
    }

}