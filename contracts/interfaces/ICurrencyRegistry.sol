pragma solidity ^0.5.0;

/**
 * @title Interface for the CurrenciesRegistry contract
 */
interface ICurrencyRegistry {

    function isAccepted(address currency) external view returns (bool);

    function addCurrency(address erc20address, address exchangeProxy) external returns (bool);

    function setBaseCurrency(address erc20address) external returns (bool);

    function getBaseCurrency() external returns (address);

    function getAcceptedCurrencies() external returns (address[] memory);

    function lockExchangeRates() external returns (bool);

    function toUSD(
        uint256 amount,
        address currencyFrom
    ) 
        external view
        returns (uint256 outAmount);

    function toBCY(
        uint256 amount,
        address currencyFrom
    ) 
        external view
        returns (uint256 outAmount);

    function getRate(
        address currencyFrom,
        address currencyTo,
        uint256 amount
    ) 
    external
    returns (uint256);

}
