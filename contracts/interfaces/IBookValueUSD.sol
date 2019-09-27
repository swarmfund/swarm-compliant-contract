pragma solidity ^0.5.0;

/**
 * @dev Interface for the Asset contract
 */
interface IBookValueUSD {
    event AssetValueUSDUpdated(address src20, uint256 newAssetValueUSD);

    function getBookValueUSD(address src20) external view returns (uint256);
}