const issuerStakeOfferPool = artifacts.require('IssuerStakeOfferPool');

const {
    ERC20_SWM,
    ETH_PRICE_ORACLE,
    SWM_PRICE_ORACLE,
    MIN_TOKENS,
    MAX_MARKUP,
    MAX_PROVIDER_COUNT
} = process.env;

module.exports = function (deployer) {

    return deployer.deploy(
            issuerStakeOfferPool,
            ERC20_SWM,
            ETH_PRICE_ORACLE,
            SWM_PRICE_ORACLE,
            MIN_TOKENS,
            MAX_MARKUP,
            MAX_PROVIDER_COUNT
        ).then(
        async issuerStakeOfferPool => {
        }
    )

};