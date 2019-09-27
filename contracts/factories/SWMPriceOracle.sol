pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../interfaces/IPriceUSD.sol";

/**
 * @title SWMPriceOracle
 * Serves to get the currently valid (not necessarily current) price of SWM in USD.
 *
 * Note: 0.19 will be returned as 19. Solidity can't handle decimal numbers, so we
 *       store cents. Caller needs to be aware of this.
 *
 * @dev Needs to conform to the IPriceUSD interface, otherwise can be rewritten to
 *      use whichever method of setting the price is desired (manual, external oracle...)
 */
contract SWMPriceOracle is IPriceUSD, Ownable {

    event updatedSWMPrice(uint256 oldPrice, uint256 newPrice);

    uint256 public _SWMPriceUSD;

    constructor(uint256 newSWMPriceUSD) 
    public {
        _SWMPriceUSD = newSWMPriceUSD;
        emit updatedSWMPrice(0, _SWMPriceUSD);
    }

    /**
     *  This function gets the price of SWM in USD 
     *  @return The currently valid price of SWM in USD
     */
    function getPrice() external view returns (uint256) {
        return _SWMPriceUSD;
    }

    /**
     *  This function can be called manually or programmatically to update the 
     *  currently valid price of SWM in USD
     *
     *  @param newSWMPriceUSD The new SWM price in USD
     *  @return true on success
     */
    function updatePrice(uint256 newSWMPriceUSD) external onlyOwner returns (bool) {
        _SWMPriceUSD = newSWMPriceUSD;
        emit updatedSWMPrice(_SWMPriceUSD, newSWMPriceUSD);
        return true;
    }

}