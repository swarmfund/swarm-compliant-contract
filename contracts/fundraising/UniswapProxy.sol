pragma solidity ^0.5.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.0/contracts/ownership/Ownable.sol";
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
        address erc20DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        exchangeList[erc20DAI] = 0x2a1530C4C41db0B0b2bB646CB5Eb1A67b7158667;
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
        return true;
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
        uint256 amount 
    ) 
        external
        returns (uint256)
    {
        // If same, just return the input
        if (currencyFrom == currencyTo)
            return (amount);

        uint256 result;

        // ERC20 - ETH
        if (currencyTo == address(0)) {
            result = IUniswap(exchangeList[currencyFrom]).getTokenToEthInputPrice(amount);
            return (result);
        }

        // ETH - ERC20
        if (currencyFrom == address(0)) {
            result = IUniswap(exchangeList[currencyTo]).getEthToTokenInputPrice(amount);
            return (result);
        }

        // ERC20 - ERC20
        uint256 amountETH = IUniswap(exchangeList[currencyFrom]).getTokenToEthInputPrice(amount);
        result = IUniswap(exchangeList[currencyTo]).getEthToTokenInputPrice(amountETH);
        return (result);
    }

}
