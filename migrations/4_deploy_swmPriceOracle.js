const SWMPriceOracle = artifacts.require("SWMPriceOracle");

const {
    SWM_PRICE_USD
} = process.env;

module.exports = function (deployer) {
    return deployer.deploy(SWMPriceOracle,
        SWM_PRICE_USD
    )
};
