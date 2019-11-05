pragma solidity ^0.5.0;

/**
    @title interface for exchange rate provider contracts
 */
interface IPriceUSD {

    function getPrice() external view returns (uint256 numerator, uint256 denominator);

}