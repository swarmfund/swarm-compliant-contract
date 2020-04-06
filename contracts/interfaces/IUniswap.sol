pragma solidity ^0.5.10;

/**
   An interface to Uniswap exchanges. 
   https://docs.uniswap.io/smart-contract-integration/interface

   Each ERC20 token has its own exchange.
   Each function covers a different scenario.

   *** However, they should all yield the same exhange rate! ***
   
   Test that hypothesis here: 
   https://etherscan.io/address/0x4ad62eb698d551d7260466f779f2864a38074dba#readContract

   // If you want to buy ERC20
   getEthToTokenOutputPrice(tokens_bought: uint256): uint256
   tokens_bought: Amount of ERC20 tokens bought
   Returns: Amount of ETH that must be sold

   // If you want to sell ETH
   getEthToTokenInputPrice(eth_sold: uint256): uint256
   eth_sold: Amount of ETH sold
   Returns: Amount of ERC20 tokens that can be bought

   // If you want to sell ERC20
   getTokenToEthInputPrice(tokens_sold: uint256): uint256
   tokens_sold: Amount of ERC20 tokens sold
   Returns: Amount of ETH that can be bought

   // If you want to buy ETH
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
