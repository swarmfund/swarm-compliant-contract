pragma solidity ^0.5.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.0/contracts/ownership/Ownable.sol";
import "../interfaces/IPriceUSD.sol";

/**
 * @title SWMPriceOracle
 * Serves to get the currently valid (not necessarily current) price of SWM in USD.
 *
 * Note: 0.019 will be returned as (19, 1000). Solidity at this point cannot natively
 *       handle decimal numbers, so we work with two values. Caller needs to be aware of this.
 *
 * @dev Needs to conform to the IPriceUSD interface, otherwise can be rewritten to
 *      use whichever method of setting the price is desired (manual, external oracle...)
 */
contract SWMPriceOracle is IPriceUSD, Ownable {

    event UpdatedSWMPriceUSD(uint256 oldPriceNumerator, uint256 oldPriceDenominator, 
                             uint256 newPriceNumerator, uint256 newPriceDenominator);

    uint256 public _priceNumerator;
    uint256 public _priceDenominator;

    constructor(uint256 priceNumerator, uint256 priceDenominator) 
    public {
        require(priceNumerator > 0, "numerator must not be zero");
        require(priceDenominator > 0, "denominator must not be zero");

        _priceNumerator = priceNumerator;
        _priceDenominator = priceDenominator;

        emit UpdatedSWMPriceUSD(0, 0, priceNumerator, priceNumerator);
    }

    /**
     *  This function gets the price of SWM in USD 
     *
     *  0.0736 is returned as (736, 10000)
     *  @return _priceNumerator, The numerator of the currently valid price of SWM in USD
     *  @return _priceDenominator, The denominator of the currently valid price of SWM in USD
     */
    function getPrice() external view returns (uint256 priceNumerator, uint256 priceDenominator) {
        return (_priceNumerator, _priceDenominator);
    }

    /**
     *  This function can be called manually or programmatically to update the 
     *  currently valid price of SWM in USD
     *
     *  To update to 0.00378 call with (378, 100000)
     *  @param priceNumerator The new SWM price in USD
     *  @param priceDenominator The new SWM price in USD
     *  @return true on success
     */
    function updatePrice(uint256 priceNumerator, uint256 priceDenominator) external onlyOwner returns (bool) {
        require(priceNumerator > 0, "numerator must not be zero");
        require(priceDenominator > 0, "denominator must not be zero");

        emit UpdatedSWMPriceUSD(_priceNumerator, _priceDenominator, priceNumerator, priceDenominator);

        _priceNumerator = priceNumerator;
        _priceDenominator = priceDenominator;

        return true;
    }
}