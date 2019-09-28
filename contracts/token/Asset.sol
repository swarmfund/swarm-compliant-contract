pragma solidity ^0.5.0;

import "../interfaces/IBookValueUSD.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

/**
 * @dev Asset contract holds the USD value of the Asset.
 * Value in this context is the Book Value (as opposed to Market Value)
 */
contract Asset is IBookValueUSD, Ownable {
    event AssetValueUSDUpdated(address src20, uint256 newAssetValueUSD);

    mapping(address => uint256) public assetsValuesUSD;

    constructor (address _src20, uint256 _assetValueUSD) public {
        assetsValuesUSD[_src20] = _assetValueUSD;
        emit AssetValueUSDUpdated(_src20, _assetValueUSD);
    }

    function getAssetValueUSD(address src20) external view returns (uint256) {
        return assetsValuesUSD[src20];
    }

    function setAssetValueUSD(address _src20, uint256 _newAssetValueUSD) external onlyOwner returns (bool) {
        assetsValuesUSD[_src20] = _newAssetValueUSD;
        emit AssetValueUSDUpdated(_src20, _newAssetValueUSD);
        return true;
    }
}