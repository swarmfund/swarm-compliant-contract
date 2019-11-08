pragma solidity ^0.5.10;

/**
 * @title The Issuer Stake Offer Pool Interface
 * Interface to Issuer Stake Offer Pool, which allows anyone 
 * to register as provider of SWM tokens.
 */
interface IIssuerStakeOfferPool {

    function register(uint256 swmAmount, uint256 markup) external returns (bool);
    function unRegister() external returns (bool);
    function isStakeOfferer(address account) external view returns (bool);
    function getSWMPriceETH(address account, uint256 numSWM) external returns (uint256);
    function buySWMTokens(address account, uint256 numSWM) external payable returns (bool);

}