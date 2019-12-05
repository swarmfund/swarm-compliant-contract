pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../interfaces/IUniswap.sol";

/**
 * @title The UniswapMock Contract
 * To be created and set up for testing purposes.
 */
contract UniswapMock is Ownable {

    uint256 rate;

    constructor() public {
    }

    function setTokenToETHRate(
        uint256 newRate
        // ,uint256 newRateDecimal
    )
        external
        onlyOwner() 
        returns (bool) 
    {
        rate = newRate;
        return true;
    }

    function getTokenToEthInputPrice(
        uint256 amount
        //,uint256 decimals
    ) 
    external
    view
    returns (uint256, uint256)
    {
        return(amount * rate, 0);
    }

    function getEthToTokenInputPrice(
        uint256 amount
        //,uint256 decimals
    ) 
    external
    view
    returns (uint256, uint256)
    {
        return(amount * 1/rate, 0);
    }

}
