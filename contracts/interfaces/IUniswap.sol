pragma solidity ^0.5.10;

/**
 * @dev Interface for Uniswap exchanges. Each ERC20 token has its own
 *      exchange. Each function covers a different scenario.
 */
interface IUniswap {

   /**
    * @dev Each function covers a different scenario.
    */
   function getEthToTokenOutputPrice(uint256) external returns(uint256); 
   function getEthToTokenInputPrice(uint256) external returns(uint256);
   function getTokenToEthInputPrice(uint256) external returns(uint256);
   function getTokenToEthOutputPrice(uint256) external returns(uint256);

}
