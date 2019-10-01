pragma solidity ^0.5.0;

/**
 * @dev Interface for the Asset contract
 */
interface IBookValueUSD {

    function getBookValueUSD(address src20) external view returns (uint256);
}