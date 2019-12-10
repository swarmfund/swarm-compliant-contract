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

    address USDERC20 = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // call setUSDERC20() to change

    address ETH = address(0);

    struct CurrencyStats {
        address erc20address;
        address exchangeProxy; // NOTE: this is not the exchange, but the exchange proxy
                               // Multiple currencies can use the same proxy
        uint256 finalExchangeRate;
        uint256 totalBufferedAmount;
        uint256 totalQualifiedAmount;
    }

    CurrencyStats[] public currenciesList; // allowedCurrencies // currencies // acceptedCurrencies

    // pointer for each currency, to the relevant record in the CurrencyStats array above
    mapping(address => uint256) public currencyIndex;

    address public baseCurrency; // address(0) == ETH

    // per currency, its final exchange rate to BCY
    mapping(address => uint256) lockedExchangeRate;

    constructor(
    )
        public 
    {
        // Add just ETH at deployment
        // EDIT: we cannot because we don't have an exchange for it!
        //       well, we can but need to pass exchangeProxy as constructor parameter
        // CurrencyStats memory c;
        // c.erc20address = address(0);
        // c.exchangeProxy = address(0);
        // currenciesList.push(c);
        // currencyIndex[address(0)] = 0;
        // setBaseCurrency(address(0));
    }

    function setUSDERC20(address usdErc20) external onlyOwner() returns (bool) {
        USDERC20 = usdErc20;
        return true;
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
            USDERC20,
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
    public
        // returns (uint256 outAmount, uint256 outDecimals)
    returns (uint256 outAmount)
    {
        uint256 rAmount;

        (rAmount,) =
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

    /**
     *  Loop through the accepted currencies and lock the exchange rates
     *  between each of them and BCY
     *  @return true on success
     */
    function lockExchangeRates()
        external
        returns (bool)
    {
        for (uint256 i = 0; i < currenciesList.length; i++)
            lockedExchangeRate[currenciesList[i].erc20address] =
                toBCY(10**18, currenciesList[i].erc20address);

        return true;
    }

}
