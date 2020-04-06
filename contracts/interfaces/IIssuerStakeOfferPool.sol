pragma solidity ^0.5.10;

/**
 * @title The Issuer Stake Offer Pool Interface
 * Interface to Issuer Stake Offer Pool, which allows anyone 
 * to register as provider of SWM tokens.
 */
interface IIssuerStakeOfferPool {

    function register(uint256 swmAmount, uint256 markup) external returns (bool);
    function unRegister() external returns (bool);
    function unRegister(address provider) external returns (bool);
    function updateMinTokens(uint256 _minTokens) external;
    function isStakeOfferer(address account) external view returns (bool);
    function getTokens(address account) external view returns (uint256);

    function getSWMPriceETH(address account, uint256 numSWM) external returns (uint256);
    function loopGetSWMPriceETH(uint256 _swmAmount, uint256 _maxMarkup) external returns (uint256);

    function buySWMTokens(address account, uint256 numSWM) external payable returns (bool);
    function loopBuySWMTokens(uint256 numSWM,  uint256 _maxMarkup) external payable returns (bool);

}