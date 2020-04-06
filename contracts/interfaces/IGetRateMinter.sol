pragma solidity ^0.5.10;

/**
 * @title IGetRateMinter
 * @dev Interface to GetRateMinter, proxy (manager) for SRC20 minting/burning.
 */
interface IGetRateMinter {

    function calcStake(uint256 netAssetValueUSD) external view returns (uint256);
    function stakeAndMint(address src20, uint256 numSRC20Tokens) external returns(bool);

}
