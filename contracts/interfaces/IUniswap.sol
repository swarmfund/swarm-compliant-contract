pragma solidity ^0.5.10;

/**
    * @dev Interface for Uniswap exchanges. Each ERC20 token has its own
    *      exchange. Each function covers a different scenario.

   getEthToTokenOutputPrice(tokens_bought: uint256): uint256
   tokens_bought: Amount of ERC20 tokens bought
   Returns: Amount of ETH that must be sold

   getEthToTokenInputPrice(eth_sold: uint256): uint256
   eth_sold: Amount of ETH sold
   Returns: Amount of ERC20 tokens that can be bought

   getTokenToEthInputPrice(tokens_sold: uint256): uint256
   tokens_sold: Amount of ERC20 tokens sold
   Returns: Amount of ETH that can be bought

   getTokenToEthOutputPrice(eth_bought: uint256): uint256
   eth_bought: Amount of ETH bought
   Returns: Amount of ERC20 tokens that must be sold
 
*/
interface IUniswap {

   function getEthToTokenOutputPrice(uint256) external returns(uint256); 
   function getEthToTokenInputPrice(uint256) external returns(uint256);
   function getTokenToEthInputPrice(uint256) external returns(uint256);
   function getTokenToEthOutputPrice(uint256) external returns(uint256);

}
