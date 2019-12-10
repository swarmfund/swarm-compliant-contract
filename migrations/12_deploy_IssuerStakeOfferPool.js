const issuerStakeOfferPool = artifacts.require('IssuerStakeOfferPool');

const {
    DAI_ERC20,
    DAI_EXCHANGE,
    USDC_ERC20,
    USDC_EXCHANGE,
    WBTC_ERC20,
    WBTC_EXCHANGE
} = process.env;

module.exports = function (deployer) {

    return deployer.deploy(
            issuerStakeOfferPool,
            DAI_ERC20,  // address _swarmERC20,
            DAI_ERC20,  // address _ethPriceOracle,
            DAI_ERC20,  // address _swmPriceOracle,
            0,          // uint256 _minTokens,
            100000,     // uint256 _maxMarkup
            0           // uint256 _maxProviderCount)
        ).then(
        async issuerStakeOfferPool => {
        }
    )

};