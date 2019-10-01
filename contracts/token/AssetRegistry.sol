pragma solidity ^0.5.0;

import "../interfaces/ISRC20Roles.sol";
import "./SRC20.sol";
import "../interfaces/IAssetRegistry.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

/**
 * AssetRegistry holds the real-world/offchain properties of the various Assets being tokenized.
 * It provides functions for getting/setting these properties.
 */
contract AssetRegistry is IAssetRegistry, Ownable {

    struct AssetType {
        bytes32 kyaHash;
        string kyaUrl;
        uint256 bookValueUSD;
    }

    address public _src20Factory;

    mapping(address => AssetType) public assetList;

    modifier onlyFactory() {
        require(_src20Factory == msg.sender, "Caller not factory");
        _;
    }

    modifier onlyDelegate(address src20) {
        require(SRC20(src20)._roles().isDelegate(msg.sender), "Caller not delegate");
        _;
    }

    constructor(address src20Factory) public {
        _src20Factory = src20Factory;
    }

    /**
     * Add an asset to the AssetRegistry
     *
     * @param src20 the token address.
     * @param kyaHash SHA256 hash of KYA document.
     * @param kyaUrl URL of token's KYA document (ipfs, http, etc.).
     *               or address(0) if no rules should be checked on chain.
     * @return True on success.
     */
    function addAsset(address src20, bytes32 kyaHash, string calldata kyaUrl, uint256 bookValueUSD)
        external
        onlyFactory
        returns (bool)
    {
        require(assetList[src20].bookValueUSD == 0, 'Asset already added, try update functions');

        assetList[src20].kyaHash = kyaHash;
        assetList[src20].kyaUrl = kyaUrl;
        assetList[src20].bookValueUSD = bookValueUSD;

        emit AssetAdded(src20, kyaHash, kyaUrl, bookValueUSD);
        return true;
    }

    /**
     * Gets the currently valid book value for a token.
     *
     * @param src20 the token address.
     * @return The current book value of the token.
     */
    function getBookValueUSD(address src20) external view returns (uint256) {
        return assetList[src20].bookValueUSD;
    }

    /**
     * Sets the currently valid book value for a token.
     *
     * @param src20 the token address.
     * @param bookValueUSD the new value we're setting 
     * @return True on success.
     */
    function updateBookValueUSD(address src20, uint256 bookValueUSD) external onlyDelegate(src20) returns (bool) {
        assetList[src20].bookValueUSD = bookValueUSD;
        emit AssetBookValueUSDUpdated(src20, bookValueUSD);
        return true;
    }

    /**
     * Retrieve token's KYA document's hash and url.
     *
     * @param src20 the token this applies to
     *
     * @return Hash of KYA document.
     * @return URL of KYA document.
     */
    function getKYA(address src20) public view returns (bytes32, string memory) {
        return (assetList[src20].kyaHash, assetList[src20].kyaUrl);
    }

    /**
     * @dev Update KYA document, sending document hash and url. 
     * Hash is SHA256 hash of document content.
     * Emits AssetKYAUpdated event.
     * Allowed to be called by owner's delegate only.
     *
     * @param src20 the token this applies to.
     * @param kyaHash SHA256 hash of KYA document.
     * @param kyaUrl URL of token's KYA document (ipfs, http, etc.).
     *               or address(0) if no rules should be checked on chain.
     * @return True on success.
     */
    function updateKYA(address src20, bytes32 kyaHash, string calldata kyaUrl)
        external onlyDelegate(src20) returns (bool)
    {
        assetList[src20].kyaHash = kyaHash;
        assetList[src20].kyaUrl = kyaUrl;

        emit AssetKYAUpdated(src20, kyaHash, kyaUrl);
        return true;
    }
}