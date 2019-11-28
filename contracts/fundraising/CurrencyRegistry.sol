pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

import "../interfaces/IExchange.sol";

/**
 * @title The Fundraise Contract
 * This contract allows the deployer to perform a Swarm-Powered Fundraise.
 */
contract CurrencyRegistry is Ownable {

    using SafeMath for uint256;

    enum Currencies {ETH, DAI, USDC, WBTC}

    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // @TODO this needs to be configurable in order to test

    address ETH = address(0);

    struct CurrencyStats {
        address erc20address;
        address exchangeProxy;
        uint256 finalExchangeRate;
        uint256 totalBufferedAmount;
        uint256 totalQualifiedAmount;
    }

    CurrencyStats[] currenciesList; // allowedCurrencies // currencies

    mapping(address => uint256) currencyIndex;

    address public baseCurrency; // address(0) == ETH

    constructor(

    )
        public 
    {
        // Add just ETH at deployment
        CurrencyStats memory c;
        c.erc20address = address(0);
        c.exchangeProxy = address(0);
        currenciesList.push(c);
        currencyIndex[address(0)] = 0;
    }

    function isAccepted(address currency) public view returns (bool) {
        for (uint256 i = 0; i < currenciesList.length; i++) {
            if (currency == currenciesList[i].erc20address) {
                return true;
            }
        }
        return false;
    }

    function addCurrency(address erc20address, address exchangeProxy) external onlyOwner() returns (bool) {
        CurrencyStats memory c;
        c.erc20address = erc20address;
        c.exchangeProxy = exchangeProxy;
        currenciesList.push(c);
        currencyIndex[c.erc20address] = currenciesList.length - 1;
        return true;
    }

    function setBaseCurrency(address currency) public onlyOwner() returns (bool) {
        require(isAccepted(currency), "Unsupported base currency");
        baseCurrency = currency;
        return true;
    }

    function getBaseCurrency() external view returns (address) {
        return baseCurrency;
    }

    function getAcceptedCurrencies() external view returns (address[] memory) {
        address[] memory currencies = new address[](currenciesList.length);
        for (uint256 i = 0; i < currenciesList.length; i++) {
            currencies[i] = (currenciesList[i].erc20address);
        }
        return currencies;
    }

    function toUSDC(
        uint256 amount,
        address currencyFrom
    //uint256 decimals
    )
    external
        //returns (uint256 outAmount, uint256 outDecimals)
    returns (uint256 outAmount)
    {
        (uint256 rAmount,) =
        IExchange(currenciesList[currencyIndex[currencyFrom]].exchangeProxy).getRate(
            currencyFrom,
            USDC,
            amount,
            0
        //decimals
        );
        return rAmount;
    }

    function toBCY(
        uint256 amount,
        address currencyFrom
    //, uint256 decimals
    )
    external
        // returns (uint256 outAmount, uint256 outDecimals)
    returns (uint256 outAmount)
    {
        (uint256 rAmount,) =
        IExchange(currenciesList[currencyIndex[currencyFrom]].exchangeProxy).getRate(
            currencyFrom,
            baseCurrency,
            amount,
            0
        //decimals
        );
        return rAmount;
    }

    function getRate(
        address currencyFrom,
        address currencyTo,
        uint256 amount,
        uint256 decimals
    )
    external
    returns (uint256, uint256)
    {
        return IExchange(currenciesList[currencyIndex[currencyFrom]].exchangeProxy).getRate(
            currencyFrom,
            currencyTo,
            amount,
            decimals
        );
    }

}
