pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../interfaces/IUniswap.sol";
import "../interfaces/IExchange.sol";

/**
 * @title The UniswapProxy Contract
 * Forwards conversion calls to Uniswap
 */
contract UniswapProxy is Ownable {

    mapping(address => address) exchangeList;

    constructor() public {
        // These are mainnet addresses, prefilled for convenience
        // After deployment, call addOrUpdateExchange to update/modify
        address erc20DAI = 0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359;
        exchangeList[erc20DAI] = 0x09cabEC1eAd1c0Ba254B09efb3EE13841712bE14;
        address erc20USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        exchangeList[erc20USDC] = 0x97deC872013f6B5fB443861090ad931542878126;
        address erc20WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
        exchangeList[erc20WBTC] = 0x4d2f5cFbA55AE412221182D8475bC85799A5644b;
    }

    function addOrUpdateExchange(
        address token, 
        address newExchange
    )
        external onlyOwner() returns (bool) {
        exchangeList[token] = newExchange;
    }

    /**
    * Function providing exchange rates
    *
    * NOTE: it has to follow the convention of ETH being address(0),
    *       and needs to provide exchange rates from and to ETH too.
    */
    function getRate(
        address currencyFrom, 
        address currencyTo, 
        uint256 amount, 
        uint256 decimals
    ) 
        external
        returns (uint256, uint256)
    {
        // If same, just return the input
        if (currencyFrom == currencyTo)
            return (amount, decimals);

        uint256 result;

        // ERC20 - ETH
        if (currencyTo == address(0)) {
            result = IUniswap(exchangeList[currencyFrom]).getTokenToEthInputPrice(amount);
            return (result, 0);
        }

        // ETH - ERC20
        if (currencyFrom == address(0)) {
            result = IUniswap(exchangeList[currencyTo]).getEthToTokenInputPrice(amount);
            return (result, 0);
        }

        // ERC20 - ERC20
        uint256 amountETH = IUniswap(exchangeList[currencyFrom]).getTokenToEthInputPrice(amount);
        result = IUniswap(exchangeList[currencyTo]).getEthToTokenInputPrice(amountETH);
        return (result, 0);
    }

}
