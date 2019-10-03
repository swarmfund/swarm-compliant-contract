pragma solidity ^0.5.0;

/**
 * @dev Interface for the AssetRegistry contract
 */
interface INetAssetValueUSD {

    function getNetAssetValueUSD(address src20) external view returns (uint256);
}