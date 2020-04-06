pragma solidity ^0.5.0;

/**
 * Interface for a generic exchange providing exchange rates.
 *
 * NOTE: it has to follow the convention of ETH being address(0),
 *       and needs to provide exchange rates from and to ETH too.
 */
interface IExchange {

    function getRate(
        address currencyFrom, 
        address currencyTo, 
        uint256 amount, 
        uint256 decimals
    )
        external
        returns (uint256 outAmount, uint256 outDecimals);

}
