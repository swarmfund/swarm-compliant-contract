pragma solidity ^0.5.10;

/**
 * @title IMinter
 * @dev Interface to a Minter, a proxy (manager) for SRC20 minting/burning.
 */
interface IMinter {

    function stakeAndMint(address src20, uint256 numSRC20Tokens) external returns(bool);

}
